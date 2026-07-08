import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/artisan_profile.dart';
import '../../../data/models/review.dart';
import 'artisan_repository.dart';

/// Firestore `artisanProfiles` + `reviews` koleksiyonları ile çalışan
/// [ArtisanRepository].
///
/// Meslek filtresi sunucu tarafında (`where professionCode ==`) uygulanır.
/// Coğrafi filtre (serviceAreas map dizisi) ve canlı müsaitlik sıralaması
/// hesaplanmış alanlar olduğundan istemci tarafında yapılır — MVP için yeterli.
/// Ölçeklenince: `serviceAreas` için denormalize edilmiş `areaKeys[]` alanı +
/// `isAvailableNow` (Cloud Functions ile) ve gerçek `startAfter` sayfalaması.
///
/// Puan (rating): artık istemci `reviews`'i TARAMAZ. `onReviewCreated` Cloud
/// Function'ı `averageRating/totalReviews/totalRatingSum` alanlarını profile
/// denormalize eder; burada doğrudan profil dökümanından okunur.
class FirebaseArtisanRepository implements ArtisanRepository {
  FirebaseArtisanRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Uygulama-ömrü singleton olduğundan (bkz. `artisanRepositoryProvider`)
  /// örnek üzerinde kısa ömürlü önbellek tutulur. Amaç: sayfalama (`loadMore`)
  /// ve ardışık aramalarda aynı profil koleksiyonunu tekrar tekrar OKUMAMAK
  /// (Firestore fatura kalemi doküman okumadır).
  static const Duration _cacheTtl = Duration(minutes: 3);

  // Profesyon filtresine göre çekilmiş profil dökümanları önbelleği.
  String? _profilesCacheKey;
  DateTime? _profilesCacheAt;
  List<({String id, Map<String, dynamic> data})>? _profilesCache;

  bool _fresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _cacheTtl;

  /// Bu depo üzerinden yapılan bir yazma sonrası (profil kaydı vb.) önbelleği
  /// elle boşaltmak için — çağıran isteğe bağlı kullanır.
  void invalidateCache() {
    _profilesCache = null;
    _profilesCacheKey = null;
    _profilesCacheAt = null;
  }

  Future<List<({String id, Map<String, dynamic> data})>> _cachedProfiles(
      String? professionCode) async {
    final key = professionCode ?? '*';
    if (_profilesCacheKey == key &&
        _fresh(_profilesCacheAt) &&
        _profilesCache != null) {
      return _profilesCache!;
    }
    Query<Map<String, dynamic>> q = _db.collection('artisanProfiles');
    if (professionCode != null) {
      q = q.where('profession', isEqualTo: professionCode);
    }
    // Okuma tavanı: istemci filtre/sıralama öncesi en fazla bu kadar profil.
    final snap = await q.limit(AppConstants.artisanFetchCap).get();
    final list = snap.docs
        .map((d) => (id: d.id, data: d.data()))
        .toList(growable: false);
    _profilesCache = list;
    _profilesCacheKey = key;
    _profilesCacheAt = DateTime.now();
    return list;
  }

  @override
  Future<ArtisanSearchPage> searchArtisans({
    required ArtisanFilter filter,
    required int offset,
    required int limit,
  }) async {
    final docs = await _cachedProfiles(filter.professionCode);
    final now = DateTime.now();

    final records = docs
        .map((d) => _record(d.id, d.data))
        .where((r) => r.profile.profession.isNotEmpty)
        .where((r) {
      // Temel kural: müsait olmayan usta müşteri aramasında GÖSTERİLMEZ
      // (müsaitlik Premium gerektirir).
      if (!r.profile.isAvailableAt(now)) return false;
      if (!filter.matchesQuery(
        displayName: r.displayName,
        professionNameTR: kProfessionNames[r.profile.profession] ?? '',
      )) {
        return false;
      }
      if (!filter.hasGeo) return true;
      return r.profile.serviceAreas.any(filter.matchesArea);
    }).toList();

    // Sıralama: önce müsait ustalar (puana göre), sonra müsait olmayanlar.
    records.sort((a, b) {
      final aAvail = a.profile.isAvailableAt(now);
      final bAvail = b.profile.isAvailableAt(now);
      if (aAvail != bAvail) return aAvail ? -1 : 1;
      return b.profile.averageRating.compareTo(a.profile.averageRating);
    });

    final end = (offset + limit).clamp(0, records.length);
    final page = offset >= records.length
        ? const <_Rec>[]
        : records.sublist(offset, end);

    return ArtisanSearchPage(
      items: page.map((r) => r.toSummary()).toList(),
      hasMore: end < records.length,
    );
  }

  @override
  Future<ArtisanDetail?> getArtisanDetail(String uid) async {
    final snap = await _db.collection('artisanProfiles').doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;

    final reviewsSnap = await _db
        .collection('reviews')
        .where('artisanUID', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    final reviews =
        reviewsSnap.docs.map((d) => Review.fromMap(d.id, d.data())).toList();

    // Puan profil dökümanından (CF denormalize eder); yorumlar yalnızca liste
    // gösterimi için çekilir (en yeni 50).
    final rec = _record(uid, snap.data()!);

    return ArtisanDetail(
      uid: uid,
      displayName: rec.displayName,
      professionNameTR: kProfessionNames[rec.profile.profession] ?? '',
      profile: rec.profile,
      reviews: reviews,
      profilePhotoUrl: rec.profilePhotoUrl,
    );
  }

  _Rec _record(String uid, Map<String, dynamic> data) {
    return _Rec(
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '',
      profilePhotoUrl: data['profilePhotoURL'] as String?,
      profile: ArtisanProfile.fromMap(uid, data),
    );
  }
}

/// Firestore dökümanından türetilmiş hafif kayıt (özet üretmek için).
class _Rec {
  _Rec({
    required this.uid,
    required this.displayName,
    required this.profile,
    this.profilePhotoUrl,
  });

  final String uid;
  final String displayName;
  final String? profilePhotoUrl;
  final ArtisanProfile profile;

  ArtisanSummary toSummary() => ArtisanSummary(
        uid: uid,
        displayName: displayName,
        professionCode: profile.profession,
        professionNameTR: kProfessionNames[profile.profession] ?? '',
        experienceYears: profile.experienceYears,
        averageRating: profile.averageRating,
        totalReviews: profile.totalReviews,
        isVerified: profile.isVerified,
        isPremium: profile.isPremium,
        isAvailable: profile.isAvailable,
        isNewArtisan: profile.isNewArtisan,
        profilePhotoUrl: profilePhotoUrl,
      );
}
