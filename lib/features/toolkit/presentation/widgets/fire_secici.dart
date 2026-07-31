import 'package:flutter/material.dart';

import '../../application/toolkit_models.dart';
import 'sayi_alani.dart';

/// Fire (zayiat) oranı seçici: %0 / %5 / %10 / %15 / Özel. Ortak — Alan ve
/// Fayans ekranları paylaşır. "Özel" seçilince yüzde giriş alanı görünür.
class FireSecici extends StatelessWidget {
  const FireSecici({
    super.key,
    required this.secili,
    required this.onChanged,
    required this.ozelController,
  });

  final FireOrani secili;
  final ValueChanged<FireOrani> onChanged;
  final TextEditingController ozelController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fire payı',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in FireOrani.values)
              ChoiceChip(
                label: Text(f.etiket),
                selected: secili == f,
                onSelected: (_) => onChanged(f),
              ),
          ],
        ),
        if (secili == FireOrani.ozel) ...[
          const SizedBox(height: 10),
          SayiAlani(
            controller: ozelController,
            label: 'Özel fire',
            suffix: '%',
            hint: 'Örn. 8',
          ),
        ],
      ],
    );
  }
}
