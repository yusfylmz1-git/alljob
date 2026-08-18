import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/job.dart';

/// Play Store öncesi denetimde (2026-08-17) bulunan sorunların regresyon
/// testleri. Her biri canlıda sessizce bozulan — yani fark edilmesi haftalar
/// alacak — bir arıza sınıfını temsil eder.
void main() {
  group('Eksik Firestore indeksleri (canlıda FAILED_PRECONDITION)', () {
    late List<dynamic> indexes;
    late List<dynamic> fieldOverrides;

    setUpAll(() {
      final raw = File('firestore.indexes.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      indexes = (json['indexes'] as List?) ?? const [];
      fieldOverrides = (json['fieldOverrides'] as List?) ?? const [];
    });

    bool indeksVar(String koleksiyon, List<String> alanlar) {
      return indexes.any((i) {
        final m = i as Map<String, dynamic>;
        if (m['collectionGroup'] != koleksiyon) return false;
        final f = ((m['fields'] as List?) ?? const [])
            .map((x) => (x as Map<String, dynamic>)['fieldPath'] as String)
            .toList();
        return f.length == alanlar.length &&
            List.generate(f.length, (n) => f[n] == alanlar[n])
                .every((ok) => ok);
      });
    }

    test('reviews(customerUID+createdAt) — profil ekranı yorumları', () {
      // `review_repository.dart` getReviewsFor() bu sorguyu profil başlığı
      // her çizildiğinde çalıştırır. İndeks yoksa Future.wait içinde patlar
      // ve puan/yorum bloğu hiç görünmez.
      expect(indeksVar('reviews', ['customerUID', 'createdAt']), isTrue,
          reason: 'İndeks olmadan kullanıcı profilindeki yorum listesi '
              'canlıda FAILED_PRECONDITION ile çöker.');
    });

    test('reviews(artisanUID+createdAt) — usta yorumları korunuyor', () {
      expect(indeksVar('reviews', ['artisanUID', 'createdAt']), isTrue);
    });

    test('jobs(customerId+status) — açık ilan sayacı', () {
      // functions/index.js refreshOpenJobCount() iki eşitlik filtresi
      // kullanır → bileşik indeks şart. Yoksa sorgu catch'e düşer, sayaç
      // güncellenmez ve firestore.rules openJobQuotaOk() her zaman 0 okur
      // → 5 ilan limiti TAMAMEN devre dışı kalır.
      expect(indeksVar('jobs', ['customerId', 'status']), isTrue,
          reason: 'İndeks yoksa ilan limiti sessizce çalışmaz; '
              'bir kullanıcı sınırsız ilan açabilir.');
    });

    test('bildirimler için TTL politikası tanımlı', () {
      // saveNotification her bildirime expireAt yazıyor ama fieldOverrides
      // boşsa Firestore bunu SİLMEZ — sadece anlamsız bir alan olur.
      final ttl = fieldOverrides.any((f) {
        final m = f as Map<String, dynamic>;
        return m['collectionGroup'] == 'notifications' &&
            m['fieldPath'] == 'expireAt' &&
            m['ttl'] == true;
      });
      expect(ttl, isTrue,
          reason: 'TTL tanımsızsa users/{uid}/notifications sonsuza kadar '
              'büyür (aktif kullanıcı yılda ~2000 bildirim).');
    });
  });

  group('Süresi dolmuş ilan mesaj almamalı', () {
    Job ilan({required Duration kalan}) {
      final now = DateTime.now();
      return Job(
        jobId: 'j1',
        customerId: 'c1',
        customerName: 'Müşteri',
        title: 'Test ilanı',
        description: 'Açıklama',
        category: 'painter',
        province: 'Bursa',
        district: 'Nilüfer',
        neighborhood: null,
        photos: const [],
        priceType: JobPriceType.fixed,
        budget: 100,
        status: JobStatus.open, // ham durum HEP open kalır
        createdAt: now.subtract(const Duration(days: 10)),
        expiresAt: now.add(kalan),
      );
    }

    test('ham status open kalsa da efektif durum expired olur', () {
      // Sunucuda ilanı expired yapan zamanlanmış görev YOK; doküman
      // sonsuza kadar open kalır. Kapı bu yüzden effectiveStatus'e bakmalı.
      final dolmus = ilan(kalan: const Duration(days: -3));

      expect(dolmus.status, JobStatus.open);
      expect(dolmus.effectiveStatus, JobStatus.expired);
      expect(dolmus.effectiveStatus.isActiveForOffers, isFalse,
          reason: 'Süresi dolmuş ilana hâlâ "Mesaj gönder" düğmesi '
              'çıkıyordu — "ilanım doldu ama mesaj geliyor" şikâyeti.');
    });

    test('süresi dolmamış ilan mesaj alabilir', () {
      final acik = ilan(kalan: const Duration(days: 2));

      expect(acik.effectiveStatus, JobStatus.open);
      expect(acik.effectiveStatus.isActiveForOffers, isTrue,
          reason: 'Düzeltme fazlasını yapıp açık ilanı kapatmamalı.');
    });

    test('ilan detayı ekranı ham status DEĞİL efektif durumu kullanır', () {
      final src =
          File('lib/features/jobs/presentation/job_detail_screen.dart')
              .readAsStringSync();

      expect(src.contains('job.effectiveStatus.isActiveForOffers'), isTrue,
          reason: 'Kapı ham `status`e dönerse süresi dolmuş ilan yine '
              'mesaj alır.');
      expect(src.contains('job.status.isActiveForOffers'), isFalse);
    });
  });

  group('Profil fotoğrafı aynası (Keşfet/Ana Sayfa eski foto gösteriyordu)',
      () {
    late String src;

    setUpAll(() {
      src = File('lib/features/auth/data/firebase_auth_repository.dart')
          .readAsStringSync();
    });

    test('ayna kapısı bayat önbelleğe DEĞİL doküman varlığına bakar', () {
      // `_cached.hasArtisanProfile` oturum tazelenmeden güncellenmiyordu:
      // users yeni fotoğrafı, artisanProfiles eskisini taşıyordu. Kullanıcı
      // kendi profilinde yeniyi, Keşfet'te eskiyi görüyordu.
      expect(
        src.contains("ayna.isNotEmpty && _cached?.hasArtisanProfile == true"),
        isFalse,
        reason: 'Bayat önbellek kapısı geri gelmiş — foto ayrışması tekrar '
            'yaşanır.',
      );
      expect(src.contains('snap.exists'), isTrue,
          reason: 'Ayna, artisanProfiles dokümanının gerçekten var olup '
              'olmadığına bakmalı.');
    });
  });

  group('Güvenlik: reviews create allowlist', () {
    late String rules;

    setUpAll(() => rules = File('firestore.rules').readAsStringSync());

    test('create alan allowlist\'i var (moderasyon alanı enjekte edilemez)',
        () {
      // reviews herkese açık okunur. Allowlist yokken istemci ilk yazımda
      // `hiddenByAdmin: false` gönderip admin gizlemesini atlatabiliyordu.
      final createBlok = rules.substring(
        rules.indexOf('match /reviews/{reviewId}'),
        rules.indexOf('match /neighborhoods/{id}'),
      );

      expect(createBlok.contains('keys().hasOnly(['), isTrue,
          reason: 'reviews create allowlist\'i kaldırılmış — sunucu alanları '
              'istemciye açık.');

      // Allowlist'in KENDİSİNİ çıkar (yorum satırları hariç): hasOnly([...])
      // parantezleri arasındaki alan adları.
      final baslangic = createBlok.indexOf('keys().hasOnly([');
      final bitis = createBlok.indexOf(']', baslangic);
      final allowlist = createBlok.substring(baslangic, bitis);

      expect(allowlist.contains("'customerDisplayName'"), isTrue);
      expect(allowlist.contains('hiddenByAdmin'), isFalse,
          reason: 'Moderasyon alanı allowlist\'te OLMAMALI — istemci ilk '
              'yazımda admin gizlemesini atlatabilirdi.');
      expect(allowlist.contains('moderatedBy'), isFalse);
    });

    test('boyut tavanı var (herkese açık doküman şişirilemez)', () {
      final createBlok = rules.substring(
        rules.indexOf('match /reviews/{reviewId}'),
        rules.indexOf('match /neighborhoods/{id}'),
      );

      expect(createBlok.contains('tags.size()'), isTrue);
      expect(createBlok.contains('customerDisplayName.size()'), isTrue,
          reason: 'Tavan yoksa tek yoruma yüzlerce KB metin konup her '
              'profil görüntüleyene indirtilebilir.');
    });
  });

  // NOT: "Gizlilik: yapılandırma hataları kullanıcıya sızmamalı" grubu
  // SMS doğrulama akışına özgüydü; akış 2026-08-18'de tamamen kaldırıldı
  // (phone_verification_repository.dart silindi), testler de onunla düştü.

  group('Sertifika gizliliği (özel nitelikli veri)', () {
    late String storage;

    setUpAll(() => storage = File('storage.rules').readAsStringSync());

    test('certificate/ okuması sahibi + admin ile sınırlı', () {
      expect(storage.contains('match /certificate/{uid}/{fileName}'), isTrue,
          reason: 'Sertifikaya özel kural kaldırılmış — belge herkese açık.');

      final blok = storage.substring(
        storage.indexOf('match /certificate/{uid}/{fileName}'),
        storage.indexOf('match /{folder}/{uid}/{fileName}'),
      );
      expect(blok.contains('allow read: if true'), isFalse,
          reason: 'Usta buraya kimlik/diploma yükleyebiliyor.');
      expect(blok.contains('request.auth.uid == uid'), isTrue);
      expect(blok.contains("token.get('admin', false)"), isTrue,
          reason: 'Admin doğrulama için belgeyi görebilmeli.');
    });

    test('genel {folder} kuralı sertifikayı GERİ AÇMIYOR', () {
      // Storage'da eşleşen tüm kurallar OR'lanır: `{folder}/{uid}/{file}`
      // deseni certificate yoluna da uyar. `read: if true` bırakılsaydı
      // özel kural hiçbir işe yaramazdı — en kolay gözden kaçan hata.
      final blok = storage.substring(
        storage.indexOf('match /{folder}/{uid}/{fileName}'),
        storage.indexOf('match /{folder}/{fileName}'),
      );
      expect(blok.contains('allow read: if true'), isFalse,
          reason: 'Genel kural sertifika okumasını geri açıyor!');
      expect(blok.contains("allow read: if folder in ["), isTrue);
      expect(blok.contains("'certificate'"), isFalse,
          reason: 'certificate genel klasör listesinde OLMAMALI.');
    });

    test('müşteriye belge görseli çizilmiyor, onay rozeti gösteriliyor', () {
      final src =
          File('lib/features/customer/presentation/artisan_profile_screen.dart')
              .readAsStringSync();

      expect(
        src.contains('profile.certificates.isNotEmpty && isOwner'),
        isTrue,
        reason: 'Belge galerisi sahibiyle sınırlı olmalı; müşteriye çizmek '
            'artık kırık kutu üretir (Storage okumayı reddeder).',
      );
      expect(src.contains('Belgeleri onaylı'), isTrue,
          reason: 'Güven sinyali korunmalı — rozet kalmalı.');
    });
  });

  group('Ürün taslağı kotası', () {
    test('firestore.rules taslak kotası kapısı içeriyor', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules.contains('productDraftQuotaOk()'), isTrue,
          reason: 'Kota kapısı yoksa script ile sınırsız taslak yazılabilir.');
      expect(rules.contains('productStats'), isTrue);
    });

    test('productStats istemci yazımına KAPALI', () {
      final rules = File('firestore.rules').readAsStringSync();
      final privateBlok = rules.substring(
        rules.indexOf('match /private/{doc}'),
        rules.indexOf('match /blocked/{otherUid}'),
      );

      expect(privateBlok.contains("'productStats'"), isFalse,
          reason: 'İstemci yazabilseydi sayacı sıfırlayıp kotayı kaldırırdı.');
      expect(privateBlok.contains("doc in ['contact', 'push', 'chatMeta']"),
          isTrue);
    });

    test('CF sayacı tazeliyor ve okuma tavanlı', () {
      final src = File('functions/index.js').readAsStringSync();

      expect(src.contains('refreshDraftProductCount'), isTrue);
      final fn = src.substring(
        src.indexOf('async function refreshDraftProductCount'),
        src.indexOf('async function refreshDraftProductCount') + 900,
      );
      expect(fn.contains('.limit('), isTrue,
          reason: 'Limitsiz get() 100.000 taslakta koleksiyonu tarardı.');
      expect(fn.contains('draftCount'), isTrue);
    });

    test('açık ilan sayacı da tavanlı okuyor', () {
      final src = File('functions/index.js').readAsStringSync();
      final fn = src.substring(
        src.indexOf('async function refreshOpenJobCount'),
        src.indexOf('async function refreshOpenJobCount') + 900,
      );
      expect(fn.contains('.limit('), isTrue,
          reason: '10.000 ilanı olan hesapta her yazımda 10.000 doküman '
              'okunuyordu.');
    });

    test('products(ownerUid+status) indeksi var', () {
      final raw = File('firestore.indexes.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final idx = (json['indexes'] as List).any((i) {
        final m = i as Map<String, dynamic>;
        if (m['collectionGroup'] != 'products') return false;
        final f = ((m['fields'] as List?) ?? const [])
            .map((x) => (x as Map<String, dynamic>)['fieldPath'])
            .toList();
        return f.length == 2 && f[0] == 'ownerUid' && f[1] == 'status';
      });
      expect(idx, isTrue,
          reason: 'İndeks yoksa taslak sayacı sessizce çalışmaz → kota '
              'fiilen devre dışı kalır.');
    });
  });

  group('Usta araması sunucu taraflı bölge filtresi', () {
    test('il filtresi Firestore sorgusuna taşınmış', () {
      final src = File(
              'lib/features/artisan/data/firebase_artisan_repository.dart')
          .readAsStringSync();

      expect(src.contains("where('serviceProvinces', arrayContains:"), isTrue,
          reason: 'İl istemcide eleniyorsa koleksiyonun ilk 180 profili '
              'çekilir ve 181. usta hiçbir aramada görünmez.');
    });

    test('önbellek anahtarı ili de içeriyor', () {
      final src = File(
              'lib/features/artisan/data/firebase_artisan_repository.dart')
          .readAsStringSync();

      // Anahtar yalnız meslekten türeseydi, Bursa araması İstanbul
      // sonuçlarını önbellekten döndürürdü.
      expect(src.contains("'\${professionCode ?? '*'}|\${province ?? '*'}'"),
          isTrue,
          reason: 'Önbellek anahtarı il ayrımı yapmazsa yanlış şehrin '
              'ustaları gösterilir.');
    });
  });

  group('KVKK: hesap silme anonimleştirmesi', () {
    test('silinen kullanıcının yazdığı yorum işaretleniyor', () {
      final src = File('functions/index.js').readAsStringSync();

      expect(src.contains('authorDeleted: true'), isTrue,
          reason: 'reports/supportTickets silinme işareti taşıyor, reviews '
              'taşımıyordu — tutarsızlık.');
    });
  });
}
