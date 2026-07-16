import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/local/mock_database.dart';
import '../../../data/models/review.dart';
import '../../artisan/data/artisan_providers.dart';

/// Değerlendirme yazma/okuma soyutlaması. Mock'ta [MockDatabase]'e,
/// Firebase'de `reviews` koleksiyonuna gider.
abstract class ReviewRepository {
  /// Değerlendirme yazar. Aynı müşteri aynı ustayı ikinci kez
  /// değerlendirirse MEVCUT kayıt güncellenir (yeni kayıt açılmaz).
  Future<void> addReview({
    required String artisanUid,
    required String customerUid,
    required String customerName,
    required String chatId,
    required int rating,
    required List<String> tags,
    String? jobId,
  });

  /// Bu müşterinin bu ustaya daha önce verdiği değerlendirme (yoksa null) —
  /// değerlendirme ekranı formu ön-doldurup "güncelleme" dilinde konuşur.
  Future<Review?> getMyReview({
    required String customerUid,
    required String artisanUid,
    required String chatId,
  });

  /// Ustanın aldığı değerlendirmeler (en yeni önce).
  Future<List<Review>> getArtisanReviews(String artisanUid);
}

class MockReviewRepository implements ReviewRepository {
  MockReviewRepository(this._db);
  final MockDatabase _db;

  @override
  Future<void> addReview({
    required String artisanUid,
    required String customerUid,
    required String customerName,
    required String chatId,
    required int rating,
    required List<String> tags,
    String? jobId,
  }) async {
    // İkinci değerlendirme mevcut kaydı günceller (Firestore paritesi).
    _db.addReview(
      artisanUid: artisanUid,
      customerUid: customerUid,
      customerName: customerName,
      rating: rating,
      tags: tags,
    );
  }

  @override
  Future<Review?> getMyReview({
    required String customerUid,
    required String artisanUid,
    required String chatId,
  }) async {
    final reviews = _db.artisans[artisanUid]?.reviews ?? const <Review>[];
    return reviews.where((r) => r.customerUid == customerUid).firstOrNull;
  }

  @override
  Future<List<Review>> getArtisanReviews(String artisanUid) async =>
      _db.artisans[artisanUid]?.reviews ?? const [];
}

/// Firestore `reviews` koleksiyonu. Puan TOPLAMLARI artisanProfiles üzerinde
/// Cloud Functions ile güncellenecek (kurallar istemci yazımını engeller);
/// o zamana dek ortalamalar okuma sırasında değerlendirmelerden hesaplanır
/// (bkz. FirebaseArtisanRepository).
class FirebaseReviewRepository implements ReviewRepository {
  FirebaseReviewRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _db.collection('reviews');

  @override
  Future<void> addReview({
    required String artisanUid,
    required String customerUid,
    required String customerName,
    required String chatId,
    required int rating,
    required List<String> tags,
    String? jobId,
  }) async {
    final review = Review(
      id: chatId,
      artisanUid: artisanUid,
      customerUid: customerUid,
      customerDisplayName: customerName,
      chatId: chatId,
      rating: rating,
      tags: tags,
      createdAt: DateTime.now(),
    );
    // Döküman ID'si = chatId (chat_{müşteri}__{usta}): müşteri başına usta
    // başına TEK döküman. İlk gönderim create; sonrakiler AYNI dökümanın
    // üzerine yazar (kural yalnız rating/tags/createdAt/ad değişimine izin
    // verir). Ortalamayı CF `onReviewWritten` delta ile işler.
    // jobId: H6 tamamlanmış iş yolu (rules).
    final map = review.toMap();
    if (jobId != null && jobId.isNotEmpty) map['jobId'] = jobId;
    await _reviews.doc(chatId).set(map);
  }

  @override
  Future<Review?> getMyReview({
    required String customerUid,
    required String artisanUid,
    required String chatId,
  }) async {
    // Döküman ID'si deterministik olduğundan tek get yeter (sorgu gerekmez).
    final snap = await _reviews.doc(chatId).get();
    final data = snap.data();
    if (data == null) return null;
    return Review.fromMap(snap.id, data);
  }

  @override
  Future<List<Review>> getArtisanReviews(String artisanUid) async {
    final snap = await _reviews
        .where('artisanUID', isEqualTo: artisanUid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    // H5: admin soft-hide — consumer listesinde gösterme.
    return snap.docs
        .where((d) => d.data()['hiddenByAdmin'] != true)
        .map((d) => Review.fromMap(d.id, d.data()))
        .toList();
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  if (useFirebaseBackend) return FirebaseReviewRepository();
  return MockReviewRepository(ref.watch(mockDatabaseProvider));
});

/// Ustanın kendi panelinde gösterilen değerlendirmeleri.
final artisanReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, uid) {
  return ref.watch(reviewRepositoryProvider).getArtisanReviews(uid);
});
