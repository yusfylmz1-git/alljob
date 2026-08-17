import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ölçek korumaları (2026-08-14).
///
/// Denetimde iki açık iş bırakılmıştı: mesaj gönderiminde sunucu tarafı hız
/// sınırı yoktu ve ilan fan-out'u alıcı başına ayrı Firestore turu yapıyordu.
/// Bu testler ikisinin de geri gitmesini engeller.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Mesaj hız sınırı SUNUCUDA', () {
    late String rules;
    setUpAll(() => rules = read('firestore.rules'));

    test('kuralda hız sınırı var', () {
      // İstemcideki `minMessageInterval` ATLATILABİLİR: doğrudan SDK
      // çağrısı yapan biri saniyede yüzlerce mesaj yazabilirdi.
      expect(rules.contains('messageRateOk'), isTrue,
          reason: 'Sunucu tarafı hız sınırı yok — spam/fatura riski.');
      expect(rules.contains('duration.value(1, \'s\')'), isTrue);
    });

    test('mesaj create kuralı hız sınırını çağırıyor', () {
      // Fonksiyon tanımlı olup çağrılmazsa koruma etkisizdir.
      // MESAJ bloğundaki create'i bul (dosyada birden çok `allow create` var);
      // `messageRateOk` tanımından SONRAKİ ilk create doğru olanıdır.
      final tanim = rules.indexOf('function messageRateOk');
      expect(tanim, greaterThan(-1));
      final i = rules.indexOf('allow create: if isSignedIn()', tanim);
      expect(i, greaterThan(-1));
      final govde = rules.substring(i, i + 500);
      expect(govde.contains('messageRateOk()'), isTrue);
    });

    test('createdAt SUNUCU damgası olmak zorunda', () {
      // İstemci geçmiş tarih yazarak sınırı atlatamasın.
      expect(rules.contains('createdAt == request.time'), isTrue);
    });

    test('istemci serverTimestamp yazıyor (kural paritesi)', () {
      // Kural `request.time` arıyor; istemci `Timestamp.fromDate` yazarsa
      // TÜM mesajlar reddedilir — sessiz ve tam kırılma.
      final repo =
          read('lib/features/chat/data/firebase_chat_repository.dart');
      final i = repo.indexOf("collection('messages').add(");
      final govde = repo.substring(i, i + 900);
      expect(govde.contains('FieldValue.serverTimestamp()'), isTrue,
          reason: 'İstemci yerel saat yazıyor — kural tüm mesajları reddeder.');
      // Yalnız KOD satırlarına bak: açıklama yorumu neden
      // `Timestamp.fromDate` KULLANILMADIĞINI anlatıyor.
      final kod = govde
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(kod.contains('Timestamp.fromDate'), isFalse,
          reason: 'createdAt hâlâ istemci saatiyle yazılıyor.');
    });

    test('updatedAt de sunucu damgası (aynı saat kaynağı)', () {
      // İkisi farklı kaynaktan gelirse saati ileri cihazlar engellenir.
      final repo =
          read('lib/features/chat/data/firebase_chat_repository.dart');
      final i = repo.indexOf("'lastMessage':");
      final govde = repo.substring(i, i + 700);
      expect(govde.contains('FieldValue.serverTimestamp()'), isTrue);
    });

    test('eski sohbetler kilitlenmiyor (updatedAt yoksa serbest)', () {
      // Geriye dönük veri korunmalı; aksi hâlde eski sohbetlerde kimse
      // mesaj gönderemez.
      final i = rules.indexOf('function messageRateOk');
      final govde = rules.substring(i, i + 500);
      expect(govde.contains('son == null'), isTrue,
          reason: 'updatedAt olmayan eski sohbetler kilitlenir.');
    });
  });

  group('İlan fan-out maliyeti', () {
    late String cf;
    setUpAll(() => cf = read('functions/index.js'));

    test('token okuması TOPLU (alıcı başına ayrı tur değil)', () {
      expect(cf.contains('getFcmTokensBulk'), isTrue,
          reason: '120 alıcı = 120 ayrı Firestore round-trip.');
      expect(cf.contains('db.getAll('), isTrue);
    });

    test('fan-out toplu okumayı kullanıyor', () {
      final i = cf.indexOf('exports.onJobCreated');
      final j = cf.indexOf('\nexports.', i + 1);
      final govde = cf.substring(i, j == -1 ? cf.length : j);
      expect(govde.contains('getFcmTokensBulk(recipientUids)'), isTrue);
      // Eski worker havuzu kalmamalı.
      expect(govde.contains('tokenWorker'), isFalse,
          reason: 'Eski N+1 worker havuzu geri gelmiş.');
    });

    test('alıcı tavanı duruyor', () {
      expect(cf.contains('JOB_FANOUT_RECIPIENT_CAP = 120'), isTrue,
          reason: 'Tavan kalkarsa tek ilan binlerce push tetikler.');
    });

    test('tercih atlaması SADECE o kullanıcıyı atlıyor', () {
      // ESKİ HATA: `return` worker'ı tamamen sonlandırıyordu — bildirimi
      // kapatmış tek kullanıcı, kuyruktaki herkesin bildirimini de
      // engelliyordu (sessiz kayıp).
      final i = cf.indexOf('exports.onJobCreated');
      final j = cf.indexOf('\nexports.', i + 1);
      final govde = cf.substring(i, j == -1 ? cf.length : j);
      final k = govde.indexOf('prefsSkipped++');
      expect(k, greaterThan(-1));
      final sonra = govde.substring(k, k + 400);
      expect(sonra.contains('continue'), isTrue,
          reason: 'prefsSkipped sonrası `return` — tüm kuyruk düşer.');
    });
  });
}
