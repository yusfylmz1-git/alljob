import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Madde 10 — hesap silme tüm kişisel veriyi kapsamalı (KVKK + Play).
///
/// `deleteAccount` CF'i zaten ilanları, favorileri, profili, storage'ı ve
/// alt koleksiyonları siliyordu; envanter çıkarılınca uid taşıyan DÖRT
/// koleksiyonun hiç ele alınmadığı görüldü. Bu test o boşluğun geri
/// açılmasını engeller.
///
/// Ayrım bilinçlidir ve iki yönlü hukuki ölçüte dayanır:
///   SİL      → kişisel veri, saklamanın meşru gerekçesi yok
///   ANONİM   → kayıt iki taraflı / kötüye kullanım kanıtı, kimlik düşer
///
/// Karşı test de var: şikayet ve denetim izlerini SİLEN kod eklenirse
/// "şikayet edilince hesabı sil, temize çık" açığı doğar — o yüzden
/// silinmediklerini de doğruluyoruz.
void main() {
  late String cf;

  setUpAll(() => cf = File('functions/index.js').readAsStringSync());

  /// `deleteAccount` gövdesi — sonraki `exports.` tanımına kadar.
  String deleteAccountBody() {
    final start = cf.indexOf('exports.deleteAccount');
    expect(start, isNot(-1), reason: 'deleteAccount CF bulunamadı.');
    final next = cf.indexOf('\nexports.', start + 1);
    return cf.substring(start, next == -1 ? cf.length : next);
  }

  group('Hesap silme — SİLİNMESİ gerekenler', () {
    test('üyelik satın alma kaydı silinir (Play token kişisel veri)', () {
      final body = deleteAccountBody();
      expect(
        body.contains('membershipPurchases'),
        isTrue,
        reason: 'Play purchaseToken hesap silinince kalmamalı.',
      );
      expect(
        RegExp(r'delete\(\s*db\.collection\("membershipPurchases"\)')
            .hasMatch(body.replaceAll('\n', ' ')),
        isTrue,
        reason: 'membershipPurchases anonimleştirilmez, SİLİNİR.',
      );
    });

    test('daha önce kapsanan veriler kapsamda kalır', () {
      final body = deleteAccountBody();
      // Regresyon: bunlardan biri düşerse silme eksik kalır.
      for (final k in const [
        'jobs',
        'favorites',
        'staffNeeds',
        'staffWorkers',
        'products',
        'artisanProfiles',
        'recursiveDelete',
        'deleteFiles',
        'deleteUser',
      ]) {
        expect(body.contains(k), isTrue, reason: '$k kapsamdan düşmüş.');
      }
    });
  });

  group('Hesap silme — ANONİMLEŞTİRİLMESİ gerekenler', () {
    test('destek talebinde kimlik düşer, gövde kalır', () {
      final body = deleteAccountBody();
      expect(body.contains('supportTickets'), isTrue);
      expect(
        body.contains('deletedAccount'),
        isTrue,
        reason: 'Talep anonimleştiğine dair işaret taşımalı.',
      );
      expect(
        RegExp(r'delete\(\s*db\.collection\("supportTickets"\)')
            .hasMatch(body.replaceAll('\n', ' ')),
        isFalse,
        reason: 'Destek yazışması iki taraflı kayıttır, silinmez.',
      );
    });

    test('şikayette yalnız ŞİKAYET EDENİN kimliği düşer', () {
      final body = deleteAccountBody();
      expect(body.contains('reporterUid'), isTrue);
      expect(
        body.contains('reporterDeleted'),
        isTrue,
        reason: 'Anonimleşme işareti olmalı.',
      );
      // Şikayet EDİLEN kimliği kaydın kendisidir; düşerse kayıt anlamsız.
      expect(
        body.contains('reportedUid'),
        isFalse,
        reason: 'Şikayet edilenin kimliği silme yolunda DEĞİŞTİRİLMEMELİ.',
      );
    });
  });

  group('Hesap silme — KORUNMASI gerekenler (kötüye kullanım açığı)', () {
    test('şikayet kayıtları silinmez', () {
      final flat = deleteAccountBody().replaceAll('\n', ' ');
      expect(
        RegExp(r'delete\(\s*db\.collection\("reports"\)').hasMatch(flat),
        isFalse,
        reason: 'Şikayet silinirse hesabı silip temize çıkma açığı doğar.',
      );
    });

    test('yönetici denetim izleri silinmez', () {
      final body = deleteAccountBody();
      for (final k in const [
        'adminUserNotes',
        'premiumOverrides',
        'adminAuditLogs',
      ]) {
        expect(
          body.contains(k),
          isFalse,
          reason: '$k denetim izidir, silme yolunda yer almamalı.',
        );
      }
    });
  });

  group('Silme YARIDA KALMAMALI (13. bulgu)', () {
    // Anonimleştirme `update` kullanır; `update` OLMAYAN dokümanda NOT_FOUND
    // fırlatır (ör. kullanıcının hiç destek talebi/üyeliği yoksa). Varsayılan
    // BulkWriter işleyicisi bunu yutmaz → hata `close()`tan çıkar, Auth kaydı
    // SİLİNMEDEN fonksiyon düşer ve kullanıcı "hesabım silinmedi" der.
    test('BulkWriter hatası silmeyi düşürmez', () {
      final body = deleteAccountBody();
      expect(body.contains('onWriteError'), isTrue,
          reason: 'NOT_FOUND yutulmazsa silme yarıda kalır.');
      expect(
        RegExp(r'try\s*\{\s*await writer\.close\(\);')
            .hasMatch(body.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ')),
        isTrue,
        reason: 'Anonimleştirme temizliktir; silmenin ön koşulu değildir.',
      );
    });

    test('Auth kaydı zaten yoksa başarı sayılır', () {
      // Önceki deneme yarıda kaldıysa Auth kaydı silinmiş olabilir; ikinci
      // denemede NOT_FOUND fırlatmak kullanıcıyı kilitlerdi.
      final body = deleteAccountBody();
      expect(body.contains('auth/user-not-found'), isTrue);
    });

    test('Auth silme EN SON çalışır (sıra korunur)', () {
      // Veri temizlenmeden Auth silinirse kullanıcı tekrar deneyemez.
      final body = deleteAccountBody();
      expect(
        body.indexOf('recursiveDelete') < body.indexOf('deleteUser'),
        isTrue,
        reason: 'Auth kaydı en sonda silinmeli.',
      );
    });
  });

  group('Şikayet doküman kimliği', () {
    test('kimlik taşınmaz — tekillik garantisi korunur', () {
      // ID formatı {tip}_{hedef}__{reporterUid}; kural bu formata dayanarak
      // "hedef başına şikayetçi başına TEK kayıt" garantisi veriyor. Anonim
      // hale getirmek için dokümanı taşımak o garantiyi bozar.
      final rules = File('firestore.rules').readAsStringSync();
      expect(
        rules.contains("reportId == request.resource.data.targetType"),
        isTrue,
        reason: 'Kimlik türetme kuralı durduğu sürece doküman taşınamaz.',
      );
    });
  });
}
