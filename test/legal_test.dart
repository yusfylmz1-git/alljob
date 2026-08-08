import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sepette_hizmet/app.dart';
import 'package:sepette_hizmet/core/router/app_router.dart';
import 'package:sepette_hizmet/core/router/route_paths.dart';
import 'package:sepette_hizmet/features/auth/presentation/login_screen.dart';
import 'package:sepette_hizmet/features/legal/legal_docs.dart';
import 'package:sepette_hizmet/features/legal/presentation/legal_screen.dart';

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

  testWidgets('kayıt rotası Google girişe yönlenir (register → login)',
      (tester) async {
    final container = await pumpApp(tester);
    addTearDown(container.dispose);

    container.read(routerProvider).go(RoutePaths.register);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LoginScreen), findsOneWidget);
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
