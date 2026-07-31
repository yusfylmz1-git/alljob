import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/validators.dart';
import '../application/toolkit_calculators.dart';
import '../application/toolkit_models.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Hesaplanacak malzeme türü. Akışın ilk adımında seçilir; sorular ve sonuç
/// buna göre şekillenir.
enum MalzemeTuru {
  fayans('Fayans / Seramik', Icons.grid_on_rounded, Color(0xFFEA580C)),
  boya('Boya', Icons.format_paint_rounded, Color(0xFF2563EB)),
  parke('Parke / Laminat', Icons.view_day_rounded, Color(0xFF7C3AED)),
  alan('Sadece Alan', Icons.square_foot_rounded, Color(0xFF059669));

  const MalzemeTuru(this.baslik, this.icon, this.renk);
  final String baslik;
  final IconData icon;
  final Color renk;
}

/// Yönlendirmeli ölçüm & malzeme hesabı (PRD-007 §6).
///
/// Akış: **1) Malzeme seç → 2) Alanı ölç (AR veya elle, en×boy) → 3) Malzemeye
/// özel sorular → 4) Direkt sonuç** (ör. "~X kutu fayans"). AR ile gelen
/// uzunluk bir kenar olarak ölçüme aktarılır (query `ar_uzunluk`).
class MeasureFlowScreen extends StatefulWidget {
  const MeasureFlowScreen({super.key, this.arUzunlukM});

  /// AR ekranından "aktar" ile dönen uzunluk (m) — en alanına ön-doldurulur.
  final double? arUzunlukM;

  @override
  State<MeasureFlowScreen> createState() => _MeasureFlowScreenState();
}

enum _Adim { malzeme, olcum, sorular, sonuc }

class _MeasureFlowScreenState extends State<MeasureFlowScreen> {
  _Adim _adim = _Adim.malzeme;
  MalzemeTuru? _malzeme;

  // Adım 2 — alan ölçüsü (en × boy, m). AR'dan gelen değer en'e düşer.
  final _enCtrl = TextEditingController();
  final _boyCtrl = TextEditingController();
  OlcuKaynagi _kaynak = OlcuKaynagi.manuel;

  // Adım 3 — malzemeye özel girdiler.
  final _fayansEnCtrl = TextEditingController(text: '30');
  final _fayansBoyCtrl = TextEditingController(text: '60');
  final _katCtrl = TextEditingController(text: '2');
  final _paketCtrl = TextEditingController(text: '2');
  FireOrani _fire = FireOrani.on;

  HesapSonucu? _sonuc;

  @override
  void initState() {
    super.initState();
    if (widget.arUzunlukM != null && widget.arUzunlukM! > 0) {
      _enCtrl.text = trSayi(widget.arUzunlukM!);
      _kaynak = OlcuKaynagi.ar;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _enCtrl,
      _boyCtrl,
      _fayansEnCtrl,
      _fayansBoyCtrl,
      _katCtrl,
      _paketCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _alanM2 {
    final en = Validators.parseTrAmount(_enCtrl.text) ?? 0;
    final boy = Validators.parseTrAmount(_boyCtrl.text) ?? 0;
    return en * boy;
  }

  void _geri() {
    switch (_adim) {
      case _Adim.malzeme:
        context.pop();
      case _Adim.olcum:
        setState(() => _adim = _Adim.malzeme);
      case _Adim.sorular:
        setState(() => _adim = _Adim.olcum);
      case _Adim.sonuc:
        setState(() => _adim = _Adim.sorular);
    }
  }

  void _malzemeSec(MalzemeTuru m) {
    setState(() {
      _malzeme = m;
      _adim = _Adim.olcum;
    });
  }

  void _olcumIleri() {
    if (_alanM2 <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Önce geçerli bir en ve boy girin (ör. 3 × 4).'),
        ));
      return;
    }
    // "Sadece alan" için soru adımı yok — doğrudan sonuç.
    setState(() => _adim =
        _malzeme == MalzemeTuru.alan ? _Adim.sonuc : _Adim.sorular);
    if (_malzeme == MalzemeTuru.alan) _hesapla();
  }

  Future<void> _arAc() async {
    // AR ekranı ölçtüğü uzunluğu bu akışa geri getirir (Alan rotası zaten
    // ar_uzunluk query'sini biliyor; burada akışa özel geri dönüş kullanırız).
    HapticFeedback.selectionClick();
    // ret=1: AR ekranı "aktar" yerine ölçtüğü uzunluğu pop ile geri döndürür.
    final sonuc = await context.push<double>('${RoutePaths.toolkitAr}?ret=1');
    if (sonuc != null && sonuc > 0 && mounted) {
      setState(() {
        _enCtrl.text = trSayi(sonuc);
        _kaynak = OlcuKaynagi.ar;
      });
    }
  }

  void _hesapla() {
    final alan = _alanM2;
    final HesapSonucu s;
    switch (_malzeme!) {
      case MalzemeTuru.fayans:
        s = fayansHesapla(
          alanM2: alan,
          fayansEnCm: Validators.parseTrAmount(_fayansEnCtrl.text) ?? 0,
          fayansBoyCm: Validators.parseTrAmount(_fayansBoyCtrl.text) ?? 0,
          fire: _fire,
        );
      case MalzemeTuru.boya:
        s = boyaHesapla(
          alanM2: alan,
          katSayisi: (Validators.parseTrAmount(_katCtrl.text) ?? 1).round(),
        );
      case MalzemeTuru.parke:
        s = parkeHesapla(
          alanM2: alan,
          paketM2: Validators.parseTrAmount(_paketCtrl.text) ?? 2.0,
          fire: _fire,
        );
      case MalzemeTuru.alan:
        s = alanHesapla(
          OlcumSeansi(
            yuzeyler: [Yuzey.alan(alanM2: alan)],
            kaynak: _kaynak,
          ),
        );
    }
    setState(() {
      _sonuc = s;
      _adim = _Adim.sonuc;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _geri,
        ),
        title: Text(switch (_adim) {
          _Adim.malzeme => 'Ne hesaplayalım?',
          _Adim.olcum => 'Alanı ölç',
          _Adim.sorular => _malzeme?.baslik ?? 'Detaylar',
          _Adim.sonuc => 'Sonuç',
        }),
        bottom: _AdimGostergesi(adim: _adim, malzeme: _malzeme),
      ),
      body: SafeArea(
        child: switch (_adim) {
          _Adim.malzeme => _MalzemeAdimi(onSec: _malzemeSec),
          _Adim.olcum => _OlcumAdimi(
              enCtrl: _enCtrl,
              boyCtrl: _boyCtrl,
              kaynak: _kaynak,
              onAr: _arAc,
              onIleri: _olcumIleri,
            ),
          _Adim.sorular => _SorularAdimi(
              malzeme: _malzeme!,
              fayansEnCtrl: _fayansEnCtrl,
              fayansBoyCtrl: _fayansBoyCtrl,
              katCtrl: _katCtrl,
              paketCtrl: _paketCtrl,
              fire: _fire,
              onFire: (f) => setState(() => _fire = f),
              onHesapla: _hesapla,
            ),
          _Adim.sonuc => _SonucAdimi(
              malzeme: _malzeme!,
              sonuc: _sonuc!,
              kaynak: _kaynak,
              onYeni: () => setState(() {
                _sonuc = null;
                _adim = _Adim.malzeme;
              }),
            ),
        },
      ),
    );
  }
}

/// Üst ince adım göstergesi (4 nokta). "Sadece alan"da soru adımı atlanır.
class _AdimGostergesi extends StatelessWidget implements PreferredSizeWidget {
  const _AdimGostergesi({required this.adim, required this.malzeme});
  final _Adim adim;
  final MalzemeTuru? malzeme;

  @override
  Size get preferredSize => const Size.fromHeight(6);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final aktif = _Adim.values.indexOf(adim);
    return SizedBox(
      height: 6,
      child: Row(
        children: [
          for (var i = 0; i < _Adim.values.length; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 3,
                decoration: BoxDecoration(
                  color: i <= aktif
                      ? palette.primary
                      : palette.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Adım 1 — Malzeme seçimi
// ---------------------------------------------------------------------------

class _MalzemeAdimi extends StatelessWidget {
  const _MalzemeAdimi({required this.onSec});
  final ValueChanged<MalzemeTuru> onSec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Neyi hesaplamak istiyorsun?',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Seçtiğin malzemeye göre sana birkaç soru sorup ihtiyacı '
          'hesaplayacağız.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (final m in MalzemeTuru.values) ...[
          _MalzemeKart(malzeme: m, onTap: () => onSec(m)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MalzemeKart extends StatelessWidget {
  const _MalzemeKart({required this.malzeme, required this.onTap});
  final MalzemeTuru malzeme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: malzeme.renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(malzeme.icon, color: malzeme.renk, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  malzeme.baslik,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Adım 2 — Ölçüm (AR veya elle en × boy)
// ---------------------------------------------------------------------------

class _OlcumAdimi extends StatelessWidget {
  const _OlcumAdimi({
    required this.enCtrl,
    required this.boyCtrl,
    required this.kaynak,
    required this.onAr,
    required this.onIleri,
  });

  final TextEditingController enCtrl;
  final TextEditingController boyCtrl;
  final OlcuKaynagi kaynak;
  final VoidCallback onAr;
  final VoidCallback onIleri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TahminiUyariBanner(compact: true),
        const SizedBox(height: 16),
        Text(
          'Alanı ölç',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Genişlik ve uzunluğu gir; ya da kamerayla kaba ölçüm al. '
          'Kamerayla önce bir kenarı ölçüp buraya aktarabilirsin.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.view_in_ar_rounded),
          label: const Text('Kamerayla ölç (AR)'),
          onPressed: onAr,
        ),
        if (kaynak == OlcuKaynagi.ar) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 16, color: palette.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AR ölçümü genişliğe aktarıldı. Uzunluğu da girip devam et.',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: palette.success),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SayiAlani(controller: enCtrl, label: 'Genişlik', suffix: 'm'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('×', style: TextStyle(fontSize: 18)),
            ),
            Expanded(
              child: SayiAlani(controller: boyCtrl, label: 'Uzunluk', suffix: 'm'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Devam'),
          onPressed: onIleri,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Adım 3 — Malzemeye özel sorular
// ---------------------------------------------------------------------------

class _SorularAdimi extends StatelessWidget {
  const _SorularAdimi({
    required this.malzeme,
    required this.fayansEnCtrl,
    required this.fayansBoyCtrl,
    required this.katCtrl,
    required this.paketCtrl,
    required this.fire,
    required this.onFire,
    required this.onHesapla,
  });

  final MalzemeTuru malzeme;
  final TextEditingController fayansEnCtrl;
  final TextEditingController fayansBoyCtrl;
  final TextEditingController katCtrl;
  final TextEditingController paketCtrl;
  final FireOrani fire;
  final ValueChanged<FireOrani> onFire;
  final VoidCallback onHesapla;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${malzeme.baslik} için birkaç detay',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (malzeme == MalzemeTuru.fayans) ...[
          Row(
            children: [
              Expanded(
                child: SayiAlani(
                    controller: fayansEnCtrl, label: 'Fayans eni', suffix: 'cm'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SayiAlani(
                    controller: fayansBoyCtrl,
                    label: 'Fayans boyu',
                    suffix: 'cm'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FireSecimi(fire: fire, onFire: onFire),
        ] else if (malzeme == MalzemeTuru.boya) ...[
          SayiAlani(controller: katCtrl, label: 'Kaç kat boyanacak?'),
        ] else if (malzeme == MalzemeTuru.parke) ...[
          SayiAlani(
              controller: paketCtrl,
              label: 'Paket başına alan',
              suffix: 'm²'),
          const SizedBox(height: 16),
          _FireSecimi(fire: fire, onFire: onFire),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.calculate_rounded),
          label: const Text('Hesapla'),
          onPressed: onHesapla,
        ),
      ],
    );
  }
}

/// Fire (zayiat) oranı seçici — segment gibi çipler.
class _FireSecimi extends StatelessWidget {
  const _FireSecimi({required this.fire, required this.onFire});
  final FireOrani fire;
  final ValueChanged<FireOrani> onFire;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fire payı (kesim kaybı)',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in FireOrani.values)
              if (f != FireOrani.ozel)
                ChoiceChip(
                  label: Text(f.etiket),
                  selected: fire == f,
                  onSelected: (_) => onFire(f),
                ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Adım 4 — Sonuç
// ---------------------------------------------------------------------------

class _SonucAdimi extends StatelessWidget {
  const _SonucAdimi({
    required this.malzeme,
    required this.sonuc,
    required this.kaynak,
    required this.onYeni,
  });

  final MalzemeTuru malzeme;
  final HesapSonucu sonuc;
  final OlcuKaynagi kaynak;
  final VoidCallback onYeni;

  /// Sonucun "manşet" satırı — malzemeye göre en anlamlı tek çıktı.
  String get _vurgu {
    final s = sonuc;
    if (s is FayansSonucu) return '~${s.adet} adet fayans';
    if (s is ParkeSonucu) return '~${s.paketAdedi} paket parke';
    if (s is BoyaSonucu) return '~${trSayi(s.litre)} litre boya';
    if (s is AlanSonucu) return '${trSayi(s.netM2)} m²';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SonucKarti(
          baslik: '${malzeme.baslik} ihtiyacı',
          vurguDeger: _vurgu,
          sonuc: sonuc,
          kaynak: kaynak,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Yeni hesap'),
          onPressed: onYeni,
        ),
      ],
    );
  }
}
