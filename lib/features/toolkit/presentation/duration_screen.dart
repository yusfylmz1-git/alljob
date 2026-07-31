import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../application/toolkit_calculators.dart' show trSayi;
import '../application/toolkit_cost.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// İş Süresi Tahmini (PRD-007 Faz C §6.5). Alan + hız (m²/saat, meslek
/// şablonundan düzenlenebilir) + günlük çalışma saati → tahmini saat/gün.
class DurationScreen extends StatefulWidget {
  const DurationScreen({super.key});

  @override
  State<DurationScreen> createState() => _DurationScreenState();
}

/// Meslek başına tipik hız şablonu (m²/saat). Kullanıcı düzenleyebilir.
const List<({String ad, double hiz})> _sablonlar = [
  (ad: 'Boya', hiz: 15),
  (ad: 'Fayans', hiz: 3),
  (ad: 'Sıva', hiz: 5),
  (ad: 'Şap', hiz: 8),
];

class _DurationScreenState extends State<DurationScreen> {
  final TextEditingController _alan = TextEditingController();
  final TextEditingController _hiz = TextEditingController(text: '15');
  final TextEditingController _gunlukSaat = TextEditingController(text: '8');
  SureSonucu? _sonuc;

  @override
  void dispose() {
    _alan.dispose();
    _hiz.dispose();
    _gunlukSaat.dispose();
    super.dispose();
  }

  void _hesapla() {
    final alan = Validators.parseTrAmount(_alan.text);
    if (alan == null || alan <= 0) {
      setState(() => _sonuc = null);
      return;
    }
    final hiz = Validators.parseTrAmount(_hiz.text) ?? 1;
    final gunluk = Validators.parseTrAmount(_gunlukSaat.text) ?? 8;
    setState(() {
      _sonuc = sureHesapla(alanM2: alan, m2PerSaat: hiz, gunlukSaat: gunluk);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İş Süresi Tahmini')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(compact: true),
          const SizedBox(height: 16),
          SayiAlani(controller: _alan, label: 'İşin alanı', suffix: 'm²'),
          const SizedBox(height: 16),
          Text('Meslek şablonu (hızı doldurur)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in _sablonlar)
                ActionChip(
                  label: Text(s.ad),
                  onPressed: () =>
                      setState(() => _hiz.text = trSayi(s.hiz)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SayiAlani(
            controller: _hiz,
            label: 'Hız',
            suffix: 'm²/saat',
            hint: 'Şablondan seç veya elle gir',
          ),
          const SizedBox(height: 12),
          SayiAlani(
            controller: _gunlukSaat,
            label: 'Günlük çalışma',
            suffix: 'saat',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.schedule_outlined),
            label: const Text('Hesapla'),
            onPressed: _hesapla,
          ),
          if (_sonuc != null) ...[
            const SizedBox(height: 20),
            SonucKarti(
              baslik: 'Tahmini süre',
              vurguDeger:
                  '${trSayi(_sonuc!.saat)} saat (~${trSayi(_sonuc!.gun)} gün)',
              sonuc: _sonuc!,
            ),
          ],
        ],
      ),
    );
  }
}
