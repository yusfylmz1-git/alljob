import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tek profil tasarımı sözleşmesi (2026-08-09).
///
/// Kullanıcı kararı: "insanların birbirine bakabildiği ekranı da profilim
/// sayfasına benzetelim; sadece düğmeler değişsin — Instagram'daki gibi
/// mesaj ve takip düğmesi gelsin."
void main() {
  String read(String p) => File(p).readAsStringSync();

  late String header;
  late String kendi;
  late String usta;
  late String musteri;

  setUpAll(() {
    header = read('lib/core/widgets/profile_header.dart');
    kendi = read('lib/features/profile/presentation/profile_screen.dart');
    usta = read('lib/features/customer/presentation/artisan_profile_screen.dart');
    musteri = read('lib/features/customer/presentation/public_user_screen.dart');
  });

  group('Üç ekran da AYNI başlığı kullanıyor', () {
    test('kendi profilim', () => expect(kendi.contains('ProfileHeader('), isTrue));
    test('usta profili', () => expect(usta.contains('ProfileHeader('), isTrue));
    test('müşteri profili',
        () => expect(musteri.contains('ProfileHeader('), isTrue));

    test('başlık TEK yerde tanımlı', () {
      expect(header.contains('class ProfileHeader'), isTrue);
      // Kopyalanmış ikinci bir tanım olmamalı.
      expect(kendi.contains('class ProfileHeader'), isFalse);
      expect(usta.contains('class ProfileHeader'), isFalse);
    });
  });

  group('Sadece DÜĞMELER değişiyor', () {
    // 2026-08-09 (madde 2): ikinci düğme "Profilime bak" → "İlanlarım".
    // Kendi profilindeyken profili tekrar açan düğmenin karşılığı yoktu;
    // kullanıcı asıl kendi ilanlarına ulaşamıyordu.
    test('kendi profilimde: düzenle + İlanlarım', () {
      // 2026-08-14: düğmeler `label: const Text('…')` biçimine geçti.
      // Korunan şey yazım biçimi değil, hangi düğmelerin bulunduğu.
      expect(kendi.contains('Profili düzenle'), isTrue);
      expect(kendi.contains('İlanlarım'), isTrue);
      expect(kendi.contains('Profilime bak'), isFalse);
    });

    test('usta profilinde: Mesaj + Takip', () {
      expect(usta.contains("label: 'Mesaj'"), isTrue);
      expect(usta.contains('_TakipDugmesi'), isTrue);
    });

    test('müşteri profilinde: Mesaj + Takip', () {
      expect(musteri.contains("label: 'Mesaj'"), isTrue);
      expect(musteri.contains('_TakipDugmesi'), isTrue);
    });

    test('takip düğmesi durumu yansıtıyor', () {
      expect(usta.contains("takipte ? 'Takiptesin' : 'Takip et'"), isTrue);
      expect(musteri.contains("takipte ? 'Takiptesin' : 'Takip et'"), isTrue);
    });

    test('başkasının profilinde DÜZENLE düğmesi yok', () {
      // isOwner/isMe dalı dışında düzenlemeye giriş olmamalı.
      expect(usta.contains('isOwner'), isTrue);
      expect(musteri.contains('isMe'), isTrue);
    });
  });

  group('Ortak alanlar her profilde görünüyor', () {
    test('telefon · web · sosyal medya satırları', () {
      expect(header.contains('class ProfileBioDetails'), isTrue);
      expect(header.contains('ProfileBioDetails(user: user)'), isTrue);
      expect(header.contains('user.publicPhone'), isTrue);
      expect(header.contains('s.website'), isTrue);
      expect(header.contains('s.instagram'), isTrue);
    });

    test('hakkımda ve mavi tik', () {
      expect(header.contains('user.aboutText'), isTrue);
      expect(header.contains('Icons.verified'), isTrue);
    });

    test('sayaçlar: takip · takipçi · değerlendirme', () {
      expect(header.contains("label: 'takip'"), isTrue);
      expect(header.contains("label: 'takipçi'"), isTrue);
      expect(header.contains("label: 'değerlendirme'"), isTrue);
    });
  });

  group('Gizlilik: başkasının listesi gezilemez', () {
    test('sayaçlar yalnız KENDİ profilimde tıklanır', () {
      expect(header.contains('isMe ? () => context.push(RoutePaths.favorites)'),
          isTrue);
      expect(header.contains('isMe ? () => context.push(RoutePaths.followers)'),
          isTrue);
    });

    test('kendi profilim isMe: true veriyor', () {
      expect(kendi.contains('isMe: true'), isTrue);
    });

    test('başkasının profilinde isMe VERİLMİYOR (varsayılan false)', () {
      // ProfileHeader çağrısında isMe geçilmezse sayaçlar pasif kalır.
      final i = usta.indexOf('ProfileHeader(');
      final blok = usta.substring(i, i + 300);
      expect(blok.contains('isMe: true'), isFalse);
    });
  });

  group('Kaybolmayan davranışlar', () {
    test('"Seni takip ediyor" rozeti duruyor', () {
      expect(usta.contains('_SeniTakipEdiyor'), isTrue);
      expect(musteri.contains('Seni takip ediyor'), isTrue);
    });

    test('değerlendirme bloğu her iki profilde', () {
      expect(usta.contains('ReviewCta('), isTrue);
      expect(musteri.contains('ReviewCta('), isTrue);
      expect(musteri.contains('ReviewList('), isTrue);
    });

    test('usta profilinde VİTRİN duruyor', () {
      // İş fotoğrafları, hizmet bölgeleri: usta profilinin gövdesi.
      expect(usta.contains('İş fotoğrafları'), isTrue);
      expect(usta.contains('Hizmet bölgeleri'), isTrue);
    });

    test('müsaitlik anahtarı yalnız KENDİ profilimde', () {
      expect(kendi.contains('_AvailabilitySwitch'), isTrue);
      expect(usta.contains('_AvailabilitySwitch'), isFalse);
    });
  });

  group('Ölü kod temizlendi', () {
    test('eski koyu gradyan başlık widgetları gitti', () {
      for (final ad in ['_HeroStats', '_StatCell', '_AvatarWithEdit',
                        '_HeroAction', '_BioDetails']) {
        expect(kendi.contains('class $ad'), isFalse, reason: ad);
      }
    });

    test('usta profilindeki kopya sayaç/rozet gitti', () {
      for (final ad in ['_Stat', '_HeroTag', '_FollowsYouBadge',
                        '_PublicPhoneChip']) {
        expect(usta.contains('class $ad '), isFalse, reason: ad);
      }
    });
  });
}
