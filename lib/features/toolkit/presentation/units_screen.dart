import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../application/toolkit_calculators.dart' show trSayi;
import '../application/toolkit_cost.dart';
import 'widgets/sayi_alani.dart';
import 'widgets/tahmini_uyari_banner.dart';

/// Birim Dönüştürücü (PRD-007 Faz C §6.5). Grup seç (uzunluk/alan/hacim/ağırlık),
/// kaynak ve hedef birim, değer → anlık dönüşüm.
class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  final TextEditingController _deger = TextEditingController();
  BirimGrubu _grup = BirimGrubu.uzunluk;
  late Birim _kaynak;
  late Birim _hedef;

  @override
  void initState() {
    super.initState();
    _grupAyarla(_grup);
  }

  @override
  void dispose() {
    _deger.dispose();
    super.dispose();
  }

  void _grupAyarla(BirimGrubu g) {
    final liste = kBirimTablosu[g]!;
    _grup = g;
    _kaynak = liste.first;
    _hedef = liste.length > 1 ? liste[1] : liste.first;
  }

  String get _sonucMetni {
    final v = Validators.parseTrAmount(_deger.text);
    if (v == null) return '—';
    final r = birimCevir(v, _kaynak, _hedef);
    return '${trSayi(r, ondalik: 4)} ${_hedef.ad}';
  }

  static const Map<BirimGrubu, String> _grupAd = {
    BirimGrubu.uzunluk: 'Uzunluk',
    BirimGrubu.alan: 'Alan',
    BirimGrubu.hacim: 'Hacim',
    BirimGrubu.agirlik: 'Ağırlık',
  };

  @override
  Widget build(BuildContext context) {
    final liste = kBirimTablosu[_grup]!;
    return Scaffold(
      appBar: AppBar(title: const Text('Birim Dönüştürücü')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const TahminiUyariBanner(compact: true),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final g in BirimGrubu.values)
                ChoiceChip(
                  label: Text(_grupAd[g]!),
                  selected: _grup == g,
                  onSelected: (_) => setState(() => _grupAyarla(g)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SayiAlani(controller: _deger, label: 'Değer'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Birim>(
                  initialValue: _kaynak,
                  decoration: const InputDecoration(
                    labelText: 'Kaynak',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final b in liste)
                      DropdownMenuItem(value: b, child: Text(b.ad)),
                  ],
                  onChanged: (b) => setState(() => _kaynak = b ?? _kaynak),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward),
              ),
              Expanded(
                child: DropdownButtonFormField<Birim>(
                  initialValue: _hedef,
                  decoration: const InputDecoration(
                    labelText: 'Hedef',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final b in liste)
                      DropdownMenuItem(value: b, child: Text(b.ad)),
                  ],
                  onChanged: (b) => setState(() => _hedef = b ?? _hedef),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Dönüştür'),
            onPressed: () => setState(() {}),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _sonucMetni,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
