import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/local/mock_database.dart';
import '../../../data/models/review.dart';
import '../../artisan/data/artisan_providers.dart';

/// Değerlendirme yazma/okuma soyutlaması. Mock'ta [MockDatabase]'e,
/// Firebase'de `reviews` koleksiyonuna gider.
abstract class ReviewRepository {
  /// Değerlendirme yazar — KİŞİ BAZLI (2026-08-08).
  ///
  /// Doküman kimliği `rev_{yazan}__{hedef}` olduğu için bir kişi bir kişiyi
  /// yalnız BİR KEZ değerlendirir; ikinci gönderim aynı kaydı GÜNCELLER.
  ///
  /// [targetUid] puanı alan, [authorUid] veren taraftır. İlan/sohbet
  /// bağımlılığı YOK: profil sayfasındaki "Değerlendir" düğmesi doğrudan
  /// buraya gelir.
  Future<void> addReview({
    required String authorUid,
    required String targetUid,
    required String authorName,
    required int rating,
    required List<String> tags,
    required ReviewDirection direction,
  });

  /// [authorUid]'in [targetUid] için daha önce yazdığı değerlendirme (yoksa
  /// null) — form ön-doldurup "güncelleme" dilinde konuşur.
  Future<Review?> getMyReview({
    required String authorUid,
    required String targetUid,
  });

  /// Bir kullanıcının ALDIĞI değerlendirmeler (en yeni önce).
  ///
  /// Usta ve müşteri ayrımı YOK: profil kimin olursa olsun aldığı puanlar
  /// listelenir. Yön yalnızca "kim yazdı" bilgisidir.
  Future<List<Review>> getReviewsFor(String uid);

  /// Ustanın aldığı değerlendirmeler (en yeni önce).
  ///
  /// [getReviewsFor]'un usta tarafındaki dar hâli — usta vitrininde yalnız
  /// müşteri→usta yönü listelenir.
  Future<List<Review>> getArtisanReviews(String artisanUid);
}

class MockReviewRepository implements ReviewRepository {
  MockReviewRepository(this._db);
  final MockDatabase _db;

  /// Mock'un usta vitrini dışında tuttuğu kayıtlar (a2c + müşteri hedefli).
  ///
  /// `MockDatabase.addReview` yalnız usta profiline yazabiliyor; müşteriye
  /// verilen puanların da bir yeri olmalı ki mock, kuralların davranışını
  /// taklit etsin (CLAUDE.md kural 1).
  final Map<String, Review> _extra = {};

  @override
  Future<void> addReview({
    required String authorUid,
    required String targetUid,
    required String authorName,
    required int rating,
    required List<String> tags,
    required ReviewDirection direction,
  }) async {
    final c2a = direction == ReviewDirection.customerToArtisan;
    // Yön, hangi alanın "usta" hangisinin "müşteri" olduğunu belirler.
    final artisanUid = c2a ? targetUid : authorUid;
    final customerUid = c2a ? authorUid : targetUid;

    if (c2a) {
      // İkinci değerlendirme mevcut kaydı günceller (Firestore paritesi).
      _db.addReview(
        artisanUid: artisanUid,
        customerUid: customerUid,
        customerName: authorName,
        rating: rating,
        tags: tags,
      );
      return;
    }

    final id = reviewDocId(authorUid: authorUid, targetUid: targetUid);
    _extra[id] = Review(
      id: id,
      artisanUid: artisanUid,
      customerUid: customerUid,
      customerDisplayName: authorName,
      chatId: '',
      rating: rating,
      tags: tags,
      direction: direction,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Review?> getMyReview({
    required String authorUid,
    required String targetUid,
  }) async {
    final id = reviewDocId(authorUid: authorUid, targetUid: targetUid);
    final extra = _extra[id];
    if (extra != null) return extra;
    // c2a: usta vitrininde yazarı ben olan kayıt.
    final reviews = _db.artisans[targetUid]?.reviews ?? const <Review>[];
    return reviews.where((r) => r.customerUid == authorUid).firstOrNull;
  }

  @override
  Future<List<Review>> getReviewsFor(String uid) async {
    final alinan = <Review>[
      ...(_db.artisans[uid]?.reviews ?? const <Review>[]),
      ..._extra.values.where((r) => r.targetUid == uid),
    ];
    alinan.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return alinan;
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
    required String authorUid,
    required String targetUid,
    required String authorName,
    required int rating,
    required List<String> tags,
    required ReviewDirection direction,
  }) async {
    // Kimlik ÇİFTE bağlı: aynı kişiye ikinci yazım aynı dokümanın üzerine
    // gelir → "bir kez değerlendir, sonra güncelle" kısıtını kimliğin
    // kendisi taşır, ayrı bir sorgu gerekmez.
    final docId = reviewDocId(authorUid: authorUid, targetUid: targetUid);
    final c2a = direction == ReviewDirection.customerToArtisan;
    final review = Review(
      id: docId,
      // Şema alanları korunuyor (kural 6: yeniden adlandırma veri göçüdür).
      // Yön, hangi uid'in hangi alana yazılacağını belirler.
      artisanUid: c2a ? targetUid : authorUid,
      customerUid: c2a ? authorUid : targetUid,
      customerDisplayName: authorName,
      chatId: '',
      rating: rating,
      tags: tags,
      direction: direction,
      createdAt: DateTime.now(),
    );
    // Ortalamayı CF `onReviewWritten` delta ile işler (istemci yazmaz).
    await _reviews.doc(docId).set(review.toMap());
  }

  @override
  Future<Review?> getMyReview({
    required String authorUid,
    required String targetUid,
  }) async {
    // Kimlik deterministik → tek get yeter, sorgu gerekmez.
    final snap = await _reviews
        .doc(reviewDocId(authorUid: authorUid, targetUid: targetUid))
        .get();
    final data = snap.data();
    if (data == null) return null;
    return Review.fromMap(snap.id, data);
  }

  @override
  Future<List<Review>> getReviewsFor(String uid) async {
    // Hedef iki alandan birinde olabilir (yöne göre), Firestore OR sorgusu
    // yerine iki sorgu + birleştirme: her ikisi de indeksli ve ucuz.
    final sonuclar = await Future.wait([
      _reviews
          .where('artisanUID', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get(),
      _reviews
          .where('customerUID', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get(),
    ]);

    final alinan = <String, Review>{};
    for (final snap in sonuclar) {
      for (final d in snap.docs) {
        if (d.data()['hiddenByAdmin'] == true) continue;
        final r = Review.fromMap(d.id, d.data());
        // Kaydın HEDEFİ ben miyim? Yazdıklarım listeye girmemeli.
        if (r.targetUid == uid) alinan[d.id] = r;
      }
    }
    final list = alinan.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<Review>> getArtisanReviews(String artisanUid) async {
    final snap = await _reviews
        .where('artisanUID', isEqualTo: artisanUid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    // H5: admin soft-hide — consumer listesinde gösterme.
    // `a2c` (usta→müşteri) kayıtları da `artisanUID` taşır ama usta VİTRİNİNE
    // ait değildir; yalnız müşteri→usta yönü listelenir.
    return snap.docs
        .where((d) => d.data()['hiddenByAdmin'] != true)
        .map((d) => Review.fromMap(d.id, d.data()))
        .where((r) => r.direction == ReviewDirection.customerToArtisan)
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

/// Bir profilin ALDIĞI değerlendirmeler — usta/müşteri fark etmez.
final reviewsForUserProvider =
    FutureProvider.family<List<Review>, String>((ref, uid) {
  return ref.watch(reviewRepositoryProvider).getReviewsFor(uid);
});

/// Oturumdaki kullanıcının [targetUid] için YAZDIĞI değerlendirme (yoksa
/// null). "Değerlendir" mi "Değerlendirmeni Güncelle" mi yazılacağını ve
/// formun ön-dolu gelip gelmeyeceğini belirler.
final myReviewForProvider =
    FutureProvider.family<Review?, ({String authorUid, String targetUid})>(
        (ref, arg) {
  if (arg.authorUid.isEmpty || arg.targetUid.isEmpty) return Future.value();
  return ref.watch(reviewRepositoryProvider).getMyReview(
        authorUid: arg.authorUid,
        targetUid: arg.targetUid,
      );
});
