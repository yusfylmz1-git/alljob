import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../application/toolkit_calculators.dart' show trSayi;
import '../application/toolkit_cost.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Kâr Hesaplayıcı (PRD-007 Faz C §6.4). Maliyet + kâr (% veya sabit) → satış.
class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});

  @override
  State<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends State<ProfitScreen> {
  final TextEditingController _maliyet = TextEditingController();
  final TextEditingController _deger = TextEditingController();
  KarYontemi _yontem = KarYontemi.yuzde;
  KarSonucu? _sonuc;

  @override
  void dispose() {
    _maliyet.dispose();
    _deger.dispose();
    super.dispose();
  }

  void _hesapla() {
    final maliyet = Validators.parseTrAmount(_maliyet.text);
    if (maliyet == null || maliyet < 0) {
      setState(() => _sonuc = null);
      return;
    }
    final deger = Validators.parseTrAmount(_deger.text) ?? 0;
    setState(() {
      _sonuc = karHesapla(maliyet: maliyet, yontem: _yontem, deger: deger);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kâr Hesapla')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(compact: true),
          const SizedBox(height: 16),
          SayiAlani(controller: _maliyet, label: 'Maliyet', suffix: 'TL'),
          const SizedBox(height: 16),
          Text('Kâr yöntemi',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Yüzde (%)'),
                selected: _yontem == KarYontemi.yuzde,
                onSelected: (_) =>
                    setState(() => _yontem = KarYontemi.yuzde),
              ),
              ChoiceChip(
                label: const Text('Sabit (TL)'),
                selected: _yontem == KarYontemi.sabit,
                onSelected: (_) =>
                    setState(() => _yontem = KarYontemi.sabit),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SayiAlani(
            controller: _deger,
            label: _yontem == KarYontemi.yuzde ? 'Kâr oranı' : 'Kâr tutarı',
            suffix: _yontem == KarYontemi.yuzde ? '%' : 'TL',
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
              baslik: 'Satış fiyatı',
              vurguDeger: '${trSayi(_sonuc!.satis)} TL',
              sonuc: _sonuc!,
            ),
          ],
        ],
      ),
    );
  }
}
