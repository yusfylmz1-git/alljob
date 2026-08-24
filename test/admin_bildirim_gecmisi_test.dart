// Regresyon: gönderilen duyuruların geçmişi görünüyor (2026-08-23).
//
// Denetim bulgusu: "bildirim ekranından gönderilen bildirimler projede
// nerede gözükecek? saçma bir kurgu olmaması lazım."
//
// İki ayrı sorun vardı:
//
//  1. Ekrandaki liste YALNIZ zamanlanmış kampanyaları gösteriyordu
//     (`scheduledCampaigns` koleksiyonu). "Şimdi gönder" ile yollanan
//     duyurunun hiçbir izi yoktu — yönetici "geçen hafta ne gönderdim"
//     sorusunu cevaplayamıyor, aynı duyuruyu iki kez göndermeye karşı
//     koruma da olmuyordu.
//
//  2. Gönderim sonrası mesaj "N alıcı" diyordu ama bildirimin NEREYE
//     düştüğünü söylemiyordu.
//
// Çift test (kural 7): geçmiş geldi Mİ + yeni koleksiyon AÇILMADI MI.
// İkincisi önemli: aynı bilgiyi iki yerde tutmak ayrışma demek.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/features/admin/data/admin_audit_repository.dart';
import 'package:sepette_hizmet/features/admin/data/admin_broadcast_history.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  AuditEntry kayit(String action, Map<String, dynamic> after) => AuditEntry(
        id: 'a1',
        actorUid: 'admin1',
        action: action,
        createdAt: DateTime(2026, 8, 23, 14, 30),
        after: after,
      );

  group('Denetim kaydından duyuru okunuyor', () {
    test('anında gönderim (düz alanlar)', () {
      final r = BroadcastRecord.fromAudit(kayit('broadcast_notification', {
        'title': 'Bakım duyurusu',
        'audience': 'artisans',
        'recipients': 412,
        'sendPush': true,
      }));
      expect(r, isNotNull);
      expect(r!.title, 'Bakım duyurusu');
      expect(r.recipients, 412);
      expect(r.pushSent, isTrue);
      expect(r.scheduled, isFalse);
    });

    test('zamanlanmış kampanya (İÇ İÇE sonuç)', () {
      // `campaign_sent` sonucu `result` nesnesinin içine yazıyor; düz
      // alan bekleyen kod bunları "0 kişi" gösterirdi.
      final r = BroadcastRecord.fromAudit(kayit('campaign_sent', {
        'title': 'Kampanya',
        'audience': 'all',
        'result': {'recipients': 1200, 'pushOk': true},
      }));
      expect(r, isNotNull);
      expect(r!.recipients, 1200,
          reason: 'İç içe sonuç okunamıyor — liste "0 kişi" gösterir.');
      expect(r.pushSent, isTrue);
      expect(r.scheduled, isTrue);
    });

    test('duyuru OLMAYAN kayıt atlanıyor', () {
      // Denetim kaydında 30'dan fazla eylem türü var; hepsi listeye
      // düşerse geçmiş anlamsızlaşır.
      for (final baska in [
        'bulk_plan_update',
        'province_threshold_set',
        'user_suspended',
      ]) {
        expect(BroadcastRecord.fromAudit(kayit(baska, {})), isNull,
            reason: '$baska duyuru sayıldı.');
      }
    });

    test('eksik alanlar ÇÖKMÜYOR', () {
      final r = BroadcastRecord.fromAudit(kayit('broadcast_notification', {}));
      expect(r, isNotNull);
      expect(r!.title, '(başlıksız)');
      expect(r.recipients, 0);
    });
  });

  group('Hedef KOD değil AD gösteriliyor', () {
    const adlar = {'painter': 'Boyacı'};

    test('meslek hedefi çevriliyor', () {
      final r = BroadcastRecord.fromAudit(kayit('broadcast_notification', {
        'audience': 'profession',
        'profession': 'painter',
      }));
      expect(r!.hedefTR(adlar), 'Meslek: Boyacı');
    });

    test('bilinmeyen kod ham hâliyle gösteriliyor', () {
      // Katalogdan kalkmış eski bir kod "—" olarak kaybolmamalı.
      final r = BroadcastRecord.fromAudit(kayit('broadcast_notification', {
        'audience': 'profession',
        'profession': 'eski_kod',
      }));
      expect(r!.hedefTR(adlar), 'Meslek: eski_kod');
    });

    test('diğer hedefler Türkçe', () {
      for (final (kod, beklenen) in [
        ('all', 'Herkes'),
        ('artisans', 'Ustalar'),
        ('customers', 'Müşteriler'),
        ('user', 'Tek kişi'),
      ]) {
        final r = BroadcastRecord.fromAudit(
            kayit('broadcast_notification', {'audience': kod}));
        expect(r!.hedefTR(adlar), beklenen);
      }
    });
  });

  group('Fazlasını yapmıyor — yeni koleksiyon YOK', () {
    test('kaynak denetim kaydı', () {
      // Ayrı koleksiyon açmak aynı bilgiyi iki kopyada tutmak ve ikisinin
      // ayrışması demekti.
      final kaynak = read(
          'lib/features/admin/data/admin_broadcast_history.dart');
      expect(kaynak.contains('adminAuditRepositoryProvider'), isTrue);
      expect(kaynak.contains("collection('broadcasts')"), isFalse,
          reason: 'Yeni koleksiyon açılmış — veri iki yerde.');
    });

    test('YENİ İNDEKS gerektirmiyor', () {
      // `action` filtresi eklemek `action + createdAt` bileşik indeksi
      // demekti. Duyuru seyrek bir işlem; bellekte süzmek yeterli.
      final kaynak = read(
          'lib/features/admin/data/admin_broadcast_history.dart');
      expect(kaynak.contains('whereType<BroadcastRecord>()'), isTrue,
          reason: 'Filtreleme bellekte yapılmıyor.');
      final idx = read('firestore.indexes.json');
      expect(idx.contains('"action"'), isFalse,
          reason: 'Denetim kaydına yeni indeks eklenmiş.');
    });

    test('liste sınırlı (sayfa şişmesin)', () {
      final kaynak = read(
          'lib/features/admin/data/admin_broadcast_history.dart');
      expect(kaynak.contains('limit: 200'), isTrue);
      expect(kaynak.contains('.take(20)'), isTrue);
    });
  });

  group('Ekran nereye düştüğünü SÖYLÜYOR', () {
    late String ekran;
    setUpAll(() => ekran = read(
        'lib/features/admin/presentation/admin_broadcast_screen.dart'));

    test('gönderim sonrası bildirim merkezi anılıyor', () {
      expect(ekran.contains('bildirim merkezinde görünüyor'), isTrue,
          reason: 'Yönetici bildirimin nereye düştüğünü bilmiyordu.');
    });

    test('geçmiş listesi ekranda', () {
      expect(ekran.contains('Son gönderilenler'), isTrue);
      expect(ekran.contains('broadcastHistoryProvider'), isTrue);
    });

    test('gönderimden sonra liste TAZELENİYOR', () {
      // Yönetici gönderdiği duyuruyu hemen listede görmeli.
      expect(ekran.contains('ref.invalidate(broadcastHistoryProvider)'),
          isTrue);
    });

    test('zamanlanmış liste KALDIRILMADI', () {
      // İki liste farklı iş görür: biri gelecek, diğeri geçmiş.
      expect(ekran.contains('scheduledCampaignsProvider'), isTrue,
          reason: 'Planlanan kampanyalar listesi kaybolmuş.');
    });
  });
}
