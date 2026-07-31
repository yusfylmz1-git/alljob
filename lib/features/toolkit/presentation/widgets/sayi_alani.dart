import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Usta Çantası araçlarında ortak sayısal giriş alanı. TR ondalık (virgül)
/// kabul eder; parse `Validators.parseTrAmount` ile yapılır (bu widget yalnız
/// klavye/biçim sunar, değeri controller üstünden okuruz).
class SayiAlani extends StatelessWidget {
  const SayiAlani({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.hint,
  });

  final TextEditingController controller;
  final String label;

  /// Birim eki (ör. "m", "cm", "m²").
  final String? suffix;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Yalnız rakam, virgül ve nokta (TR ondalık + binlik).
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
