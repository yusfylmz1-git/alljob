// Regresyon: `users.province` + admin il filtresi (2026-08-23).
//
// Denetim bulgusu: kullanıcı listesinde il filtresi yoktu ve şehir bazlı Pro
// geçişi başladığında yönetici "Bursa'da kaç kullanıcı var" sorusunu
// cevaplayamayacaktı.
//
// SORUN: il iki yerde ama ikisi de DİZİ —
// `artisanProfiles.serviceAreas` ve `users.shopServiceAreas`. Firestore
// `where` ile dizinin içindeki alana bakılamaz.
//
// ÇÖZÜM: `users.province` düz kopyası. Toplu göç YOK; profil kaydedildiğinde
// dolar (telefon düzeltmesindeki desenin aynısı).
//
// Çift test (kural 7): il yazılıyor MU + eski kayıtlar BOZULMUYOR MU.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/app_user.dart';
import 'package:sepette_hizmet/data/models/geo_models.dart';
import 'package:sepette_hizmet/features/admin/data/admin_user_repository.dart';
import 'package:sepette_hizmet/features/auth/data/mock_auth_repository.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  AppUser kullanici(String uid, {String? il, bool usta = false}) => AppUser(
        uid: uid,
        displayName: 'Test $uid',
        email: '$uid@test.com',
        createdAt: DateTime(2026, 8, 20),
        province: il,
        hasArtisanProfile: usta,
      );

  group('province alanı modelde', () {
    test('toMap boş ili YAZMIYOR', () {
      // Eski kayıtlarda `null` görünmesin; sorgu zaten eşleşmez.
      expect(kullanici('a').toMap().containsKey('province'), isFalse);
      expect(kullanici('a', il: '  ').toMap().containsKey('province'), isFalse);
    });

    test('dolu il yazılıyor', () {
      expect(kullanici('a', il: 'Bursa').toMap()['province'], 'Bursa');
    });

    test('fromMap boş dizeyi null yapıyor', () {
      expect(AppUser.fromMap('a', {'province': ''}).province, isNull);
      expect(AppUser.fromMap('a', {'province': '  '}).province, isNull);
      expect(AppUser.fromMap('a', {'province': ' Bursa '}).province, 'Bursa');
    });

    test('markOrtakAlanlarGocmus ili TAŞIYOR', () {
      // Sayaç tuzağının aynısı: elle yazılmış kurucu alanı taşımazsa,
      // kullanıcı adını değiştirince ili sessizce düşerdi.
      final u = kullanici('a', il: 'Bursa').markOrtakAlanlarGocmus();
      expect(u.province, 'Bursa',
          reason: 'Ortak alan yazımında il düşüyor.');
    });
  });

  group('Yazma yolu — mağaza kaydı', () {
    test('mağaza bölgesinden il TÜRETİLİYOR', () async {
      final repo = MockAuthRepository();
      await repo.register(
        displayName: 'Satıcı',
        email: 'satici@test.com',
        password: '123456',
      );
      await repo.updateUserProfile(
        hasShopProfile: true,
        shopServiceAreas: const [
          ServiceArea(province: 'Bursa', district: 'Nilüfer'),
        ],
      );
      expect(repo.currentUser!.province, 'Bursa');
    });

    test('AÇIKÇA verilen il öncelikli (usta kaydı)', () async {
      // Usta profili kaydedilirken `shopServiceAreas` gönderilmez ama il
      // yine güncellenmeli.
      final repo = MockAuthRepository();
      await repo.register(
        displayName: 'Usta',
        email: 'usta2@test.com',
        password: '123456',
      );
      await repo.updateUserProfile(province: 'Ankara');
      expect(repo.currentUser!.province, 'Ankara');
    });

    test('boş dize ili TEMİZLİYOR', () async {
      final repo = MockAuthRepository();
      await repo.register(
        displayName: 'Usta',
        email: 'usta3@test.com',
        password: '123456',
      );
      await repo.updateUserProfile(province: 'Bursa');
      await repo.updateUserProfile(province: '');
      expect(repo.currentUser!.province, isNull,
          reason: 'Bölge silinince il yapışık kalmamalı.');
    });
  });

  group('İl filtresi — diğer filtrelerle BİRLEŞMİYOR', () {
    MockAdminUserRepository repoWith(List<AppUser> users) {
      final r = MockAdminUserRepository();
      for (final u in users) {
        r.put(u);
      }
      return r;
    }

    test('il seçiliyken yalnız o ildekiler', () async {
      final repo = repoWith([
        kullanici('bursali', il: 'Bursa'),
        kullanici('ankarali', il: 'Ankara'),
      ]);
      final liste = await repo.fetchPage(province: 'Bursa');
      expect(liste.map((u) => u.uid), ['bursali']);
    });

    test('il seçiliyken ROL filtresi yok sayılıyor', () {
      // Her kombinasyon ayrı bileşik indeks isterdi. İl seçiliyken
      // rozetlerden ayırt edilir.
      final repo = read('lib/features/admin/data/admin_user_repository.dart');
      expect(repo.contains('if (il != null && il.isNotEmpty) {'), isTrue);
      expect(repo.contains('} else {'), isTrue,
          reason: 'İl ve rol filtresi birleşiyor — indeks patlaması.');
    });

    test('ili OLMAYAN kullanıcı filtrede çıkmıyor', () async {
      // Eski kayıtlar; kabul edilebilir kayıp.
      final repo = repoWith([
        kullanici('eski'),
        kullanici('yeni', il: 'Bursa'),
      ]);
      final liste = await repo.fetchPage(province: 'Bursa');
      expect(liste.map((u) => u.uid), ['yeni']);
    });

    test('il verilmezse eski davranış AYNI', () async {
      final repo = repoWith([
        kullanici('a', usta: true),
        kullanici('b'),
      ]);
      final hepsi = await repo.fetchPage();
      expect(hepsi.length, 2);
      final ustalar =
          await repo.fetchPage(filter: AdminUserListFilter.artisans);
      expect(ustalar.map((u) => u.uid), ['a']);
    });
  });

  group('Fazlasını yapmıyor — GÖÇ yok, kural var', () {
    test('toplu göç kodu YOK', () {
      // Kimsenin verisi habersiz değişmemeli; alan kayıt sırasında dolar.
      final js = read('functions/index.js');
      expect(js.contains('backfillProvince'), isFalse);
      expect(js.contains('migrateProvince'), isFalse);
    });

    test('kural province yazımını SINIRLIYOR', () {
      // Serbest metin depolama yüzeyi olmamalı.
      final rules = read('firestore.rules');
      expect(rules.contains("!('province' in d)"), isTrue);
      expect(rules.contains('d.province.size() <= 40'), isTrue);
    });

    test('indeks tanımlı', () {
      // Olmadan sorgu `failed-precondition` atar.
      final idx = read('firestore.indexes.json');
      expect(idx.contains('"province"'), isTrue);
    });

    test('mock ile Firebase AYNI davranıyor (kural 1)', () {
      final repo = read('lib/features/admin/data/admin_user_repository.dart');
      // İki uygulamada da "il seçiliyse diğer filtre yok sayılır".
      expect(
        RegExp(r'if \(il != null && il\.isNotEmpty\)').allMatches(repo).length,
        2,
        reason: 'Mock ve Firebase farklı davranıyor — fark yalnız canlıda '
            'ortaya çıkar.',
      );
    });
  });
}
