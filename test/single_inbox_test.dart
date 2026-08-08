import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tek mesaj kutusu sözleşmesi (2026-08-08).
///
/// Kullanıcı kararı: "Tek mesajlaşma kutusu olsun, her ilan için ayrı mesaj
/// kutusu açılmasına gerek yok. Kişi ile olan sohbet tek yerden görüntülensin."
void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Sohbet listesinde sekme YOK', () {
    late String list;
    setUpAll(() =>
        list = read('lib/features/chat/presentation/chat_list_screen.dart'));

    test('"İlan Mesajları / Genel" sekmeleri kaldırıldı', () {
      // Yorumda "eskiden şöyleydi" diye geçebilir; aranan KOD izi.
      expect(list.contains("label: 'İlan Mesajları'"), isFalse);
      expect(list.contains('_ChatScope'), isFalse);
      expect(list.contains('_ScopeTab'), isFalse);
      expect(list.contains('TabBar('), isFalse);
      expect(list.contains('TabController'), isFalse);
    });

    test('tümü/okunmamış/arşiv filtresi DURUYOR', () {
      // Sekme gitti diye filtreler de gitmemeli.
      expect(list.contains('_ChatFilter'), isTrue);
      expect(list.contains('okunmamis'), isTrue);
      expect(list.contains('arsiv'), isTrue);
    });
  });

  group('Sohbet kimliği ilandan türemez', () {
    test('Firebase: chatIdFor jobId almıyor', () {
      final repo =
          read('lib/features/chat/data/firebase_chat_repository.dart');
      expect(
        repo.contains('static String chatIdFor(String customerUid, '
            'String artisanUid) =>'),
        isTrue,
      );
      // Eski 3 parçalı birleştirme kalmamalı.
      expect(repo.contains(r"'${base}__$jobId'"), isFalse);
    });

    test('Mock paritesi: aynı imza (CLAUDE.md kural 1)', () {
      final mock = read('lib/features/chat/data/chat_repository.dart');
      expect(
        mock.contains('static String chatIdFor(String customerUid, '
            'String artisanUid) =>'),
        isTrue,
      );
      expect(mock.contains(r"'${base}__$jobId'"), isFalse);
    });

    test('değerlendirme sohbete HİÇ bağlı değil', () {
      // 2026-08-08: değerlendirme kimliği kişi çiftinden türüyor
      // (rev_{yazan}__{hedef}); sohbet/ilan bağımlılığı tamamen kalktı.
      final review =
          read('lib/features/review/presentation/review_screen.dart');
      expect(review.contains('chatIdFor'), isFalse);
      expect(review.contains('FirebaseChatRepository'), isFalse);
    });
  });
}
