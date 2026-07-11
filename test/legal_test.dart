import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usta_cepte/app.dart';
import 'package:usta_cepte/core/router/app_router.dart';
import 'package:usta_cepte/core/router/route_paths.dart';
import 'package:usta_cepte/features/auth/application/auth_controller.dart';
import 'package:usta_cepte/features/auth/presentation/register_screen.dart';
import 'package:usta_cepte/features/customer/presentation/customer_dashboard_screen.dart';
import 'package:usta_cepte/features/legal/legal_docs.dart';
import 'package:usta_cepte/features/legal/presentation/legal_screen.dart';

import 'helpers/mock_backend.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(overrides: mockBackendOverrides());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const UstaCepteApp(),
      ),
    );
    // Splash çözülsün.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  testWidgets(
      'kayıt: yasal onay işaretlenmeden kayıt olunamaz, işaretlenince olunur',
      (tester) async {
    final container = await pumpApp(tester);
    addTearDown(container.dispose);

    container.read(routerProvider).go(RoutePaths.register);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RegisterScreen), findsOneWidget);

    // Formu doldur (ad, e-posta, şifre, şifre tekrarı).
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test Kişi');
    await tester.enterText(fields.at(1), 'yeni@ornek.com');
    await tester.enterText(fields.at(2), 'sifre123');
    await tester.enterText(fields.at(3), 'sifre123');

    // Onay kutusu İŞARETLENMEDEN gönder → inline hata, kayıt olmaz.
    await tester.ensureVisible(find.text('Kayıt Ol'));
    await tester.tap(find.text('Kayıt Ol'));
    await tester.pump();
    expect(find.text('Kayıt olmak için koşulları kabul etmelisiniz.'),
        findsOneWidget);
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(container.read(currentUserProvider), isNull);

    // Kutucuğu işaretle → kayıt tamamlanır, ana ekrana düşer.
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Kayıt Ol'));
    await tester.tap(find.text('Kayıt Ol'));
    await tester.pump();
    // Kayıt async tamamlanır → go(home) bildirimi SONRAKİ karede işlenir;
    // geçiş animasyonu için de ek kareler gerekir.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(container.read(currentUserProvider)?.email, 'yeni@ornek.com');
    expect(find.byType(CustomerDashboardScreen), findsOneWidget);

    // Başarı toast'ının zamanlayıcısı sönsün (bekleyen timer kalmasın).
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('yasal metinler misafire açık: hub + metin sayfası açılır',
      (tester) async {
    final container = await pumpApp(tester);
    addTearDown(container.dispose);

    // Hub: üç metin de listelenir (misafir — oturum yok).
    container.read(routerProvider).go(RoutePaths.legal);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LegalHubScreen), findsOneWidget);
    for (final doc in kLegalDocs) {
      expect(find.text(doc.title), findsOneWidget);
    }

    // Tek metin sayfası: başlık + bölüm başlığı görünür.
    container.read(routerProvider).go(RoutePaths.legalDoc(legalPrivacy.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LegalDocScreen), findsOneWidget);
    expect(find.text('1. Topladığımız Veriler'), findsOneWidget);
  });
}
