import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tutarlı bildirim (snackbar) gösterimi için yardımcı eklenti.
extension SnackbarHelper on BuildContext {
  void showSuccess(String message) => _show(message, AppColors.success, Icons.check_circle_outline);
  void showError(String message) => _show(message, AppColors.danger, Icons.error_outline);
  void showInfo(String message) => _show(message, AppColors.secondary, Icons.info_outline);

  void _show(String message, Color color, IconData icon) {
    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
  }
}
