/// Usta Çantası (PRD-007) çekirdek domain modelleri.
///
/// Bu katman **saf Dart**tır: Flutter, Firebase veya UI bağımlılığı yoktur;
/// böylece hesaplayıcılar unit test ile doğrulanabilir. Faz A'da yalnız
/// iskelet tipler tanımlıdır; hesap formülleri Faz B/C'de bu tipleri kullanır.
///
/// Kritik ilke: tüm ölçüm ve ihtiyaçlar **tahminidir** (bkz. [HesapSonucu]).
library;

import 'dart:math' as math;

/// Ölçünün nereden geldiği: elle giriş veya (Faz D+) AR kamera.
enum OlcuKaynagi {
  manuel,
  ar;

  /// Sonuç ekranındaki kaynak rozeti metni.
  String get etiket => switch (this) {
        OlcuKaynagi.manuel => 'Manuel',
        OlcuKaynagi.ar => 'AR',
      };
}

/// Malzeme fire (zayiat) oranı. Standart seçenekler + kullanıcı tanımlı özel.
enum FireOrani {
  yok(0.0, '%0'),
  bes(0.05, '%5'),
  on(0.10, '%10'),
  onbes(0.15, '%15'),
  ozel(0.0, 'Özel');

  const FireOrani(this.oran, this.etiket);

  /// 0.0–1.0 arası çarpan (örn. %10 fire → 0.10).
  final double oran;

  /// UI'da gösterilen kısa etiket.
  final String etiket;
}

/// Tek bir yüzey: ya en×boy (m) dikdörtgen ya da doğrudan alan (m²).
///
/// [dususmM2] kapı/pencere gibi çıkarılacak alanların toplamıdır (m²).
/// Net alan negatif olamaz (düşüm alanı aşarsa 0'a sıkışır).
class Yuzey {
  const Yuzey._({
    required this.enM,
    required this.boyM,
    required this.dogrudanAlanM2,
    required this.dususmM2,
    this.etiket,
  });

  /// en×boy (m) ile dikdörtgen yüzey.
  factory Yuzey.dikdortgen({
    required double enM,
    required double boyM,
    double dususmM2 = 0,
    String? etiket,
  }) =>
      Yuzey._(
        enM: enM,
        boyM: boyM,
        dogrudanAlanM2: null,
        dususmM2: dususmM2,
        etiket: etiket,
      );

  /// Doğrudan alan (m²) ile yüzey (ölçü zaten alan olarak biliniyorsa).
  factory Yuzey.alan({
    required double alanM2,
    double dususmM2 = 0,
    String? etiket,
  }) =>
      Yuzey._(
        enM: null,
        boyM: null,
        dogrudanAlanM2: alanM2,
        dususmM2: dususmM2,
        etiket: etiket,
      );

  final double? enM;
  final double? boyM;
  final double? dogrudanAlanM2;

  /// Çıkarılacak alan (kapı/pencere), m².
  final double dususmM2;

  /// Opsiyonel kullanıcı etiketi ("Salon duvarı" vb.).
  final String? etiket;

  /// Düşümlerden ÖNCE brüt alan (m²).
  double get brutAlanM2 =>
      dogrudanAlanM2 ?? ((enM ?? 0) * (boyM ?? 0));

  /// Düşümler sonrası net alan (m²); negatif olamaz.
  double get netAlanM2 => math.max(0, brutAlanM2 - dususmM2);
}

/// Bir ölçüm oturumu: yüzey listesi + kaynak + zaman damgası.
///
/// Elle ve AR girdileri aynı seansı besler (PRD §5 veri akışı). Faz A'da
/// bellek içi kullanılır; kalıcılık (SharedPreferences/sqflite) sonraki karar.
class OlcumSeansi {
  OlcumSeansi({
    List<Yuzey>? yuzeyler,
    this.kaynak = OlcuKaynagi.manuel,
    this.etiket,
    DateTime? olusturulma,
  })  : yuzeyler = List.unmodifiable(yuzeyler ?? const []),
        olusturulma = olusturulma ?? DateTime.now();

  final List<Yuzey> yuzeyler;
  final OlcuKaynagi kaynak;
  final String? etiket;
  final DateTime olusturulma;

  /// Tüm yüzeylerin net alan toplamı (m²).
  double get toplamNetAlanM2 =>
      yuzeyler.fold(0, (sum, y) => sum + y.netAlanM2);

  /// Yüzey ekleyerek yeni (immutable) seans döndürür.
  OlcumSeansi yuzeyEkle(Yuzey y) => OlcumSeansi(
        yuzeyler: [...yuzeyler, y],
        kaynak: kaynak,
        etiket: etiket,
        olusturulma: olusturulma,
      );
}

/// Hesaplayıcı çıktısının ortak taban tipi. Faz B/C özel sonuçlar (alan, boya,
/// fayans, maliyet…) bu sözleşmeyi izler.
///
/// [tahmini] **her zaman true**: sonuç ekranı zorunlu uyarıyı gösterir.
abstract class HesapSonucu {
  const HesapSonucu();

  /// Her sonuç tahminidir — hiçbir alt sınıf bunu false yapamaz.
  bool get tahmini => true;

  /// Paylaş/kopyala için tek satır özet metni (Faz B'de zenginleşir).
  String get ozet;
}
