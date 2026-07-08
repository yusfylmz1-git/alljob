import 'package:flutter/material.dart';

/// Marka renk paleti — elle seçilmiş, tutarlı tonlar.
/// Tema artık `ColorScheme.fromSeed` türetmesi yerine bu paleti birebir
/// kullanır; böylece her yüzey/vurgu rengi kontrollü ve profesyoneldir.
class AppColors {
  AppColors._();

  // ── Marka ──────────────────────────────────────────────────────────────
  /// Ana marka rengi: enerjik ama olgun bir turuncu.
  static const Color primary = Color(0xFFEA580C);

  /// Basılı/hover durumları için bir ton koyusu.
  static const Color primaryDark = Color(0xFFC2410C);

  /// Çok açık turuncu yüzey (rozet/ikon arka planları).
  static const Color primaryContainer = Color(0xFFFFEDD5);
  static const Color onPrimaryContainer = Color(0xFF7C2D12);

  /// İkincil marka rengi: güven veren koyu lacivert (başlık/hero yüzeyleri).
  static const Color secondary = Color(0xFF15304B);
  static const Color secondaryContainer = Color(0xFFDCE7F3);
  static const Color onSecondaryContainer = Color(0xFF102A43);

  // ── Mürekkep (metin) tonları ──────────────────────────────────────────
  static const Color ink = Color(0xFF101828); // ana metin
  static const Color inkMuted = Color(0xFF475467); // ikincil metin
  static const Color inkFaint = Color(0xFF98A2B3); // ipucu/pasif metin

  // ── Yüzeyler ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFAFAFB); // serin beyaz sayfa zemini
  static const Color surface = Colors.white; // kart/yüzey
  static const Color surfaceMuted = Color(0xFFF2F4F7); // dolgu alanları
  static const Color border = Color(0xFFE4E7EC); // ince kenarlar
  static const Color borderStrong = Color(0xFFD0D5DD);

  /// Kart/yüzey ayrıştırıcıları için çok ince (nefes alan) çizgi rengi.
  static const Color hairline = Color(0xFFEEF0F3);

  // ── Semantik renkler ──────────────────────────────────────────────────
  static const Color success = Color(0xFF039855);
  static const Color successSurface = Color(0xFFE7F6EF);
  static const Color warning = Color(0xFFDC6803);
  static const Color warningSurface = Color(0xFFFEF0C7);
  static const Color danger = Color(0xFFD92D20);
  static const Color dangerSurface = Color(0xFFFEE4E2);
  static const Color info = Color(0xFF1570EF);
  static const Color infoSurface = Color(0xFFE0EDFF);

  /// "Doğrulanmış Usta" mavi tik.
  static const Color verified = Color(0xFF1570EF);

  /// Puan yıldızı.
  static const Color star = Color(0xFFF79009);

  /// Premium altın vurgusu.
  static const Color premium = Color(0xFFB45309);
  static const Color premiumSurface = Color(0xFFFDF2DF);

  /// Geriye dönük uyumluluk: eski kodda kullanılan tohum rengi.
  static const Color brandSeed = primary;

  // ── Gradyanlar ────────────────────────────────────────────────────────
  /// Hero/başlık alanları için lacivert gradyan.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B3A5C), Color(0xFF0F2438)],
  );

  /// Marka vurgu gradyanı (logo rozeti, premium kart vb.).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
  );

  /// "Müsait" durumundaki canlı yeşil avatar halkası (kart + profil ortak).
  static const LinearGradient availableRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF059669)],
  );
}
