import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/app_user.dart';
import 'package:sepette_hizmet/data/models/social_links.dart';

/// Ortak profil alanları sözleşmesi (2026-08-08).
///
/// Kullanıcı kararı: telefon / sosyal medya / web / hakkımda HER İKİ MODDA
/// da olacak; vitrin ayrı sayfa olmaktan çıkıp Profili Düzenle içine girecek.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('AppUser ortak alanları taşıyor', () {
    test('varsayılanlar boş', () {
      final u = AppUser(
        uid: 'u1',
        displayName: 'Ali Veli',
        email: 'a@b.c',
        createdAt: DateTime(2026),
      );
      expect(u.publicPhone, isNull);
      expect(u.aboutText, '');
      expect(u.socialLinks.hasAny, isFalse);
      expect(u.hasProfileDetails, isFalse);
    });

    test('hasProfileDetails alan dolunca true', () {
      final base = AppUser(
        uid: 'u1',
        displayName: 'Ali Veli',
        email: 'a@b.c',
        createdAt: DateTime(2026),
      );
      expect(base.copyWith(publicPhone: '05321112233').hasProfileDetails,
          isTrue);
      expect(base.copyWith(aboutText: 'Merhaba').hasProfileDetails, isTrue);
      expect(
        base
            .copyWith(socialLinks: const SocialLinks(instagram: 'ali'))
            .hasProfileDetails,
        isTrue,
      );
    });

    test('toMap/fromMap gidiş-dönüş', () {
      final u = AppUser(
        uid: 'u1',
        displayName: 'Ali Veli',
        email: 'a@b.c',
        createdAt: DateTime(2026),
        publicPhone: '05321112233',
        aboutText: 'Tanıtım',
        socialLinks: const SocialLinks(instagram: 'ali', website: 'x.com'),
      );
      final geri = AppUser.fromMap('u1', u.toMap());
      expect(geri.publicPhone, '05321112233');
      expect(geri.aboutText, 'Tanıtım');
      expect(geri.socialLinks.instagram, 'ali');
      expect(geri.socialLinks.website, 'x.com');
    });

    test('copyWith alanları KORUYOR (B-19 tuzağı)', () {
      // Taşınmazsa her copyWith çağrısında silinirlerdi.
      final u = AppUser(
        uid: 'u1',
        displayName: 'Ali Veli',
        email: 'a@b.c',
        createdAt: DateTime(2026),
        publicPhone: '0532',
        aboutText: 'Tanıtım',
        socialLinks: const SocialLinks(instagram: 'ali'),
      );
      final yeni = u.copyWith(displayName: 'Veli Ali');
      expect(yeni.publicPhone, '0532');
      expect(yeni.aboutText, 'Tanıtım');
      expect(yeni.socialLinks.instagram, 'ali');
    });

    test('telefonu SİLMEK için ayrı bayrak var', () {
      // publicPhone: null "değiştirme" demek; temizlemenin başka yolu yok.
      final u = AppUser(
        uid: 'u1',
        displayName: 'Ali Veli',
        email: 'a@b.c',
        createdAt: DateTime(2026),
        publicPhone: '0532',
      );
      expect(u.copyWith(publicPhone: null).publicPhone, '0532');
      expect(u.copyWith(clearPublicPhone: true).publicPhone, isNull);
    });

    test('hassas phoneNumber HÂLÂ toMap dışında (H2/ADR-11)', () {
      final u = AppUser(
        uid: 'u1',
        displayName: 'Ali Veli',
        email: 'a@b.c',
        createdAt: DateTime(2026),
        phoneNumber: '05329998877',
        publicPhone: '05321112233',
      );
      final m = u.toMap();
      expect(m.containsKey('phoneNumber'), isFalse,
          reason: 'hassas numara herkese açık dokümana yazılamaz');
      expect(m['publicPhone'], '05321112233',
          reason: 'yayınlanan numara ayrı alan');
    });
  });

  group('Repository arayüzü', () {
    test('updateUserProfile ortak alanları alıyor', () {
      final repo = read('lib/features/auth/data/auth_repository.dart');
      expect(repo.contains('String? publicPhone'), isTrue);
      expect(repo.contains('SocialLinks? socialLinks'), isTrue);
      expect(repo.contains('String? aboutText'), isTrue);
    });

    test('mock paritesi (CLAUDE.md kural 1)', () {
      final mock = read('lib/features/auth/data/mock_auth_repository.dart');
      expect(mock.contains('SocialLinks? socialLinks'), isTrue);
      expect(mock.contains('clearPublicPhone'), isTrue);
    });

    test('ortak alanlar artisanProfiles\'a AYNALANMIYOR', () {
      // Tek doğruluk kaynağı users; iki kayıt drift etmesin.
      final fb = read('lib/features/auth/data/firebase_auth_repository.dart');
      final i = fb.indexOf('final ayna = <String, dynamic>{}');
      expect(i, greaterThan(-1));
      final blok = fb.substring(i, i + 400);
      expect(blok.contains('publicPhone'), isFalse);
      expect(blok.contains('socialLinks'), isFalse);
      expect(blok.contains('aboutText'), isFalse);
    });
  });

  group('Tek düzenleme ekranı', () {
    test('eski AccountProfileEditScreen SİLİNDİ', () {
      expect(
        File('lib/features/profile/presentation/account_profile_edit_screen.dart')
            .existsSync(),
        isFalse,
      );
    });

    test('/profile/edit tek ekrana gidiyor', () {
      final router = read('lib/core/router/app_router.dart');
      // Yorumda "eski ekran" diye geçebilir; aranan KOD izi.
      expect(router.contains('const AccountProfileEditScreen()'), isFalse);
      expect(router.contains("path: 'edit'"), isTrue);
      expect(router.contains('const ArtisanProfileEditScreen()'), isTrue);
    });

    test('Kaydet sabit alt barda — ListView sonunda değil', () {
      // Cihaz: düğme formun son satırı olunca sistem çubuğunun altına
      // düşüyordu. İlan/ürün düzenleme ile aynı Scaffold.bottomNavigationBar.
      final form = read(
          'lib/features/artisan/presentation/artisan_profile_edit_screen.dart');
      final bar = form.indexOf('bottomNavigationBar:');
      final kaydet = form.indexOf("label: 'Kaydet'");
      final liste = form.indexOf('ListView(');
      expect(bar, greaterThan(-1),
          reason: 'Kaydet Scaffold.bottomNavigationBar olmalı.');
      expect(kaydet, greaterThan(bar),
          reason: 'Kaydet düğmesi alt barın içinde tanımlanmalı.');
      expect(form.contains('SafeArea('), isTrue,
          reason: 'Sistem gezinme çubuğu için SafeArea şart.');
      // ListView, bar bildiriminden SONRA gelmeli (gövde); düğme listede olmamalı.
      expect(liste, greaterThan(bar));
      final listeGovde = form.substring(liste, form.indexOf('USTA VİTRİNİ'));
      expect(listeGovde.contains("label: 'Kaydet'"), isFalse,
          reason: 'Kaydet hâlâ kaydırılan listenin içinde — tekrar alta iner.');
    });

    test('vitrin bölümü yalnız usta profili açılmışsa çiziliyor', () {
      final form = read(
          'lib/features/artisan/presentation/artisan_profile_edit_screen.dart');
      expect(form.contains('final showArtisanVitrin'), isTrue);
      expect(form.contains('hasArtisanProfile'), isTrue);
      expect(form.contains('if (showArtisanVitrin) ...['), isTrue);
      expect(form.contains('USTA VİTRİNİ'), isTrue);
    });

    test('ortak alanlar vitrin bölümünün ÜSTÜNDE', () {
      final form = read(
          'lib/features/artisan/presentation/artisan_profile_edit_screen.dart');
      final telefon = form.indexOf("_Label('Telefon Numarası')");
      final sosyal = form.indexOf("_Label('Sosyal Medya ve Web Sitesi')");
      final hakkimda = form.indexOf("_Label('Hakkımda')");
      final vitrin = form.indexOf('USTA VİTRİNİ');
      expect(telefon, greaterThan(-1));
      expect(telefon, lessThan(vitrin));
      expect(sosyal, lessThan(vitrin));
      expect(hakkimda, lessThan(vitrin));
    });

    test('müşteri modunda usta kaydı YAZILMIYOR', () {
      // artisanProfiles dokümanı yok; yazmaya kalkmak kural ihlali üretirdi.
      final ctrl = read(
          'lib/features/artisan/application/my_profile_controller.dart');
      expect(ctrl.contains('if (ustaMi)'), isTrue);
    });

    test('"Vitrini düzenle" etiketi kalmadı', () {
      final kalan = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.readAsStringSync().contains('Vitrini düzenle')) {
          kalan.add(f.path);
        }
      }
      expect(kalan, isEmpty, reason: 'eski etiket kaldı: $kalan');
    });
  });

  group('Profilde Instagram tarzı bilgi satırları', () {
    late String profil;
    setUpAll(() =>
        profil = read('lib/core/widgets/profile_header.dart'));

    test('ProfileBioDetails çiziliyor', () {
      // 2026-08-09: ortak başlığa taşındı, artık HER İKİ profilde de var.
      expect(profil.contains('ProfileBioDetails(user: user)'), isTrue);
      expect(profil.contains('class ProfileBioDetails'), isTrue);
    });

    test('boş alan HİÇ çizilmiyor', () {
      expect(profil.contains('if (satirlar.isEmpty) return'), isTrue);
    });

    test('küçük font (labelSmall) kullanıyor', () {
      // Sınıf sonuna kadar oku: sabit karakter penceresi sınıf büyüyünce
      // (2026-08-14 WhatsApp ikonu eklendi) hedefin önünde kalıyordu.
      final i = profil.indexOf('class ProfileBioDetails');
      final sonraki = profil.indexOf('\nclass ', i + 1);
      final blok =
          profil.substring(i, sonraki == -1 ? profil.length : sonraki);
      expect(blok.contains('labelSmall'), isTrue);
    });

    test('hakkımda HER İKİ MODDA da görünüyor', () {
      // Eskiden `artisanMode ? ... : null` idi.
      final ekran =
          read('lib/features/profile/presentation/profile_screen.dart');
      expect(ekran.contains('artisanMode ? draft?.profile.aboutText'), isFalse);
      expect(profil.contains('user.aboutText.trim()'), isTrue);
    });
  });

  group('Güvenlik kuralları', () {
    late String rules;
    setUpAll(() => rules = read('firestore.rules'));

    test('yeni alanlar doğrulanıyor', () {
      expect(rules.contains('function profileFieldsOk()'), isTrue);
      expect(rules.contains('profileFieldsOk()'), isTrue);
    });

    test('uzunluk tavanı var (dokümanı şişirme koruması)', () {
      expect(rules.contains('d.aboutText.size() <= 1000'), isTrue);
      expect(rules.contains('d.publicPhone.size() <= 32'), isTrue);
    });

    test('hassas phoneNumber HÂLÂ yasak', () {
      expect(rules.contains("'phoneNumber'"), isTrue);
    });
  });

  group('Profil sadeleştirme (2026-08-08)', () {
    late String profil;
    late String form;
    setUpAll(() {
      profil = read('lib/features/profile/presentation/profile_screen.dart');
      form = read(
          'lib/features/artisan/presentation/artisan_profile_edit_screen.dart');
    });

    test('"Vitrinim" kartı KALKTI', () {
      // Görüntüle/Düzenle düğmeleri başlıktaki ikiliyle mükerrerdi.
      // Yorumda "eskiden şöyleydi" diye geçebilir; aranan KOD izi.
      expect(profil.contains('_ShopVitrineCard('), isFalse);
      expect(profil.contains("Text(\n                          'Vitrinim'"),
          isFalse);
      expect(profil.contains('_ArtisanHome('), isFalse);
    });

    // İkinci düğme 2026-08-09'da "Profilime bak" → "İlanlarım" oldu
    // (madde 2); sıralama beklentisi aynı: anahtar düğmelerin ÜSTÜNDE.
    test('müsaitlik SADE anahtar ve eylem düğmelerinin ÜSTÜNDE', () {
      expect(profil.contains('_AvailabilitySwitch'), isTrue);
      // İmza 2026-08-14'te `(user: user, draft: draft)` oldu; korunan şey
      // parametre listesi değil, anahtarın düğmelerden ÖNCE gelmesi.
      final anahtar = profil.indexOf('_AvailabilitySwitch(user:');
      final ilanlarim = profil.indexOf('İlanlarım');
      expect(anahtar, greaterThan(-1));
      expect(ilanlarim, greaterThan(-1));
      expect(anahtar, lessThan(ilanlarim));
    });

    /// Müsaitlik anahtarının TAM gövdesi.
    ///
    /// 2026-08-14: widget `ConsumerStatefulWidget`'a çevrildi (yazma
    /// koruması için), gövde artık `_AvailabilitySwitchState` içinde.
    /// Bu yüzden State sınıfından başlanır; yoksa yalnız boş sarmalayıcı
    /// okunur ve testler yanlış yere bakar.
    String availabilityBlok() {
      final i = profil.indexOf('class _AvailabilitySwitchState');
      expect(i, greaterThan(-1), reason: 'Müsaitlik anahtarı sınıfı yok.');
      final sonrakiSinif = profil.indexOf('\nclass ', i + 1);
      return profil.substring(
          i, sonrakiSinif == -1 ? profil.length : sonrakiSinif);
    }

    test('anahtarın yanında yalnız "Müsait" yazıyor', () {
      final blok = availabilityBlok();
      expect(blok.contains("'Müsait'"), isTrue);
      // Eski uzun metinler gitti.
      expect(blok.contains('Şu an kapalısın'), isFalse);
      expect(blok.contains('Aç: müşteri aramalarında görün'), isFalse);
    });

    test('kapalıyken PASİF görünüyor (sönük renk)', () {
      final blok = availabilityBlok();
      expect(blok.contains('available ? palette.ink : palette.inkMuted'),
          isTrue);
    });

    test('vitrin tamamlama bandı düzenleme formunda YOK', () {
      // Kullanıcı zaten formun içinde; hangi alanın boş olduğunu görüyor.
      expect(form.contains('_CompletionHint'), isFalse);
      expect(form.contains('ShopCompletionBanner'), isFalse);
    });

    test('bant ilan listesinde DURUYOR (oradaki işlevi gerçek)', () {
      // Usta ilanları göremediğinde sebebini orada açıklıyor.
      final nearby =
          read('lib/features/jobs/presentation/nearby_jobs_screen.dart');
      expect(nearby.contains('ShopCompletionBanner('), isTrue);
    });
  });
}
