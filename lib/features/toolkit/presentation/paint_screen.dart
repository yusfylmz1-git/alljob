import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../application/toolkit_calculators.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Boya Hesaplayıcı (PRD-007 Faz B §6.2). Alan + kat sayısı + m²/L verim →
/// tahmini litre. Sonuç her zaman "tahmini" olarak sunulur (asla "kesin").
class PaintScreen extends StatefulWidget {
  const PaintScreen({super.key});

  @override
  State<PaintScreen> createState() => _PaintScreenState();
}

class _PaintScreenState extends State<PaintScreen> {
  final TextEditingController _alan = TextEditingController();
  final TextEditingController _verim = TextEditingController(text: '10');
  int _kat = 2;
  BoyaSonucu? _sonuc;

  @override
  void dispose() {
    _alan.dispose();
    _verim.dispose();
    super.dispose();
  }

  void _hesapla() {
    final alan = Validators.parseTrAmount(_alan.text);
    if (alan == null || alan <= 0) {
      setState(() => _sonuc = null);
      return;
    }
    final verim = Validators.parseTrAmount(_verim.text) ?? 10;
    setState(() {
      _sonuc = boyaHesapla(
        alanM2: alan,
        katSayisi: _kat,
        verimM2PerLitre: verim,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boya Hesapla')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(compact: true),
          const SizedBox(height: 16),
          SayiAlani(
            controller: _alan,
            label: 'Boyanacak alan',
            suffix: 'm²',
          ),
          const SizedBox(height: 16),
          Text('Kat sayısı',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final k in [1, 2, 3])
                ChoiceChip(
                  label: Text('$k kat'),
                  selected: _kat == k,
                  onSelected: (_) => setState(() => _kat = k),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SayiAlani(
            controller: _verim,
            label: 'Verim (kutu etiketinden)',
            suffix: 'm²/L',
            hint: 'Tipik iç cephe ~10-12',
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
              vurguDeger:
                  'Tahmini boya: ${trSayi(_sonuc!.litre)} litre',
              sonuc: _sonuc!,
            ),
          ],
        ],
      ),
    );
  }
}
