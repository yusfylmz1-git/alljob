import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir ilin Pro geçişine hazırlık durumu (2026-08-23).
///
/// Kaynak: `adminStats/provinces/items/{il}` — günlük çalışan
/// `rebuildProvinceStats` yazar, yalnız admin okur.
///
/// ÖLÇÜ: `users.available == true` olan (ve askıya alınmamış) kullanıcı
/// sayısı. Usta/mağaza ayrımı YOKTUR — Pro modelinde ölçü müsaitliktir,
/// müsait olmadan ne mağaza işletilir ne ustalık yapılır.
class ProvinceStat {
  const ProvinceStat({
    required this.province,
    required this.availableCount,
    this.threshold,
    this.thresholdReachedAt,
    this.updatedAt,
  });

  final String province;

  /// Şu an müsait kullanıcı sayısı.
  final int availableCount;

  /// Bu ile ÖZEL eşik — admin yazmışsa. Yoksa [defaultThreshold].
  ///
  /// NEDEN AYARLANABİLİR (2026-08-23): sabit 1.000 küçük illeri KALICI
  /// olarak beta'da bırakırdı. Siirt'te müsait kullanıcı sayısı belki hiç
  /// 1.000'e ulaşmaz; ama 300 usta o il için doymuş bir pazar olabilir.
  /// Eşik pazarın BÜYÜKLÜĞÜNÜ değil DOYGUNLUĞUNU ölçmeli.
  final int? threshold;

  /// Eşiğe İLK ulaşıldığı an. Bir kez yazılır ve **bir daha değişmez** —
  /// sayı sonradan düşse bile geri sarmaz, çünkü kullanıcıya verilen tarih
  /// değişmemeli.
  final DateTime? thresholdReachedAt;

  final DateTime? updatedAt;

  /// VARSAYILAN eşik — sunucudaki `PROVINCE_THRESHOLD_DEFAULT` ile aynı
  /// olmalı. İl bazında [threshold] ile ezilebilir.
  static const int defaultThreshold = 1000;

  /// Bu il için geçerli eşik (özel değer varsa o, yoksa varsayılan).
  int get effectiveThreshold => threshold ?? defaultThreshold;

  bool get reached => thresholdReachedAt != null;

  /// Eşiğe kalan kullanıcı sayısı (ulaşıldıysa 0).
  int get remaining {
    if (reached) return 0;
    final kalan = effectiveThreshold - availableCount;
    return kalan > 0 ? kalan : 0;
  }

  /// 0–1 arası ilerleme (eşiği aşan iller 1'de sabitlenir).
  double get progress {
    if (reached) return 1;
    final o = availableCount / effectiveThreshold;
    return o > 1 ? 1 : o;
  }

  /// Eşiğe ulaşan ilin hangi aşamada olduğu (Pro takvimi).
  ///
  /// 1. ay geri sayım (hâlâ ücretsiz) · 2. ay teklif penceresi ·
  /// sonrası ücretli. Damga yoksa `null`.
  ProvincePhase? phaseAt(DateTime now) {
    final t = thresholdReachedAt;
    if (t == null) return null;
    final gun = now.difference(t).inDays;
    if (gun < 30) return ProvincePhase.countdown;
    if (gun < 60) return ProvincePhase.offer;
    return ProvincePhase.paid;
  }

  factory ProvinceStat.fromMap(String id, Map<String, dynamic>? m) {
    final map = m ?? const <String, dynamic>{};
    DateTime? t(String k) {
      final v = map[k];
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return ProvinceStat(
      province: (map['province'] as String?)?.trim().isNotEmpty == true
          ? map['province'] as String
          : id,
      availableCount: (map['availableCount'] as num?)?.toInt() ?? 0,
      // Geçersiz/sıfır değer YOK SAYILIR → varsayılana düşer. Yanlış bir
      // eşik yüzünden il beklenmedik anda ücretliye geçmemeli.
      threshold: switch ((map['threshold'] as num?)?.toInt()) {
        final t? when t > 0 => t,
        _ => null,
      },
      thresholdReachedAt: t('thresholdReachedAt'),
      updatedAt: t('updatedAt'),
    );
  }
}

/// İlin Pro takvimindeki aşaması. `apiValue` Firestore'a yazılan değerdir
/// (kural 6) — şu an yalnız istemcide hesaplanıyor ama enum sözleşmesi
/// baştan doğru kurulsun.
enum ProvincePhase {
  /// 1. ay: geri sayım, hâlâ ücretsiz.
  countdown('countdown', 'Geri sayım'),

  /// 2. ay: teklif penceresi — ilk ay yarı fiyat.
  offer('offer', 'Teklif penceresi'),

  /// Sonrası: abone olmayanın müsaitliği kapanır.
  paid('paid', 'Ücretli');

  const ProvincePhase(this.apiValue, this.labelTR);
  final String apiValue;
  final String labelTR;
}

/// İl istatistikleri — müsait sayısına göre azalan sıralı.
///
/// Tek seferlik okuma (canlı dinleyici DEĞİL): veri günde bir kez
/// güncelleniyor, açık dinleyici tutmak boşuna maliyet.
final provinceStatsProvider = FutureProvider<List<ProvinceStat>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('adminStats')
      .doc('provinces')
      .collection('items')
      // Türkiye'de 81 il var; limit bir güvenlik ağı, daraltma değil.
      .limit(100)
      .get();

  final liste = snap.docs
      .map((d) => ProvinceStat.fromMap(d.id, d.data()))
      .toList(growable: false);

  // Eşiğe ulaşanlar önce, sonra sayıya göre azalan: yöneticinin ilk
  // bakacağı şey "hangi il hazır".
  final sirali = [...liste]..sort((a, b) {
      if (a.reached != b.reached) return a.reached ? -1 : 1;
      return b.availableCount.compareTo(a.availableCount);
    });
  return sirali;
});

/// Bir ilin eşiğini ayarlar; `null` varsayılana döndürür.
///
/// `adminStats` istemciye yazıma KAPALI (rules) — işlem CF üzerinden yürür
/// ve denetim kaydına yazılır (gerekçe zorunlu).
///
/// Yeni eşik BİR SONRAKİ gece sayımında işlerlik kazanır; damgaya
/// dokunulmaz — eşiği düşürmek geçmiş bir geçişi iptal etmez.
final setProvinceThresholdProvider =
    Provider<Future<void> Function(String, int?, String)>((ref) {
  return (province, threshold, reason) async {
    await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('adminSetProvinceThreshold')
        .call<Object?>({
      'province': province,
      'threshold': threshold,
      'reason': reason,
    });
    ref.invalidate(provinceStatsProvider);
  };
});
