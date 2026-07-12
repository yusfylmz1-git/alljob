import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usta_cepte/app.dart';
import 'package:usta_cepte/core/router/app_router.dart';
import 'package:usta_cepte/core/router/route_paths.dart';
import 'package:usta_cepte/data/models/track_item.dart';
import 'package:usta_cepte/features/auth/application/auth_controller.dart';
import 'package:usta_cepte/features/tracking/application/tracking_controller.dart';
import 'package:usta_cepte/features/tracking/data/attachment_store.dart';
import 'package:usta_cepte/features/tracking/data/mock_tracking_repository.dart';
import 'package:usta_cepte/features/tracking/data/track_notification_service.dart';
import 'package:usta_cepte/features/tracking/data/tracking_providers.dart';
import 'package:usta_cepte/features/tracking/presentation/track_detail_screen.dart';
import 'package:usta_cepte/features/tracking/presentation/track_edit_screen.dart';
import 'package:usta_cepte/features/tracking/presentation/tracking_center_screen.dart';
import 'package:usta_cepte/features/tracking/presentation/tracking_trash_screen.dart';
import 'package:usta_cepte/features/tracking/presentation/widgets/track_card.dart';

import 'helpers/mock_backend.dart';

void main() {
  group('TrackItem modeli', () {
    test('toMap/fromMap tam tur — tüm alanlar korunur', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
      final item = TrackItem(
        id: 'a1',
        title: 'Kombi bakımı',
        note: 'Yılda bir',
        status: TrackStatus.active,
        priority: TrackPriority.high,
        tags: const ['ev', 'bakım'],
        reminderAt: now.add(const Duration(days: 3)),
        recurrence: TrackRecurrence.yearly,
        person: const TrackPerson(name: 'Ahmet Usta', phone: '+905551112233'),
        location: const TrackLocation(label: 'Kadıköy', lat: 40.9, lng: 29.0),
        attachments: const [
          TrackAttachment(
              type: TrackAttachmentType.audio, path: '/x.m4a', durationMs: 4200),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final round = TrackItem.fromMap(item.toMap());
      expect(round.id, 'a1');
      expect(round.title, 'Kombi bakımı');
      expect(round.note, 'Yılda bir');
      expect(round.priority, TrackPriority.high);
      expect(round.tags, ['ev', 'bakım']);
      expect(round.reminderAt, item.reminderAt);
      expect(round.recurrence, TrackRecurrence.yearly);
      expect(round.person?.name, 'Ahmet Usta');
      expect(round.person?.phone, '+905551112233');
      expect(round.location?.label, 'Kadıköy');
      expect(round.location?.lat, 40.9);
      expect(round.attachments.single.type, TrackAttachmentType.audio);
      expect(round.attachments.single.durationMs, 4200);
      expect(round.deletedAt, isNull);
    });

    test('newId çakışmaz', () {
      final ids = {for (var i = 0; i < 500; i++) TrackItem.newId()};
      expect(ids.length, 500);
    });

    test('bozuk/eksik enum değerleri güvenli varsayılana düşer', () {
      final t = TrackItem.fromMap({
        'id': 'x',
        'title': 'y',
        'status': 'bozuk',
        'priority': 'yok',
        'recurrence': '???',
        'createdAt': 1,
        'updatedAt': 2,
      });
      expect(t.status, TrackStatus.active);
      expect(t.priority, TrackPriority.normal);
      expect(t.recurrence, TrackRecurrence.none);
      expect(t.tags, isEmpty);
    });
  });

  group('MockTrackingRepository — CRUD + çöp/geri al', () {
    late MockTrackingRepository repo;
    const uid = 'user_1';

    TrackItem make(String id, String title) {
      final now = DateTime.now();
      return TrackItem(id: id, title: title, createdAt: now, updatedAt: now);
    }

    setUp(() => repo = MockTrackingRepository());
    tearDown(() => repo.dispose());

    test('upsert oluşturur ve günceller; aktif akış yansıtır', () async {
      await repo.upsert(uid, make('1', 'İlk'));
      expect((await repo.watchActive(uid).first).map((e) => e.title), ['İlk']);

      // Aynı id ile upsert → günceller (çoğaltmaz).
      final updated = (await repo.getById('1'))!
          .copyWith(title: 'Güncellendi', updatedAt: DateTime.now());
      await repo.upsert(uid, updated);
      final active = await repo.watchActive(uid).first;
      expect(active.length, 1);
      expect(active.single.title, 'Güncellendi');
    });

    test('çöpe atma aktiften düşürür, çöpe koyar; geri alma döndürür', () async {
      await repo.upsert(uid, make('1', 'Kayıt'));
      await repo.moveToTrash('1');

      expect(await repo.watchActive(uid).first, isEmpty);
      final trashed = await repo.watchTrashed(uid).first;
      expect(trashed.single.id, '1');
      expect(trashed.single.isTrashed, isTrue);

      await repo.restore('1');
      expect(await repo.watchTrashed(uid).first, isEmpty);
      final active = await repo.watchActive(uid).first;
      expect(active.single.id, '1');
      expect(active.single.isTrashed, isFalse);
      expect(active.single.deletedAt, isNull);
    });

    test('kalıcı silme geri alınamaz; çöp boşaltma yalnız çöptekini siler',
        () async {
      await repo.upsert(uid, make('1', 'A'));
      await repo.upsert(uid, make('2', 'B'));
      await repo.moveToTrash('1');

      await repo.deletePermanently('1');
      expect(await repo.getById('1'), isNull);
      expect(await repo.watchTrashed(uid).first, isEmpty);

      // 2 aktif kalır; emptyTrash ona dokunmaz.
      await repo.moveToTrash('2');
      await repo.upsert(uid, make('3', 'C'));
      await repo.emptyTrash(uid);
      expect(await repo.getById('2'), isNull); // çöpteydi → silindi
      expect((await repo.getById('3'))?.title, 'C'); // aktifti → durur
    });

    test('kayıtlar owner_uid ile ölçekli — başka hesabınki görünmez', () async {
      await repo.upsert('user_1', make('1', 'Benim'));
      await repo.upsert('user_2', make('2', 'Başkası'));
      final mine = await repo.watchActive('user_1').first;
      expect(mine.map((e) => e.title), ['Benim']);
    });
  });

  // Uçtan uca UI: router sırası + provider bağlantıları + ekran akışı
  // (birim testlerin görmediği yerler). Oturum açık kullanıcı gerekir.
  group('Takip Merkezi ekranı — uçtan uca akış', () {
    setUpAll(() => initializeDateFormatting('tr_TR', null));
    setUp(() => SharedPreferences.setMockInitialValues({}));

    // Oturumlu uygulamayı pompalar. Kayıt (mock) Future.delayed'lı olduğundan
    // sahte saatin ilerlemesi için runAsync içinde çağrılır (bkz. Oturum 44).
    Future<ProviderContainer> pumpLoggedIn(WidgetTester tester) async {
      final container = ProviderContainer(overrides: mockBackendOverrides());
      addTearDown(container.dispose);
      await tester.runAsync(() => container.read(authRepositoryProvider).register(
            displayName: 'Takip Test',
            email: 'takip@ornek.com',
            password: 'sifre123',
          ));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const UstaCepteApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(currentUserProvider), isNotNull);
      return container;
    }

    testWidgets('oluştur → listede görün → tamamla → çöpe at → geri al',
        (tester) async {
      final container = await pumpLoggedIn(tester);

      // Takip Merkezi'ni aç (Profil'deki satır bu rotayı iter).
      container.read(routerProvider).push(RoutePaths.tracking);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TrackingCenterScreen), findsOneWidget);
      // Hiç kayıt yokken ilk-kayıt daveti görünür.
      expect(find.text('İlk takibini oluştur'), findsOneWidget);

      // "Yeni" FAB → düzenleme ekranı → başlık gir → Kaydet.
      await tester.tap(find.text('Yeni'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // İlk alan Başlık (Not ondan sonra; etiket alanı henüz gizli). Finder'ı
      // düzenleme ekranına daral: yığındaki alttaki rotaların (keşif arama
      // kutusu vb.) TextField'larını yakalamasın.
      await tester.enterText(
        find
            .descendant(
                of: find.byType(TrackEditScreen), matching: find.byType(TextField))
            .first,
        'Kombi bakımı',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Listeye döndük ve kayıt görünür (başlığı merkez ekranına daralt —
      // pop animasyonu bitmeden düzenleme alanı da metni taşıyabilir).
      expect(find.byType(TrackingCenterScreen), findsOneWidget);
      expect(
        find.descendant(
            of: find.byType(TrackingCenterScreen),
            matching: find.text('Kombi bakımı')),
        findsOneWidget,
      );

      // Kart gerçekten çizildi (liste + provider bağlı).
      expect(find.byType(TrackCard), findsOneWidget);

      final uid = container.read(currentUserProvider)!.uid;
      final repo = container.read(trackingRepositoryProvider);

      // Tamamlama/çöp/geri-al'ı controller üstünden doğrula (kartın dairesel
      // dokunuş hedefi küçük; iş mantığı burada test edilir, UI yukarıda).
      final ctrl = container.read(trackingControllerProvider);
      final current = (await repo.watchActive(uid).first).single;
      await ctrl.toggleDone(current);
      expect((await repo.watchActive(uid).first).single.isDone, isTrue);

      // Çöpe at, sonra geri al — repo durumu doğrular (UI toast'ı showUndo).
      await ctrl.moveToTrash(current.id);
      expect(await repo.watchActive(uid).first, isEmpty);
      expect((await repo.watchTrashed(uid).first).single.id, current.id);
      await ctrl.restore(current.id);
      expect((await repo.watchActive(uid).first).single.id, current.id);
      expect(await repo.watchTrashed(uid).first, isEmpty);
    });

    testWidgets('karta dokununca detay açılır; çöp kutusu rotası bağlı',
        (tester) async {
      final container = await pumpLoggedIn(tester);
      final now = DateTime.now();
      await container.read(trackingControllerProvider).save(TrackItem(
            id: 'd1',
            title: 'Randevu: diş hekimi',
            note: 'Saat 15:00',
            createdAt: now,
            updatedAt: now,
          ));

      // Listeyi aç → kart görünür → karta dokun → detay ekranı.
      container.read(routerProvider).push(RoutePaths.tracking);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Randevu: diş hekimi'), findsOneWidget);

      await tester.tap(find.byType(TrackCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TrackDetailScreen), findsOneWidget);
      // Notu detay ekranına daralt (aynı metin arkadaki kartta da var).
      expect(
        find.descendant(
            of: find.byType(TrackDetailScreen),
            matching: find.text('Saat 15:00')),
        findsOneWidget,
      );

      // Çöp Kutusu rotası da bağlı (router sırası regresyonu: /tracking/trash
      // /tracking/:id'den ÖNCE eşleşmeli).
      container.read(routerProvider).push(RoutePaths.trackingTrash);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TrackingTrashScreen), findsOneWidget);
    });

    testWidgets('Faz 3: kişi + konum girilir, kaydedilir ve detayda görünür',
        (tester) async {
      final container = await pumpLoggedIn(tester);
      container.read(routerProvider).push(RoutePaths.trackingNew);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(
        find
            .descendant(
                of: find.byType(TrackEditScreen),
                matching: find.byType(TextField))
            .first,
        'Su tesisatı',
      );

      // "İlgili kişi" ve "Konum" alanlarını aç (Ekle çipleri).
      await tester.tap(find.text('İlgili kişi'));
      await tester.pump();
      await tester.tap(find.text('Konum'));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(
          find.widgetWithText(TextField, 'Ad'), 'Ali Usta');
      await tester.enterText(
          find.widgetWithText(TextField, 'Telefon (isteğe bağlı)'),
          '+905551112233');
      await tester.enterText(
          find.widgetWithText(TextField, 'Adres / yer etiketi'), 'Kadıköy');

      await tester.tap(find.text('Kaydet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Kayıt oluştu → detayına git → kişi + konum görünür.
      final uid = container.read(currentUserProvider)!.uid;
      final saved =
          (await container.read(trackingRepositoryProvider).watchActive(uid).first)
              .single;
      expect(saved.person?.name, 'Ali Usta');
      expect(saved.person?.phone, '+905551112233');
      expect(saved.location?.label, 'Kadıköy');

      container.read(routerProvider).push(RoutePaths.trackDetail(saved.id));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final detail = find.byType(TrackDetailScreen);
      expect(
          find.descendant(of: detail, matching: find.text('Ali Usta')),
          findsOneWidget);
      expect(find.descendant(of: detail, matching: find.text('Kadıköy')),
          findsOneWidget);
    });
  });

  // Faz 2: hatırlatma + tekrarlama motoru.
  group('TrackRecurrence.nextAfter — tekrar tarihi hesabı', () {
    test('none → null', () {
      expect(TrackRecurrence.none.nextAfter(DateTime(2026, 1, 1)), isNull);
    });

    test('günlük +1 gün, haftalık +7 gün (saat korunur)', () {
      expect(TrackRecurrence.daily.nextAfter(DateTime(2026, 1, 1, 9, 30)),
          DateTime(2026, 1, 2, 9, 30));
      expect(TrackRecurrence.weekly.nextAfter(DateTime(2026, 1, 1, 9, 30)),
          DateTime(2026, 1, 8, 9, 30));
    });

    test('aylık — ay-sonu taşması ayın son gününe kırpılır', () {
      // 31 Ocak + 1 ay → 28 Şubat 2026 (2026 artık yıl değil).
      expect(TrackRecurrence.monthly.nextAfter(DateTime(2026, 1, 31, 8, 0)),
          DateTime(2026, 2, 28, 8, 0));
      // 31 Ocak 2028 + 1 ay → 29 Şubat 2028 (artık yıl).
      expect(TrackRecurrence.monthly.nextAfter(DateTime(2028, 1, 31)),
          DateTime(2028, 2, 29));
    });

    test('yıllık — 29 Şubat + 1 yıl → 28 Şubat (artık olmayan yıl)', () {
      expect(TrackRecurrence.yearly.nextAfter(DateTime(2028, 2, 29)),
          DateTime(2029, 2, 28));
      expect(TrackRecurrence.yearly.nextAfter(DateTime(2026, 3, 15, 10, 0)),
          DateTime(2027, 3, 15, 10, 0));
    });
  });

  group('TrackingController — hatırlatma senkronu + tekrarlama', () {
    late ProviderContainer container;
    late _FakeNotif notif;

    Future<String> setUpLoggedIn() async {
      notif = _FakeNotif();
      container = ProviderContainer(overrides: [
        ...mockBackendOverrides(),
        // Mükerrer override'da SON kazanır → sahte servis mock'un Noop'undan
        // SONRA gelmeli (çağrıları kaydeder).
        trackNotificationServiceProvider.overrideWithValue(notif),
      ]);
      // Oturum sağlayıcısı bir Stream'den türer; dinlenmezse yayın yapmaz →
      // controller._uid null kalır ve save erken döner. Aktive et + kaydın
      // akışa yansımasını bekle.
      container.listen(currentUserProvider, (_, _) {});
      final user = await container.read(authRepositoryProvider).register(
            displayName: 'N',
            email: 'n@o.com',
            password: 'sifre123',
          );
      for (var i = 0;
          i < 200 && container.read(currentUserProvider)?.uid != user.uid;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return user.uid;
    }

    tearDown(() => container.dispose());

    test('kaydetme hatırlatmayı senkronlar; çöp/kalıcı silme iptal eder',
        () async {
      await setUpLoggedIn();
      final ctrl = container.read(trackingControllerProvider);
      final now = DateTime.now();
      final item = TrackItem(
        id: 'r1',
        title: 'Hatırlat',
        reminderAt: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );
      await ctrl.save(item);
      expect(notif.synced.map((e) => e.id), contains('r1'));

      await ctrl.moveToTrash('r1');
      expect(notif.cancelled, contains('r1'));

      notif.cancelled.clear();
      await ctrl.restore('r1');
      expect(notif.synced.last.id, 'r1'); // geri alınca yeniden senkron

      await ctrl.deletePermanently('r1');
      expect(notif.cancelled, contains('r1'));
    });

    test('tekrarlı takip tamamlanınca AKTİF kalır ve tarih ileri kayar',
        () async {
      await setUpLoggedIn();
      final ctrl = container.read(trackingControllerProvider);
      final reminder = DateTime(2026, 1, 10, 9, 0);
      final item = TrackItem(
        id: 'rec1',
        title: 'Kombi bakımı',
        reminderAt: reminder,
        recurrence: TrackRecurrence.monthly,
        createdAt: reminder,
        updatedAt: reminder,
      );
      await ctrl.save(item);

      await ctrl.toggleDone(item);
      final after = await container.read(trackingRepositoryProvider).getById('rec1');
      expect(after!.isDone, isFalse); // tekrarlıda "tamamlandı"ya düşmez
      // reminderAt bir sonraki (gelecekteki) tarihe kaydı — geçmiş değil.
      expect(after.reminderAt!.isAfter(DateTime.now()), isTrue);
      expect(after.reminderAt!.day, 10); // aynı gün-of-month korunur
    });

    test('tekrarsız takip tamamlanınca "tamamlandı" olur', () async {
      await setUpLoggedIn();
      final ctrl = container.read(trackingControllerProvider);
      final now = DateTime.now();
      final item = TrackItem(
        id: 'p1',
        title: 'Tek seferlik',
        createdAt: now,
        updatedAt: now,
      );
      await ctrl.save(item);
      await ctrl.toggleDone(item);
      final after = await container.read(trackingRepositoryProvider).getById('p1');
      expect(after!.isDone, isTrue);
    });
  });

  // Faz 3: kalıcı silme/çöp boşaltma ek dosyalarını da temizler.
  group('TrackingController — ek dosya temizliği', () {
    late ProviderContainer container;
    late _RecordingStore store;

    Future<void> setUp2() async {
      store = _RecordingStore();
      container = ProviderContainer(overrides: [
        ...mockBackendOverrides(),
        attachmentStoreProvider.overrideWithValue(store),
      ]);
      container.listen(currentUserProvider, (_, _) {});
      final user = await container.read(authRepositoryProvider).register(
            displayName: 'N', email: 'a@o.com', password: 'sifre123');
      for (var i = 0;
          i < 200 && container.read(currentUserProvider)?.uid != user.uid;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    tearDown(() => container.dispose());

    TrackItem withAudio(String id) {
      final now = DateTime.now();
      return TrackItem(
        id: id,
        title: 'Ekli',
        attachments: [
          TrackAttachment(
              type: TrackAttachmentType.audio,
              path: '/tmp/$id.m4a',
              durationMs: 3000),
        ],
        createdAt: now,
        updatedAt: now,
      );
    }

    test('kalıcı silme ek dosyalarını da siler', () async {
      await setUp2();
      final ctrl = container.read(trackingControllerProvider);
      await ctrl.save(withAudio('a1'));
      await ctrl.deletePermanently('a1');
      expect(store.deleted, contains('/tmp/a1.m4a'));
    });

    test('çöp boşaltma çöptekilerin ek dosyalarını siler', () async {
      await setUp2();
      final ctrl = container.read(trackingControllerProvider);
      await ctrl.save(withAudio('a2'));
      await ctrl.moveToTrash('a2');
      await ctrl.emptyTrash();
      expect(store.deleted, contains('/tmp/a2.m4a'));
    });
  });
}

/// Ek dosya silme çağrılarını kaydeden sahte depo (Faz 3 temizlik testleri).
class _RecordingStore implements AttachmentStore {
  final List<String> deleted = [];

  @override
  Future<void> deleteFile(TrackAttachment att) async => deleted.add(att.path);

  @override
  Future<void> deleteFiles(Iterable<TrackAttachment> atts) async {
    for (final a in atts) {
      deleted.add(a.path);
    }
  }

  @override
  Future<TrackAttachment> save({
    required String sourcePath,
    required TrackAttachmentType type,
    String? displayName,
    int? durationMs,
    bool move = false,
  }) =>
      throw UnimplementedError();
}

/// Bildirim çağrılarını kaydeden sahte servis (Faz 2 controller testleri).
class _FakeNotif implements TrackNotificationService {
  final List<TrackItem> synced = [];
  final List<String> cancelled = [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> sync(TrackItem item) async => synced.add(item);

  @override
  Future<void> cancel(String trackId) async => cancelled.add(trackId);
}
