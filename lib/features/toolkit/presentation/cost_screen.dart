import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../application/toolkit_calculators.dart' show trSayi;
import '../application/toolkit_cost.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Maliyet Hesaplayıcı (PRD-007 Faz C §6.4). Malzeme + işçilik + yol + diğer
/// → toplam maliyet.
class CostScreen extends StatefulWidget {
  const CostScreen({super.key});

  @override
  State<CostScreen> createState() => _CostScreenState();
}

class _CostScreenState extends State<CostScreen> {
  final TextEditingController _malzeme = TextEditingController();
  final TextEditingController _iscilik = TextEditingController();
  final TextEditingController _yol = TextEditingController();
  final TextEditingController _diger = TextEditingController();
  MaliyetSonucu? _sonuc;

  @override
  void dispose() {
    _malzeme.dispose();
    _iscilik.dispose();
    _yol.dispose();
    _diger.dispose();
    super.dispose();
  }

  void _hesapla() {
    double v(TextEditingController c) => Validators.parseTrAmount(c.text) ?? 0;
    setState(() {
      _sonuc = maliyetHesapla(
        malzeme: v(_malzeme),
        iscilik: v(_iscilik),
        yol: v(_yol),
        diger: v(_diger),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maliyet Hesapla')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(compact: true),
          const SizedBox(height: 16),
          SayiAlani(controller: _malzeme, label: 'Malzeme', suffix: 'TL'),
          const SizedBox(height: 12),
          SayiAlani(controller: _iscilik, label: 'İşçilik', suffix: 'TL'),
          const SizedBox(height: 12),
          SayiAlani(controller: _yol, label: 'Yol / ulaşım', suffix: 'TL'),
          const SizedBox(height: 12),
          SayiAlani(controller: _diger, label: 'Diğer', suffix: 'TL'),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Hesapla'),
            onPressed: _hesapla,
          ),
          if (_sonuc != null) ...[
            const SizedBox(height: 20),
            SonucKarti(
              baslik: 'Toplam maliyet',
              vurguDeger: '${trSayi(_sonuc!.toplam)} TL',
              sonuc: _sonuc!,
            ),
          ],
        ],
      ),
    );
  }
}
