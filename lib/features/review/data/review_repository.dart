import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/local/mock_database.dart';
import '../../../data/models/review.dart';
import '../../artisan/data/artisan_providers.dart';

/// Değerlendirme yazma/okuma soyutlaması. Mock'ta [MockDatabase]'e,
/// Firebase'de `reviews` koleksiyonuna gider.
abstract class ReviewRepository {
  Future<void> addReview({
    required String artisanUid,
    required String customerUid,
    required String customerName,
    required String chatId,
    required int rating,
    required List<String> tags,
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
  }) async {
    final added = _db.addReview(
      artisanUid: artisanUid,
      customerUid: customerUid,
      customerName: customerName,
      rating: rating,
      tags: tags,
    );
    // Firestore kuralıyla parite: ikinci değerlendirme reddedilir.
    if (!added) throw StateError('already-reviewed');
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
    // Döküman ID'si = chatId (chat_{müşteri}__{usta}): güvenlik kuralı bu
    // formatı ve sohbetin varlığını doğrular; bir müşteri bir ustayı yalnızca
    // 1 kez değerlendirebilir (ikinci deneme update sayılır → kural reddeder).
    await _reviews.doc(chatId).set(review.toMap());
  }

  @override
  Future<List<Review>> getArtisanReviews(String artisanUid) async {
    final snap = await _reviews
        .where('artisanUID', isEqualTo: artisanUid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => Review.fromMap(d.id, d.data())).toList();
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
