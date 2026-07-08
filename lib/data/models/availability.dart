// Ustanın çalışma takvimi / canlı müsaitlik modeli (PRD §3 "Çalışma Takvimi").
//
// Müsaitlik üç alanın birleşiminden hesaplanır (Firestore §4):
//   - manualPause    : "Geçici Olarak Müsait Değilim" — her şeyi geçersiz kılar.
//   - alwaysAvailable: "Her Zaman Müsait".
//   - weeklySchedule : "Haftalık gün ve saat planı".
//
// Platformun temel farklılaştırıcısı canlı müsaitliktir: müşteri yalnızca o an
// hizmet vermeye hazır ustaları görebilmelidir.

/// Haftanın bir günü için müsaitlik penceresi.
/// [weekday] `DateTime.weekday` ile aynıdır: 1=Pazartesi ... 7=Pazar.
/// Saatler gece yarısından itibaren dakika cinsindendir (0..1439).
class DayAvailability {
  const DayAvailability({
    required this.weekday,
    required this.enabled,
    this.startMinute = 9 * 60, // 09:00
    this.endMinute = 18 * 60, // 18:00
  });

  final int weekday;
  final bool enabled;
  final int startMinute;
  final int endMinute;

  bool containsTime(int minuteOfDay) =>
      enabled && minuteOfDay >= startMinute && minuteOfDay < endMinute;

  static String formatMinute(int m) {
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final min = (m % 60).toString().padLeft(2, '0');
    return '$h:$min';
  }

  /// "HH:mm" -> gece yarısından itibaren dakika. Hatalıysa [fallback].
  static int parseMinute(String? hhmm, int fallback) {
    if (hhmm == null) return fallback;
    final parts = hhmm.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return h * 60 + m;
  }

  String get startLabel => formatMinute(startMinute);
  String get endLabel => formatMinute(endMinute);

  DayAvailability copyWith({bool? enabled, int? startMinute, int? endMinute}) =>
      DayAvailability(
        weekday: weekday,
        enabled: enabled ?? this.enabled,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
      );

  /// Firestore gün nesnesi (PRD §4). Kapalı günlerde yalnızca `enabled` yazılır.
  Map<String, dynamic> toMap() => enabled
      ? {'enabled': true, 'start': startLabel, 'end': endLabel}
      : {'enabled': false};

  factory DayAvailability.fromMap(int weekday, Map<String, dynamic> m) =>
      DayAvailability(
        weekday: weekday,
        enabled: (m['enabled'] as bool?) ?? false,
        startMinute: parseMinute(m['start'] as String?, 9 * 60),
        endMinute: parseMinute(m['end'] as String?, 18 * 60),
      );
}

/// Yedi günlük çalışma planı. Her zaman 7 gün (Pzt..Paz) içerir.
class WeeklySchedule {
  const WeeklySchedule(this.days);

  final List<DayAvailability> days;

  /// Tüm günler kapalı başlangıç planı.
  factory WeeklySchedule.empty() => WeeklySchedule(
        List.generate(
          7,
          (i) => DayAvailability(weekday: i + 1, enabled: false),
        ),
      );

  DayAvailability dayFor(int weekday) =>
      days.firstWhere((d) => d.weekday == weekday,
          orElse: () => DayAvailability(weekday: weekday, enabled: false));

  bool isOpenAt(DateTime t) {
    final day = dayFor(t.weekday);
    return day.containsTime(t.hour * 60 + t.minute);
  }

  /// Belirtilen günü [transform] ile değiştirilmiş yeni bir plan döner.
  WeeklySchedule withDay(int weekday, DayAvailability Function(DayAvailability) transform) {
    return WeeklySchedule([
      for (final d in days) d.weekday == weekday ? transform(d) : d,
    ]);
  }

  /// Firestore gün-adlı harita (PRD §4): { "monday": {...}, ... }.
  Map<String, dynamic> toMap() => {
        for (var wd = 1; wd <= 7; wd++) _enKeys[wd - 1]: dayFor(wd).toMap(),
      };

  factory WeeklySchedule.fromMap(Map? raw) {
    if (raw == null || raw.isEmpty) return WeeklySchedule.empty();
    return WeeklySchedule([
      for (var wd = 1; wd <= 7; wd++)
        raw[_enKeys[wd - 1]] is Map
            ? DayAvailability.fromMap(
                wd, Map<String, dynamic>.from(raw[_enKeys[wd - 1]] as Map))
            : DayAvailability(weekday: wd, enabled: false),
    ]);
  }

  // Firestore anahtarları (İngilizce gün adları) — weekday sırasıyla.
  static const _enKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const weekdayNamesTR = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static String weekdayName(int weekday) => weekdayNamesTR[weekday - 1];
}

/// Usta panelindeki müsaitlik kipi seçimi (üç alanın kullanıcı dostu özeti).
enum AvailabilityMode { always, weekly, paused }
