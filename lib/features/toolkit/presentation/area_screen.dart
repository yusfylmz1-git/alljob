import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/validators.dart';
import '../application/toolkit_calculators.dart';
import '../application/toolkit_models.dart';
import 'widgets/fire_secici.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Alan Hesaplayıcı (PRD-007 Faz B §6.1). Bir veya çok yüzey (en×boy) girilir,
/// kapı/pencere düşümü ve fire uygulanır → net m² (+ fire dâhil m²).
class AreaScreen extends StatefulWidget {
  const AreaScreen({super.key, this.arUzunlukM});

  /// AR ekranından aktarılan ölçülen uzunluk (m). Verilirse ilk yüzeyin "en"i
  /// bununla doldurulur ve sonuç kaynağı AR olarak işaretlenir.
  final double? arUzunlukM;

  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _YuzeyGirdi {
  final TextEditingController en = TextEditingController();
  final TextEditingController boy = TextEditingController();

  void dispose() {
    en.dispose();
    boy.dispose();
  }
}

class _AreaScreenState extends State<AreaScreen> {
  final List<_YuzeyGirdi> _yuzeyler = [_YuzeyGirdi()];
  final TextEditingController _dususm = TextEditingController();
  FireOrani _fire = FireOrani.yok;
  final TextEditingController _ozelFire = TextEditingController();
  AlanSonucu? _sonuc;

  /// AR'dan uzunluk aktarıldıysa sonuçta kaynak rozeti AR gösterilir.
  bool _arKaynakli = false;

  @override
  void initState() {
    super.initState();
    final ar = widget.arUzunlukM;
    if (ar != null && ar > 0) {
      // Gelen uzunluğu ilk yüzeyin "en"ine yaz (TR biçim); boy'u kullanıcı girer.
      _yuzeyler.first.en.text = trSayi(ar);
      _arKaynakli = true;
    }
  }

  @override
  void dispose() {
    for (final y in _yuzeyler) {
      y.dispose();
    }
    _dususm.dispose();
    _ozelFire.dispose();
    super.dispose();
  }

  void _hesapla() {
    final yuzeyler = <Yuzey>[];
    for (final g in _yuzeyler) {
      final en = Validators.parseTrAmount(g.en.text);
      final boy = Validators.parseTrAmount(g.boy.text);
      if (en != null && boy != null && en > 0 && boy > 0) {
        yuzeyler.add(Yuzey.dikdortgen(enM: en, boyM: boy));
      }
    }
    if (yuzeyler.isEmpty) {
      setState(() => _sonuc = null);
      return;
    }
    final dususm = Validators.parseTrAmount(_dususm.text) ?? 0;
    // Düşümü ilk yüzeye toplu uygula (tek düşüm alanı; seans toplamı korunur).
    final ilk = yuzeyler.first;
    yuzeyler[0] = Yuzey.dikdortgen(
      enM: ilk.enM!,
      boyM: ilk.boyM!,
      dususmM2: dususm,
    );
    final seans = OlcumSeansi(yuzeyler: yuzeyler);
    final ozel = _fire == FireOrani.ozel
        ? (Validators.parseTrAmount(_ozelFire.text) ?? 0) / 100.0
        : null;
    setState(() {
      _sonuc = alanHesapla(seans, fire: _fire, ozelFireOrani: ozel);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Alan Hesapla')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(compact: true),
          const SizedBox(height: 16),
          Text('Yüzeyler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          for (var i = 0; i < _yuzeyler.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: SayiAlani(
                      controller: _yuzeyler[i].en,
                      label: 'En',
                      suffix: 'm',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×'),
                  ),
                  Expanded(
                    child: SayiAlani(
                      controller: _yuzeyler[i].boy,
                      label: 'Boy',
                      suffix: 'm',
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: _yuzeyler.length > 1
                            ? palette.danger
                            : palette.inkMuted),
                    onPressed: _yuzeyler.length > 1
                        ? () => setState(() => _yuzeyler.removeAt(i).dispose())
                        : null,
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Yüzey ekle'),
              onPressed: () =>
                  setState(() => _yuzeyler.add(_YuzeyGirdi())),
            ),
          ),
          const SizedBox(height: 8),
          SayiAlani(
            controller: _dususm,
            label: 'Düşüm (kapı/pencere)',
            suffix: 'm²',
            hint: 'İsteğe bağlı',
          ),
          const SizedBox(height: 16),
          FireSecici(
            secili: _fire,
            ozelController: _ozelFire,
            onChanged: (f) => setState(() => _fire = f),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Hesapla'),
            onPressed: _hesapla,
          ),
          if (_sonuc != null) ...[
            const SizedBox(height: 20),
            SonucKarti(
              baslik: 'Sonuç',
              vurguDeger: 'Net alan: ${trSayi(_sonuc!.netM2)} m²',
              sonuc: _sonuc!,
              kaynak: _arKaynakli ? OlcuKaynagi.ar : null,
            ),
          ],
        ],
      ),
    );
  }
}
