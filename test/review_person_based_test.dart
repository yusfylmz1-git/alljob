import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart';
import 'package:sepette_hizmet/data/models/review.dart';
import 'package:sepette_hizmet/features/review/data/review_repository.dart';

/// Kişi bazlı değerlendirme sözleşmesi (2026-08-08).
///
/// Kullanıcı kararı: "Herkes değerlendirmeyi bir usta veya müşteriye bir kez
/// yapabilecek, ikinci kez isterse güncelleme yapsın. Her profilde usta
/// müşteri fark etmez değerlendir düğmesi olsun."
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Doküman kimliği çifte çakılı', () {
    test('rev_{yazan}__{hedef} biçimi', () {
      expect(reviewDocId(authorUid: 'a', targetUid: 'b'), 'rev_a__b');
    });

    test('YÖN kimliği değiştirmez — aynı çift, aynı kimlik', () {
      // Aynı kişi aynı kişiyi ikinci kez yazınca AYNI dokümana düşmeli;
      // "bir kişiye bir değerlendirme" kısıtını kimlik taşıyor.
      final ilk = reviewDocId(authorUid: 'usta1', targetUid: 'must1');
      final ikinci = reviewDocId(authorUid: 'usta1', targetUid: 'must1');
      expect(ilk, ikinci);
    });

    test('TERS yön FARKLI kimlik — karşılıklı puan birbirini ezmez', () {
      expect(
        reviewDocId(authorUid: 'a', targetUid: 'b'),
        isNot(reviewDocId(authorUid: 'b', targetUid: 'a')),
      );
    });
  });

  group('Mock: bir kişiye bir değerlendirme', () {
    late MockReviewRepository repo;
    setUp(() => repo = MockReviewRepository(MockDatabase()));

    test('ikinci yazım YENİ kayıt açmaz, GÜNCELLER', () async {
      await repo.addReview(
        authorUid: 'usta1',
        targetUid: 'must1',
        authorName: 'Usta',
        rating: 3,
        tags: const ['Geç geldi'],
        direction: ReviewDirection.artisanToCustomer,
      );
      await repo.addReview(
        authorUid: 'usta1',
        targetUid: 'must1',
        authorName: 'Usta',
        rating: 5,
        tags: const ['Güvenilir'],
        direction: ReviewDirection.artisanToCustomer,
      );

      final alinan = await repo.getReviewsFor('must1');
      expect(alinan.length, 1, reason: 'ikinci yazım yeni kayıt açmamalı');
      expect(alinan.single.rating, 5, reason: 'son değer geçerli');
      expect(alinan.single.tags, ['Güvenilir']);
    });

    test('getMyReview önceki kaydı buluyor (form ön-dolgusu)', () async {
      expect(
        await repo.getMyReview(authorUid: 'usta1', targetUid: 'must1'),
        isNull,
      );
      await repo.addReview(
        authorUid: 'usta1',
        targetUid: 'must1',
        authorName: 'Usta',
        rating: 4,
        tags: const [],
        direction: ReviewDirection.artisanToCustomer,
      );
      final mevcut =
          await repo.getMyReview(authorUid: 'usta1', targetUid: 'must1');
      expect(mevcut, isNotNull);
      expect(mevcut!.rating, 4);
    });

    test('MÜŞTERİ de puan alır ve listelenir', () async {
      await repo.addReview(
        authorUid: 'usta1',
        targetUid: 'must1',
        authorName: 'Usta A',
        rating: 5,
        tags: const [],
        direction: ReviewDirection.artisanToCustomer,
      );
      await repo.addReview(
        authorUid: 'usta2',
        targetUid: 'must1',
        authorName: 'Usta B',
        rating: 3,
        tags: const [],
        direction: ReviewDirection.artisanToCustomer,
      );

      final alinan = await repo.getReviewsFor('must1');
      expect(alinan.length, 2, reason: 'farklı yazarlar ayrı kayıt');
    });

    test('hedef doğru: yazdıklarım kendi profilime düşmez', () async {
      await repo.addReview(
        authorUid: 'usta1',
        targetUid: 'must1',
        authorName: 'Usta',
        rating: 5,
        tags: const [],
        direction: ReviewDirection.artisanToCustomer,
      );
      expect(await repo.getReviewsFor('usta1'), isEmpty);
    });
  });

  group('Ekran: ilan/sohbet bağımlılığı YOK', () {
    late String screen;
    setUpAll(() =>
        screen = read('lib/features/review/presentation/review_screen.dart'));

    test('jobId parametresi kalktı', () {
      expect(screen.contains('jobId'), isFalse);
      expect(screen.contains('jobProvider'), isFalse);
      expect(screen.contains('markRated'), isFalse);
    });

    test('"iş tamamlanmalı" kapısı kalktı', () {
      expect(screen.contains('JobStatus.completed'), isFalse);
      expect(screen.contains('Değerlendirme henüz açılmadı'), isFalse);
    });

    test('hedef tek parametre', () {
      expect(screen.contains('required this.targetUid'), isTrue);
    });

    test('kendini değerlendirme engelli', () {
      expect(screen.contains('user.uid == widget.targetUid'), isTrue);
    });

    test('misafir için çıkışı olan bilgi ekranı', () {
      expect(screen.contains('Giriş gerekiyor'), isTrue);
      expect(screen.contains('Geri dön'), isTrue);
    });
  });

  group('Rota', () {
    test('jobId sorgu parametresi kalktı', () {
      final paths = read('lib/core/router/route_paths.dart');
      expect(paths.contains('static String review(String targetUid)'), isTrue);
      // jobId başka rotalarda (jobDetail) meşru — yalnız review() imzasında
      // kalmadığını doğrula.
      expect(paths.contains('review(String artisanUid, {String? jobId})'),
          isFalse);
      final router = read('lib/core/router/app_router.dart');
      expect(router.contains("state.uri.queryParameters['jobId']"), isFalse);
    });
  });

  group('Profillerde Değerlendir düğmesi', () {
    test('usta profilinde', () {
      final s =
          read('lib/features/customer/presentation/artisan_profile_screen.dart');
      expect(s.contains('ReviewCta('), isTrue);
    });

    test('müşteri profilinde', () {
      final s =
          read('lib/features/customer/presentation/public_user_screen.dart');
      expect(s.contains('ReviewCta('), isTrue);
      expect(s.contains('ReviewList('), isTrue);
    });

    test('sayaç "tamamlanan" yerine "değerlendirme" (ortak başlık)', () {
      // 2026-08-09: sayaçlar ProfileStats'a taşındı; her profilde aynı.
      final s = read('lib/core/widgets/profile_header.dart');
      expect(s.contains("label: 'değerlendirme'"), isTrue);
      expect(s.contains("label: 'tamamlanan'"), isFalse);
    });

    test('düğme mevcut kayıtta "Güncelle" diyor', () {
      final s =
          read('lib/features/review/presentation/widgets/review_cta.dart');
      expect(s.contains("'Değerlendirmeni Güncelle'"), isTrue);
      expect(s.contains("'Değerlendir'"), isTrue);
    });

    test('kendi profilinde düğme YOK', () {
      final s =
          read('lib/features/review/presentation/widgets/review_cta.dart');
      expect(s.contains('kendiProfilim'), isTrue);
      expect(s.contains('if (!kendiProfilim)'), isTrue);
    });
  });

  group('Güvenlik kuralları', () {
    late String rules;
    setUpAll(() => rules = read('firestore.rules'));

    test('"iş tamamlanmalı" koşulu KALKTI', () {
      // Bu koşul iş akışı kaldırıldıktan sonra hiç sağlanmıyordu →
      // değerlendirme fiilen kilitliydi.
      expect(rules.contains('reviewUnlockedByCompletedJob'), isFalse);
      expect(rules.contains('reviewJobOk'), isFalse);
    });

    test('kimlik yazan+hedef çiftine çakılı', () {
      expect(rules.contains('function reviewIdOk()'), isTrue);
      expect(
        rules.contains(
            "reviewId == 'rev_' + request.auth.uid + '__' + reviewTargetUid()"),
        isTrue,
      );
    });

    test('kendini değerlendirme sunucuda da engelli', () {
      expect(
        rules.contains('request.resource.data.customerUID != '
            'request.resource.data.artisanUID'),
        isTrue,
      );
    });

    test('güncelleme YALNIZ yazana açık', () {
      expect(rules.contains('allow update: if isSignedIn()'), isTrue);
      expect(rules.contains("hasOnly(['rating', 'tags', 'createdAt', "
          "'customerDisplayName'])"), isTrue);
    });

    test('silme kapalı', () {
      final i = rules.indexOf('match /reviews/{reviewId}');
      final son = rules.indexOf('match /', i + 10);
      final blok = rules.substring(i, son == -1 ? rules.length : son);
      expect(blok.contains('allow delete: if false;'), isTrue);
    });

    test('yeni ratingAsCustomer alanını istemci YAZAMAZ (kural 3)', () {
      expect(rules.contains("'ratingAsCustomer'"), isTrue);
      final i = rules.indexOf('function notSettingPublicPii()');
      final blok = rules.substring(i, i + 600);
      expect(blok.contains('ratingAsCustomer'), isTrue);
    });
  });

  group('Cloud Function', () {
    test('müşteri ortalaması herkese açık alana yazılıyor', () {
      final cf = read('functions/index.js');
      expect(cf.contains('ratingAsCustomer'), isTrue);
      // Adet zaten açıktı; ortalama da yanına geldi.
      expect(cf.contains('reviewCountAsCustomer: n'), isTrue);
    });
  });
}
