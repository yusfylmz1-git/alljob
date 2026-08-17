import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Doğrudan iletişim sözleşmesi (2026-08-08).
///
/// İş akışı (ilgi bildir → "Ustayı Seç" → tamamlama onayı) UI'dan kaldırıldı.
/// Usta ilan sahibine **doğrudan mesaj atar**; anlaşma taraflar arasında.
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Sohbet ekranı iş akışından ayrıldı', () {
    late String chat;
    setUpAll(() =>
        chat = read('lib/features/chat/presentation/chat_screen.dart'));

    test('"Bu Ustayı Seç" şeridi YOK', () {
      expect(chat.contains('_JobSelectBar'), isFalse);
      expect(chat.contains('selectArtisanForJob'), isFalse);
    });

    test('tamamlama onayı şeridi YOK', () {
      expect(chat.contains('_JobCompletionChatBar'), isFalse);
      expect(chat.contains('JobCompletionCopy'), isFalse);
    });
  });

  group('Eski akışın kodu tamamen kalktı', () {
    // Bu dosyalar UI'dan kopmuştu ama ölü kod olarak duruyordu (oturum 83).
    // Geri gelirlerse sadeleştirme sessizce geri alınmış demektir.
    test('usta seçimi yardımcısı YOK', () {
      expect(File('lib/features/jobs/application/select_artisan.dart')
          .existsSync(), isFalse);
    });

    test('tamamlama onayı widget\'ları YOK', () {
      expect(File('lib/features/jobs/presentation/job_completion.dart')
          .existsSync(), isFalse);
    });
  });

  group('İlan detayı sadeleşti', () {
    late String jd;
    setUpAll(() => jd =
        read('lib/features/jobs/presentation/job_detail_screen.dart'));

    test('usta DOĞRUDAN mesaj atıyor (ilgi bildirme ara adımı yok)', () {
      expect(jd.contains('_messageOwner'), isTrue);
      expect(jd.contains("label: Text('Mesaj Gönder')") ||
          jd.contains("Text('Mesaj Gönder')"), isTrue);
      // Eski akış izleri — YORUMDA geçebilir ("eskiden şöyleydi"),
      // asıl kontrol ÇAĞRI olarak durmaması.
      expect(jd.contains("Text('Bildirim Gönder')"), isFalse);
      expect(jd.contains('.submitOffer('), isFalse);
    });

    test('sahip tarafında teklif listesi/seçim YOK', () {
      expect(jd.contains('_OfferCard('), isFalse);
      expect(jd.contains("Text('İlgilenen Ustalar')"), isFalse);
      expect(jd.contains('.confirmDone('), isFalse);
      expect(jd.contains('_AssignedCard'), isFalse);
      expect(jd.contains('_LifecycleStepper'), isFalse);
    });

    test('KAPILAR korundu (usta tarafı)', () {
      // Sadeleştirme güvenliği gevşetmemeli.
      expect(jd.contains('ensureEmailVerified'), isTrue);
      expect(jd.contains('user.suspended'), isTrue);
      expect(jd.contains('job.matchesArtisan'), isTrue);

      // MÜSAİTLİK KAPISI: satır içi `!profile.isAvailable` kontrolü ortak
      // kapıya taşındı (`availability_gate.dart`). Sebep: sohbet başlatan
      // DÖRT giriş vardı (ilan detayı, usta profili, kullanıcı profili,
      // ürün detayı) ve kapı birinde unutulunca müsait olmayan kişi
      // oradan yazabiliyordu.
      //
      // Kapı burada ÇAĞRILIYOR mu?
      expect(jd.contains('artisanAvailabilityAllowsNewChat('), isTrue,
          reason: 'Müsaitlik kapısı ilan detayında çağrılmıyor — müsait '
              'olmayan usta buradan sohbet başlatabilir.');
    });

    test('ortak müsaitlik kapısı gerçekten müsaitliğe bakıyor', () {
      // Yukarıdaki test yalnız ÇAĞRIyı doğruluyor; kapının içi boşaltılırsa
      // çağrı durur ama koruma kaybolurdu.
      final gate =
          read('lib/features/artisan/application/availability_gate.dart');
      expect(gate.contains('isAvailable'), isTrue);
      expect(gate.contains('user.available'), isTrue);
    });

    test('ilan yönetimi (düzenle/iptal/sil) duruyor', () {
      expect(jd.contains('_editJob'), isTrue);
      expect(jd.contains('_cancelJob'), isTrue);
      expect(jd.contains('_DeleteJobButton'), isTrue);
    });
  });
}
