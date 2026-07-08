import '../../../data/models/artisan_profile.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/review.dart';

/// Listeleme kartı için özet usta modeli (users + artisanProfiles birleşimi).
class ArtisanSummary {
  const ArtisanSummary({
    required this.uid,
    required this.displayName,
    required this.professionCode,
    required this.professionNameTR,
    required this.experienceYears,
    required this.averageRating,
    required this.totalReviews,
    required this.isVerified,
    required this.isPremium,
    required this.isAvailable,
    required this.isNewArtisan,
    this.profilePhotoUrl,
  });

  final String uid;
  final String displayName;
  final String professionCode;
  final String professionNameTR;
  final int experienceYears;
  final double averageRating;
  final int totalReviews;
  final bool isVerified;
  final bool isPremium;
  final bool isAvailable; // canlı müsaitlik (PRD §3)
  final bool isNewArtisan; // ilk 15 gün "Yeni Usta" rozeti
  final String? profilePhotoUrl;
}

/// Profil sayfası için tam usta detayı.
class ArtisanDetail {
  const ArtisanDetail({
    required this.uid,
    required this.displayName,
    required this.professionNameTR,
    required this.profile,
    required this.reviews,
    this.profilePhotoUrl,
  });

  final String uid;
  final String displayName;
  final String professionNameTR;
  final ArtisanProfile profile;
  final List<Review> reviews;
  final String? profilePhotoUrl;
}

/// Sayfalama sonucu — bir sonraki sayfanın olup olmadığını taşır.
class ArtisanSearchPage {
  const ArtisanSearchPage({required this.items, required this.hasMore});
  final List<ArtisanSummary> items;
  final bool hasMore;
}

/// Usta arama filtresi. Tüm alanlar opsiyoneldir — hiçbiri zorunlu değildir
/// (PRD §3 Ekran A). Verilen her alan AND olarak uygulanır.
class ArtisanFilter {
  const ArtisanFilter({
    this.province,
    this.district,
    this.professionCode,
    this.query,
  });

  final String? province;
  final String? district;
  final String? professionCode;

  /// Serbest metin araması (usta adı veya meslek adı içinde geçer).
  final String? query;

  bool get hasGeo => province != null || district != null;

  /// Bir ustanın hizmet bölgelerinden herhangi biri, verilen coğrafi
  /// kırılımların hepsiyle eşleşiyor mu?
  bool matchesArea(ServiceArea a) =>
      (province == null || a.province == province) &&
      (district == null || a.district == district);

  /// Serbest metin sorgusu ad/meslekle eşleşiyor mu? (Türkçe harf duyarlı)
  bool matchesQuery({
    required String displayName,
    required String professionNameTR,
  }) {
    final q = _trLower(query ?? '').trim();
    if (q.isEmpty) return true;
    return _trLower(displayName).contains(q) ||
        _trLower(professionNameTR).contains(q);
  }

  /// Türkçe'ye uygun küçük harfe çevirme (İ→i, I→ı).
  static String _trLower(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
}

/// Usta verisi soyutlaması. Mock ile başlar, Firestore ile değiştirilir.
abstract interface class ArtisanRepository {
  /// Opsiyonel filtreye göre ustaları sayfalı getirir. Filtre alanları
  /// bağımsızdır; hiçbiri zorunlu değildir (boş filtre = Türkiye geneli).
  /// Sıralama (ilk 1 yıl modeli, PRD §3): önce müsait ustalar (puana göre),
  /// sonra müsait olmayanlar (puana göre).
  Future<ArtisanSearchPage> searchArtisans({
    required ArtisanFilter filter,
    required int offset,
    required int limit,
  });

  Future<ArtisanDetail?> getArtisanDetail(String uid);
}
