// Regresyon: "telefonu profilde göster" KAPATMAK numarayı SİLMEZ (2026-08-23).
//
// Kapalı test bulgusu: "telefon numarası profilde ekleniyor, ama profilde
// telefonu göster seçeneğini kapatınca telefon gidiyor."
//
// Kök neden: tek alan (`users.publicPhone`) iki iş görüyordu — hem "kayıtlı
// numaram" hem "vitrinde yayınlanan numara". Görünürlük anahtarı kapatılınca
// `setPhoneVisibility` bu alanı null'a çekiyor, yani NUMARA SİLİNİYORDU.
// Ardından profil ekranındaki `if (user.publicPhone != null)` koşulu düştüğü
// için anahtar satırı EKRANDAN TAMAMEN KAYBOLUYOR; kullanıcı numarasını
// yeniden girmeden görünürlüğü geri açamıyordu.
//
// Düzeltme iki alanı ayırır:
//   - `savedPhone`  → kalıcı kayıt, `users/{uid}/private/contact` altında
//                     (herkese açık dökümanda DEĞİL — kapalıyken numara
//                     kimseye görünmemeli, CLAUDE.md kural 5).
//   - `publicPhone` → yayın alanı, yalnız anahtar AÇIKKEN dolu, herkese açık.
//
// Çift test (kural 7): düzeltme çalışıyor MU + fazlasını yapmıyor MU.
// "Fazlası" = numarayı hiç silememek. Kullanıcı formdan silerse GİTMELİ.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/app_user.dart';
import 'package:sepette_hizmet/features/auth/data/mock_auth_repository.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  const numara = '+905321234567';

  Future<MockAuthRepository> hesapAc() async {
    final repo = MockAuthRepository();
    await repo.register(
      displayName: 'Deneme Kullanıcı',
      email: 'telefon@test.com',
      password: '123456',
    );
    return repo;
  }

  group('Görünürlük kapatmak numarayı silmez', () {
    test('kapat → numara KAYITLI kalır, yayın düşer', () async {
      final repo = await hesapAc();
      addTearDown(repo.dispose);

      await repo.updateUserProfile(publicPhone: numara);
      final eklendi = repo.currentUser!;
      expect(eklendi.publicPhone, numara, reason: 'Ekleme yayınlamalı.');
      expect(eklendi.contactPhone, numara);

      await repo.setPublicPhoneVisibility(show: false);
      final gizli = repo.currentUser!;

      // Yayın DÜŞER — herkese açık alan boşalır.
      expect(gizli.publicPhone, isNull,
          reason: 'Kapalıyken numara herkese açık alanda kalmamalı.');
      // Numara KALIR — hatanın düzeltildiği yer burası.
      expect(gizli.contactPhone, numara,
          reason: 'Anahtarı kapatmak numarayı silmemeli.');
      expect(gizli.hasContactPhone, isTrue,
          reason: 'Anahtar satırı ekranda kalmalı — bu koşul onu gösterir.');
    });

    test('kapat → geri aç: numara YENİDEN yazdırılmadan yayınlanır', () async {
      final repo = await hesapAc();
      addTearDown(repo.dispose);

      await repo.updateUserProfile(publicPhone: numara);
      await repo.setPublicPhoneVisibility(show: false);

      // Numara VERİLMEDEN açılıyor: kayıtlı numaradan çözülmeli.
      await repo.setPublicPhoneVisibility(show: true);

      expect(repo.currentUser!.publicPhone, numara,
          reason: 'Geri açmak tek dokunuş olmalı; kullanıcı numarayı '
              'yeniden girmek zorunda kalmamalı.');
    });

    test('aç/kapat döngüsü numarayı aşındırmaz', () async {
      final repo = await hesapAc();
      addTearDown(repo.dispose);

      await repo.updateUserProfile(publicPhone: numara);
      for (var i = 0; i < 3; i++) {
        await repo.setPublicPhoneVisibility(show: false);
        await repo.setPublicPhoneVisibility(show: true);
      }
      expect(repo.currentUser!.contactPhone, numara);
      expect(repo.currentUser!.publicPhone, numara);
    });
  });

  group('Fazlasını yapmıyor — numara silinebilir kalmalı', () {
    test('formdan silmek numarayı TAMAMEN kaldırır', () async {
      final repo = await hesapAc();
      addTearDown(repo.dispose);

      await repo.updateUserProfile(publicPhone: numara);
      // Boş dize = ALANI TEMİZLE (updateUserProfile sözleşmesi).
      await repo.updateUserProfile(publicPhone: '');

      final silindi = repo.currentUser!;
      expect(silindi.publicPhone, isNull);
      expect(silindi.savedPhone, isNull,
          reason: 'Kullanıcı numarasını sildiyse kalıcı kayıt da gitmeli — '
              'aksi hâlde KVKK açısından silinemeyen veri kalırdı.');
      expect(silindi.contactPhone, isNull);
      expect(silindi.hasContactPhone, isFalse);
    });

    test('numara değiştirmek eski numarayı bırakmaz', () async {
      final repo = await hesapAc();
      addTearDown(repo.dispose);

      await repo.updateUserProfile(publicPhone: numara);
      const yeni = '+905339876543';
      await repo.updateUserProfile(publicPhone: yeni);

      expect(repo.currentUser!.contactPhone, yeni);
      expect(repo.currentUser!.savedPhone, yeni,
          reason: 'Kalıcı kayıt eski numarada takılı kalmamalı.');
    });

    test('numara yokken açmak yayın oluşturmaz', () async {
      final repo = await hesapAc();
      addTearDown(repo.dispose);

      await repo.setPublicPhoneVisibility(show: true);
      expect(repo.currentUser!.publicPhone, isNull,
          reason: 'Gösterecek numara yokken yayın açılmamalı.');
    });
  });

  group('Kayıtlı numara herkese açık dökümana sızmaz', () {
    test('toMap() savedPhone YAZMIYOR', () {
      final user = AppUser(
        uid: 'u1',
        displayName: 'Deneme',
        email: 'a@b.com',
        createdAt: DateTime(2026, 1, 1),
        savedPhone: numara,
      );
      final map = user.toMap();

      expect(map.containsKey('savedPhone'), isFalse,
          reason: 'Kapalıyken numara herkese açık `users` dökümanında '
              'durursa "gizle" sözü tutulmamış olur (kural 5).');
      // Yayın alanı yerinde — gizleme, yayınlamayı bozmamalı.
      expect(map.containsKey('publicPhone'), isTrue);
    });

    test('kalıcı kayıt private/contact altına yazılıyor', () {
      final fb = read('lib/features/auth/data/firebase_auth_repository.dart');
      expect(fb.contains("doc('contact')"), isTrue,
          reason: 'Kalıcı numara `private/contact` altında yaşamalı.');
      expect(fb.contains("'savedPhone'"), isTrue);
    });
  });

  group('Görünürlük ile numara düzenleme AYRI yollar', () {
    test('vitrin repo kapatırken kalıcı kaydı silmiyor', () {
      final repo =
          read('lib/features/artisan/data/my_profile_repository.dart');
      // Eski hata: kapatma yolu `updateUserProfile(publicPhone: '')`
      // çağırıyor ve numarayı da siliyordu.
      expect(repo.contains("publicPhone: showOnProfile ? (publicPhone ?? '') : ''"),
          isFalse,
          reason: 'Görünürlük kapatma numara silme metoduna bağlanmamalı.');
      expect(repo.contains('setPublicPhoneVisibility'), isTrue,
          reason: 'Yayın için ayrı metot kullanılmalı.');
    });

    test('profil ekranı KAYITLI numarayı okuyor', () {
      final ekran =
          read('lib/features/profile/presentation/profile_screen.dart');
      expect(ekran.contains('user.hasContactPhone'), isTrue,
          reason: 'Anahtar satırı yayın durumuna göre gizlenirse, kapatan '
              'kullanıcı onu bir daha açamaz.');
      expect(ekran.contains('_PhoneEditSheet.show(context, user.contactPhone)'),
          isTrue,
          reason: 'Düzenleme formu gizlenmiş numarayı da açmalı.');
    });
  });
}
