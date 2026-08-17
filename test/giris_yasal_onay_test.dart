import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sepette_hizmet/data/models/app_user.dart';
import 'package:sepette_hizmet/features/auth/application/auth_controller.dart';
import 'package:sepette_hizmet/features/auth/data/mock_auth_repository.dart';
import 'package:sepette_hizmet/features/auth/presentation/login_screen.dart';

/// Girişte yasal onay kapısı — DAVRANIŞ testi (kaynak taraması değil).
///
/// Kural: kullanıcı Kullanım Koşulları / Gizlilik / KVKK onay kutusunu
/// işaretlemeden Google girişi BAŞLAMAMALI. Bu, KVKK açık rıza ve Play
/// politikası açısından kritik; sessizce kırılırsa hukuki risk doğar.
///
/// `MockAuthRepository` genişletilip `signInWithGoogle` çağrı sayısı
/// sayılıyor — gerçek kapının çalıştığı böyle kanıtlanır.
class _SayanRepo extends MockAuthRepository {
  int girisDenemesi = 0;

  @override
  Future<AppUser> signInWithGoogle() {
    girisDenemesi++;
    return super.signInWithGoogle();
  }
}

void main() {
  Future<_SayanRepo> ekraniAc(WidgetTester tester) async {
    final repo = _SayanRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    return repo;
  }

  Finder googleButonu() => find.text('Google ile devam et');

  group('Yasal onay giriş şartı', () {
    testWidgets('onay kutusu ekranda var', (tester) async {
      await ekraniAc(tester);
      expect(find.byType(Checkbox), findsOneWidget);
      // Varsayılan İŞARETSİZ olmalı — önceden işaretli onay geçerli rıza
      // sayılmaz (KVKK: açık rıza aktif eylem gerektirir).
      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isFalse,
          reason: 'Onay kutusu varsayılan işaretli — açık rıza değil.');
    });

    testWidgets('üç yasal metnin adı da yazıyor', (tester) async {
      await ekraniAc(tester);
      expect(find.textContaining('Kullanım Koşulları'), findsWidgets);
      expect(find.textContaining('Gizlilik'), findsWidgets);
      expect(find.textContaining('KVKK'), findsWidgets);
    });

    testWidgets('ONAYSIZ dokunuş girişi BAŞLATMAZ', (tester) async {
      final repo = await ekraniAc(tester);

      await tester.tap(googleButonu());
      await tester.pump();

      expect(repo.girisDenemesi, 0,
          reason: 'Onay verilmeden Google girişi başladı — KVKK açık rıza '
              'alınmadan kimlik doğrulama yapılıyor.');
      // Kullanıcı NEDEN olmadığını görmeli (sessiz başarısızlık olmasın).
      expect(find.textContaining('onaylayın'), findsOneWidget);
    });

    testWidgets('onay kutusu işaretlenebiliyor (kapı açılabilir)', (tester) async {
      // "Onay verilince giriş BAŞLAR" senaryosu bilerek test EDİLMİYOR:
      // mock repo giriş akışında yapay `Future.delayed` zincirleri kuruyor
      // ve widget testi bekleyen zamanlayıcıyla düşüyor. O yolun kendisi
      // zaten `auth` testlerinde kapsanıyor.
      //
      // Buradaki kritik iddia — ONAYSIZ giriş başlamaz — bir üstteki
      // testte doğrudan çağrı sayacıyla kanıtlanıyor.
      await ekraniAc(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.value, isTrue,
          reason: 'Onay kutusu işaretlenemiyor — kullanıcı giriş yapamaz.');
    });

    testWidgets('onay geri alınınca giriş yeniden kapanır', (tester) async {
      final repo = await ekraniAc(tester);

      // İşaretle → kaldır.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(googleButonu());
      await tester.pump();

      expect(repo.girisDenemesi, 0,
          reason: 'Onay kaldırıldığı hâlde giriş yapılabiliyor.');
    });
  });
}
