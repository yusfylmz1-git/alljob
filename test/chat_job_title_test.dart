import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/models/chat.dart';

/// B-19 regresyonu — ilan bazlı sohbette İŞ BAŞLIĞI kaybolmamalı.
///
/// Başlık, ilan bazlı sohbet mimarisinin kullanıcıya görünen tek işaretidir:
/// aynı kişiyle birden çok iş konuşulduğunda hangi sohbetin hangi işe ait
/// olduğu buradan anlaşılır. Kaybolunca liste okunamaz hâle gelir.
void main() {
  ChatThread thread({String? jobId, String? jobTitle}) => ChatThread(
        id: 'chat_c1__a1${jobId == null ? '' : '__$jobId'}',
        customerUid: 'c1',
        artisanUid: 'a1',
        customerName: 'Müşteri',
        artisanName: 'Usta',
        updatedAt: DateTime(2026, 1, 1),
        jobId: jobId,
        jobTitle: jobTitle,
      );

  group('B-19 · copyWith ilan alanlarını korur', () {
    test('lastMessage güncellemesi jobId/jobTitle düşürmez', () {
      final before = thread(jobId: 'job1', jobTitle: 'Mutfak dolabı montajı');
      final after = before.copyWith(lastMessage: 'merhaba');

      expect(after.jobId, 'job1');
      expect(after.jobTitle, 'Mutfak dolabı montajı',
          reason: 'copyWith ilan başlığını silmemeli — liste/AppBar bunu '
              'gösterir.');
      expect(after.lastMessage, 'merhaba');
    });

    test('arşiv/kilit güncellemeleri de düşürmez', () {
      final before = thread(jobId: 'job2', jobTitle: 'Boya işi');
      final after = before
          .copyWith(archivedBy: {'c1'})
          .copyWith(lockedAt: DateTime(2026, 2, 1))
          .copyWith(customerStarted: true);

      expect(after.jobId, 'job2');
      expect(after.jobTitle, 'Boya işi');
      expect(after.customerStarted, isTrue);
      expect(after.isLocked, isTrue);
    });
  });

  group('B-19 · isJobChat başlıktan bağımsızdır', () {
    test('jobId varsa başlık boş olsa da ilan sohbetidir', () {
      // Eski/iskelet dökümanlarda jobTitle eksik olabilir; sohbetin ilan
      // bazlı OLDUĞU bilgisi kaybolmamalı.
      //
      // NOT (2026-08-15): sohbet LİSTESİ artık ilan başlığı satırını
      // çizmiyor (kullanıcı kararı). `isJobChat` yine de anlamlıdır —
      // sohbet kimliği ilana bağlıdır ve AppBar başlığı bunu kullanır.
      final t = thread(jobId: 'job3');

      expect(t.isJobChat, isTrue);
      expect(t.jobTitle, isNull);
    });

    test('jobId yoksa genel sohbettir', () {
      expect(thread().isJobChat, isFalse);
    });

    test('boş jobId ilan sohbeti saymaz', () {
      expect(thread(jobId: '').isJobChat, isFalse);
    });
  });
}
