import 'package:flutter/material.dart';

import 'app_accent.dart';

/// Kullanıcının Görünüm ayarından seçebildiği hazır VURGU rengi.
///
/// Her seçenek açık ve koyu tema için tam bir [AppAccent] taşır. Müşteri ve
/// usta modları BAĞIMSIZ birer seçenek saklar (aynı listeden seçilir), böylece
/// "müşteriyken mavi, ustayken yeşil" gibi kişisel bir düzen kurulabilir.
class AccentOption {
  const AccentOption({
    required this.id,
    required this.labelTR,
    required this.swatch,
    required this.light,
    required this.dark,
  });

  /// Kalıcı kayıt anahtarı (SharedPreferences'ta saklanır).
  final String id;
  final String labelTR;

  /// Seçim ekranındaki yuvarlak örnek renk.
  final Color swatch;

  final AppAccent light;
  final AppAccent dark;
}

// ── Mavi ────────────────────────────────────────────────────────────────
const AccentOption _blue = AccentOption(
  id: 'blue',
  labelTR: 'Mavi',
  swatch: Color(0xFF2563EB),
  light: AppAccent(
    primary: Color(0xFF2563EB),
    onPrimary: Colors.white,
    primaryDark: Color(0xFF1D4ED8),
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    inversePrimary: Color(0xFF93C5FD),
    heroTop: Color(0xFF1D4ED8),
    heroBottom: Color(0xFF172554),
  ),
  dark: AppAccent(
    primary: Color(0xFF6BA5FF),
    onPrimary: Color(0xFF0A2A5E),
    primaryDark: Color(0xFF3B82F6),
    primaryContainer: Color(0xFF1E3A8A),
    onPrimaryContainer: Color(0xFFDBEAFE),
    inversePrimary: Color(0xFF2563EB),
    heroTop: Color(0xFF1D4ED8),
    heroBottom: Color(0xFF172554),
  ),
);

// ── Zümrüt Yeşil ────────────────────────────────────────────────────────
const AccentOption _emerald = AccentOption(
  id: 'emerald',
  labelTR: 'Yeşil',
  swatch: Color(0xFF059669),
  light: AppAccent(
    primary: Color(0xFF059669),
    onPrimary: Colors.white,
    primaryDark: Color(0xFF047857),
    primaryContainer: Color(0xFFD1FAE5),
    onPrimaryContainer: Color(0xFF064E3B),
    inversePrimary: Color(0xFF6EE7B7),
    heroTop: Color(0xFF047857),
    heroBottom: Color(0xFF022C22),
  ),
  dark: AppAccent(
    primary: Color(0xFF34D399),
    onPrimary: Color(0xFF063D2E),
    primaryDark: Color(0xFF059669),
    primaryContainer: Color(0xFF064E3B),
    onPrimaryContainer: Color(0xFFD1FAE5),
    inversePrimary: Color(0xFF059669),
    heroTop: Color(0xFF047857),
    heroBottom: Color(0xFF022C22),
  ),
);

// ── Mor (Menekşe) ─────────────────────────────────────────────────────────
const AccentOption _violet = AccentOption(
  id: 'violet',
  labelTR: 'Mor',
  swatch: Color(0xFF7C3AED),
  light: AppAccent(
    primary: Color(0xFF7C3AED),
    onPrimary: Colors.white,
    primaryDark: Color(0xFF6D28D9),
    primaryContainer: Color(0xFFEDE9FE),
    onPrimaryContainer: Color(0xFF4C1D95),
    inversePrimary: Color(0xFFC4B5FD),
    heroTop: Color(0xFF6D28D9),
    heroBottom: Color(0xFF2E1065),
  ),
  dark: AppAccent(
    primary: Color(0xFFA78BFA),
    onPrimary: Color(0xFF2E1065),
    primaryDark: Color(0xFF7C3AED),
    primaryContainer: Color(0xFF4C1D95),
    onPrimaryContainer: Color(0xFFEDE9FE),
    inversePrimary: Color(0xFF7C3AED),
    heroTop: Color(0xFF6D28D9),
    heroBottom: Color(0xFF2E1065),
  ),
);

// ── Turuncu (marka) ───────────────────────────────────────────────────────
const AccentOption _orange = AccentOption(
  id: 'orange',
  labelTR: 'Turuncu',
  swatch: Color(0xFFEA580C),
  light: AppAccent(
    primary: Color(0xFFEA580C),
    onPrimary: Colors.white,
    primaryDark: Color(0xFFC2410C),
    primaryContainer: Color(0xFFFFEDD5),
    onPrimaryContainer: Color(0xFF7C2D12),
    inversePrimary: Color(0xFFFFB787),
    heroTop: Color(0xFFC2410C),
    heroBottom: Color(0xFF431407),
  ),
  dark: AppAccent(
    primary: Color(0xFFFF8A4C),
    onPrimary: Color(0xFF431407),
    primaryDark: Color(0xFFEA580C),
    primaryContainer: Color(0xFF7C2D12),
    onPrimaryContainer: Color(0xFFFFEDD5),
    inversePrimary: Color(0xFFEA580C),
    heroTop: Color(0xFFC2410C),
    heroBottom: Color(0xFF431407),
  ),
);

/// Seçilebilir tüm renkler (Görünüm ekranındaki sıra).
const List<AccentOption> kAccentOptions = [_blue, _emerald, _violet, _orange];

/// Varsayılan seçimler: müşteri mavi, usta yeşil (mod-bazlı ilk düzen).
const String kDefaultCustomerAccentId = 'blue';
const String kDefaultArtisanAccentId = 'emerald';

/// [id]'ye karşılık gelen seçenek; bilinmeyen/null ise [fallbackId] (yoksa ilk).
AccentOption accentById(String? id, {String fallbackId = kDefaultCustomerAccentId}) {
  for (final o in kAccentOptions) {
    if (o.id == id) return o;
  }
  for (final o in kAccentOptions) {
    if (o.id == fallbackId) return o;
  }
  return kAccentOptions.first;
}
