import 'package:flutter/material.dart';

/// Türkçe, 24 saat formatlı ve sade temalı tarih/saat seçicileri (Ajanda vb.).
class AppDateTimePickers {
  AppDateTimePickers._();

  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('tr', 'TR'),
      helpText: 'Tarih seçin',
      cancelText: 'Vazgeç',
      confirmText: 'Tamam',
      builder: (context, child) => _pickerTheme(context, child),
    );
  }

  static Future<TimeOfDay?> pickTime(
    BuildContext context, {
    required TimeOfDay initialTime,
  }) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Saat seçin',
      cancelText: 'Vazgeç',
      confirmText: 'Tamam',
      hourLabelText: 'Saat',
      minuteLabelText: 'Dakika',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: _pickerTheme(context, child),
        );
      },
    );
  }

  /// Tarih + saat sırayla; biri iptal edilirse null.
  static Future<DateTime?> pickDateTime(
    BuildContext context, {
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final now = DateTime.now();
    final base = initial.isBefore(firstDate) ? firstDate : initial;
    final date = await pickDate(
      context,
      initialDate: base.isBefore(now) && firstDate.isBefore(now)
          ? (now.isAfter(lastDate) ? lastDate : now)
          : base,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !context.mounted) return null;
    final time = await pickTime(
      context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static Widget _pickerTheme(BuildContext context, Widget? child) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        datePickerTheme: DatePickerThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          headerBackgroundColor: scheme.primary,
          headerForegroundColor: scheme.onPrimary,
          dayStyle: theme.textTheme.bodyMedium,
        ),
        timePickerTheme: TimePickerThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: scheme.surface,
          hourMinuteShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          dayPeriodShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          dialBackgroundColor: scheme.surfaceContainerHighest,
          entryModeIconColor: scheme.primary,
          helpTextStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
