import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../application/toolkit_calculators.dart';
import '../application/toolkit_models.dart';
import 'widgets/fire_secici.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/sonuc_karti.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Fayans Hesaplayıcı (PRD-007 Faz B §6.3). Kaplama alanı + fayans ebadı (cm)
/// + derz (mm) + fire → tahmini adet (yukarı yuvarlanır).
class TileScreen extends StatefulWidget {
  const TileScreen({super.key});

  @override
  State<TileScreen> createState() => _TileScreenState();
}

class _TileScreenState extends State<TileScreen> {
  final TextEditingController _alan = TextEditingController();
  final TextEditingController _en = TextEditingController();
  final TextEditingController _boy = TextEditingController();
  final TextEditingController _derz = TextEditingController(text: '2');
  FireOrani _fire = FireOrani.on;
  final TextEditingController _ozelFire = TextEditingController();
  FayansSonucu? _sonuc;

  @override
  void dispose() {
    _alan.dispose();
    _en.dispose();
    _boy.dispose();
    _derz.dispose();
    _ozelFire.dispose();
    super.dispose();
  }

  void _hesapla() {
    final alan = Validators.parseTrAmount(_alan.text);
    final en = Validators.parseTrAmount(_en.text);
    final boy = Validators.parseTrAmount(_boy.text);
    if (alan == null || alan <= 0 || en == null || en <= 0 ||
        boy == null || boy <= 0) {
      setState(() => _sonuc = null);
      return;
    }
    final derz = Validators.parseTrAmount(_derz.text) ?? 0;
    final ozel = _fire == FireOrani.ozel
        ? (Validators.parseTrAmount(_ozelFire.text) ?? 0) / 100.0
        : null;
    setState(() {
      _sonuc = fayansHesapla(
        alanM2: alan,
        fayansEnCm: en,
        fayansBoyCm: boy,
        derzMm: derz,
        fire: _fire,
        ozelFireOrani: ozel,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fayans Hesapla')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(compact: true),
          const SizedBox(height: 16),
          SayiAlani(
            controller: _alan,
            label: 'Kaplama alanı',
            suffix: 'm²',
          ),
          const SizedBox(height: 16),
          Text('Fayans ebadı',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SayiAlani(controller: _en, label: 'En', suffix: 'cm'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
              Expanded(
                child: SayiAlani(controller: _boy, label: 'Boy', suffix: 'cm'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SayiAlani(
            controller: _derz,
            label: 'Derz (fuga) payı',
            suffix: 'mm',
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
              vurguDeger: 'Tahmini ihtiyaç: ~${_sonuc!.adet} adet',
              sonuc: _sonuc!,
            ),
          ],
        ],
      ),
    );
  }
}
