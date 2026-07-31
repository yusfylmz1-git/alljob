import 'package:ar_flutter_plugin_plus/ar_flutter_plugin_plus.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_hittest_result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../application/toolkit_calculators.dart';
import '../application/toolkit_models.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// AR Ölçüm — AR-1 (PRD-007 Faz D §6.6). Düzlem algıla → iki noktaya dokun →
/// aralarındaki tahmini uzunluğu (m) ölç → hesaplayıcıya aktar.
///
/// AR desteği/oturumu başlamazsa ([_hata] set olur) ekran **çökmeden** bir
/// bilgilendirme + elle ölçüm yönlendirmesi gösterir (PRD kuralı: "Destek yoksa
/// çökme yok → elle ölçüm"). Kaynak rozeti sonuçta AR olarak işaretlenir.
class ArScreen extends StatefulWidget {
  const ArScreen({super.key, this.returnResult = false});

  /// true ise (ölçüm akışından açıldığında) "aktar" düğmesi ölçtüğü uzunluğu
  /// `pop(metre)` ile geri döndürür; false ise Alan hesaplayıcıya push eder.
  final bool returnResult;

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  ARSessionManager? _sessionManager;

  /// Dokunulan noktaların dünya koordinatları (m). En çok 2 nokta tutulur.
  final List<Vector3> _noktalar = [];
  ArUzunlukSonucu? _sonuc;

  /// Kullanıcının ölçmek istediği yüzey yönü. Zemin/tezgâh = yatay,
  /// duvar = dikey. Yalnız ipucu/yönerge amaçlı; algılama iki yönü de
  /// tarar ama kullanıcı hangi yüzeyi hedeflediğini seçince yönerge netleşir.
  bool _dikeyMod = true; // varsayılan: duvar (en sık ölçülen)

  @override
  void dispose() {
    _sessionManager?.dispose();
    super.dispose();
  }

  void _onArViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _sessionManager = sessionManager;

    sessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
    );
    objectManager.onInitialize();

    // Dokunma → hit-test sonuçları. AR oturumu başlatılamazsa paket kendi
    // hata snackbar'ını gösterir (çökme yok); kullanıcı AppBar'daki "Elle ölç"
    // ile her zaman elle ölçüme geçebilir (PRD: destek yoksa elle ölçüm).
    sessionManager.onPlaneOrPointTap = _onTap;
  }

  void _onTap(List<ARHitTestResult> hits) {
    // Hiç isabet yoksa yüzey henüz izlenmiyor demektir. Sessizce yutma —
    // kullanıcı "dokunuyorum ama bir şey olmuyor" durumunda kalmasın.
    if (hits.isEmpty) {
      _yuzeyYok();
      return;
    }

    // YALNIZ düzlem (algılanmış yüzey) isabetini kabul et. Özellik-noktası
    // isabetleri (masa/koltuk gibi rastgele nesnelerin köşeleri) çok gürültülü
    // ve "duvar" sanılıyor — bunları eleyip kullanıcıyı yüzeyi taramaya
    // yönlendirmek yanlış ölçümden iyidir.
    final planeHits =
        hits.where((h) => h.type == ARHitTestResultType.plane).toList();
    if (planeHits.isEmpty) {
      _yuzeyYok();
      return;
    }
    final hit = planeHits.first;

    final nokta = hit.worldTransform.getTranslation();
    setState(() {
      if (_noktalar.length >= 2) {
        // Üçüncü dokunuş yeni ölçüm başlatır.
        _noktalar
          ..clear()
          ..add(nokta);
        _sonuc = null;
      } else {
        _noktalar.add(nokta);
        if (_noktalar.length == 2) {
          final a = [_noktalar[0].x, _noktalar[0].y, _noktalar[0].z];
          final b = [_noktalar[1].x, _noktalar[1].y, _noktalar[1].z];
          _sonuc = ArUzunlukSonucu(metre: uzunlukM(a, b));
        }
      }
    });
  }

  /// Düzlem izlenmediği için dokunuş kabul edilmedi; kullanıcıyı yönlendir.
  void _yuzeyYok() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text(
            'Yüzey (ızgara) henüz belirmedi. Telefonu yavaşça gezdirin; '
            'noktalı ızgara çıkınca onun üstüne dokunun. Boşluğa/nesne '
            'kenarına dokunmak ölçmez.',
          ),
        ),
      );
  }

  /// AR tahminini elle düzeltir: kullanıcı gerçek uzunluğu (şeritmetreyle
  /// ölçtüğü) girip AR değerini ezebilir. Kaba AR'ın en zayıf yanı budur;
  /// düzeltilen değer yine hesaplayıcıya aktarılabilir.
  Future<void> _elleDuzelt() async {
    final s = _sonuc;
    if (s == null) return;
    final ctrl = TextEditingController(text: trSayi(s.metre));
    final yeni = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uzunluğu düzelt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AR tahminidir. Şeritmetreyle ölçtüğün gerçek değeri (m) '
              'girersen onu kullanırız.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Uzunluk (m)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(ctx, (v != null && v > 0) ? v : null);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (yeni != null && mounted) {
      setState(() => _sonuc = ArUzunlukSonucu(metre: yeni));
    }
  }

  void _sifirla() {
    setState(() {
      _noktalar.clear();
      _sonuc = null;
    });
  }

  /// AR ile ölçülen uzunluğu Alan hesaplayıcıya taşır (bir kenar olarak).
  void _alanaAktar() {
    final s = _sonuc;
    if (s == null) return;
    // Ölçüm akışından açıldıysa değeri geri döndür; yoksa Alan ekranına git.
    if (widget.returnResult) {
      context.pop(s.metre);
    } else {
      context.push('${RoutePaths.toolkitArea}?ar_uzunluk=${s.metre}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaba Ölçüm (AR)'),
        actions: [
          if (_noktalar.isNotEmpty)
            IconButton(
              tooltip: 'Sıfırla',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _sifirla,
            ),
          // AR desteklenmiyor / kullanışsızsa kullanıcı her zaman elle ölçüme
          // geçebilir (PRD: destek yoksa elle ölçüm).
          IconButton(
            tooltip: 'Elle ölç',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(RoutePaths.toolkitArea),
          ),
        ],
      ),
      body: Stack(
        children: [
          // AR kamera görünümü. Oturum başlatılamazsa paket kendi hata
          // snackbar'ını gösterir; kullanıcı AppBar'daki "Elle ölç" ile geçer.
          ARView(
            onARViewCreated: _onArViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // Üstte kalıcı "tahmini" uyarısı + yüzey seçici + yönerge + nokta izi.
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Column(
              children: [
                const TahminiUyariBanner(compact: true),
                const SizedBox(height: 8),
                // Yatay/dikey yüzey tercihi — kullanıcı ne ölçtüğünü seçer.
                _YuzeySecici(
                  dikey: _dikeyMod,
                  onChanged: (v) => setState(() => _dikeyMod = v),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.ink.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Başlangıç/bitiş nokta izi — kullanıcı seçtiğini görsün.
                      _NoktaIzi(secili: _noktalar.length),
                      const SizedBox(height: 8),
                      Text(
                        _noktalar.isEmpty
                            ? 'Telefonu gezdirip ızgarayı çıkarın; '
                                '${_dikeyMod ? 'duvarda' : 'zeminde'} '
                                'başlangıç noktasına dokunun.'
                            : _noktalar.length == 1
                                ? 'Şimdi aynı yüzeyde bitiş noktasına dokunun.'
                                : 'Kaba ölçüm hazır. Gerekiyorsa “Elle düzelt”. '
                                    'Yeni ölçüm için tekrar dokunun.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sonuç kartı (iki nokta seçilince).
          if (_sonuc != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SonucKarti(
                    baslik: 'AR kaba ölçüm',
                    vurguDeger: '${trSayi(_sonuc!.metre)} m',
                    sonuc: _sonuc!,
                    kaynak: OlcuKaynagi.ar,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Elle düzelt'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                        onPressed: _elleDuzelt,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.square_foot_outlined),
                          label: Text(widget.returnResult
                              ? 'Bu ölçümü kullan'
                              : 'Alana aktar'),
                          onPressed: _alanaAktar,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Yatay (zemin/tezgâh) vs dikey (duvar) yüzey seçici — iki segmentli çip.
class _YuzeySecici extends StatelessWidget {
  const _YuzeySecici({required this.dikey, required this.onChanged});
  final bool dikey;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String etiket, IconData icon, bool deger) {
      final secili = dikey == deger;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(deger),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: secili
                  ? Colors.white
                  : Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: secili ? Colors.black : Colors.white),
                const SizedBox(width: 6),
                Text(
                  etiket,
                  style: TextStyle(
                    color: secili ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          seg('Duvar (dikey)', Icons.vertical_split_rounded, true),
          const SizedBox(width: 4),
          seg('Zemin (yatay)', Icons.horizontal_rule_rounded, false),
        ],
      ),
    );
  }
}

/// Başlangıç/bitiş nokta izi — kaç nokta seçildiğini görsel gösterir.
class _NoktaIzi extends StatelessWidget {
  const _NoktaIzi({required this.secili});

  /// Seçilmiş nokta sayısı (0, 1 veya 2).
  final int secili;

  @override
  Widget build(BuildContext context) {
    Widget nokta(String etiket, bool dolu) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dolu ? Colors.white : Colors.transparent,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: dolu
                ? const Icon(Icons.check, size: 13, color: Colors.black)
                : null,
          ),
          const SizedBox(height: 3),
          Text(etiket,
              style: const TextStyle(color: Colors.white, fontSize: 10.5)),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        nokta('Başlangıç', secili >= 1),
        Container(
          width: 40,
          height: 2,
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.white.withValues(alpha: secili >= 2 ? 1 : 0.4),
        ),
        nokta('Bitiş', secili >= 2),
      ],
    );
  }
}
