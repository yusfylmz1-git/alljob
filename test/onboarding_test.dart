import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usta_cepte/app.dart';
import 'package:usta_cepte/features/customer/presentation/customer_dashboard_screen.dart';
import 'package:usta_cepte/features/onboarding/onboarding_state.dart';
import 'package:usta_cepte/features/onboarding/presentation/onboarding_screen.dart';

import 'helpers/mock_backend.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));
  // Testte gerçek plugin yok; bellek içi depo kullan.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ilk açılışta onboarding görünür; Atla keşfete götürür',
      (tester) async {
    final container = ProviderContainer(overrides: [
      ...mockBackendOverrides(),
      // İlk açılış simülasyonu: onboarding henüz görülmedi.
      onboardingSeenProvider.overrideWith((ref) => false),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const UstaCepteApp(),
      ),
    );

    // Splash çözülür → misafir + görülmemiş onboarding → tanıtım akışı.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Aradığın usta, bölgende'), findsOneWidget);

    // Atla → görüldü işaretlenir ve keşfete gidilir.
    await tester.tap(find.text('Atla'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CustomerDashboardScreen), findsOneWidget);
    expect(container.read(onboardingSeenProvider), isTrue);
  });

  testWidgets('onboarding görüldüyse splash doğrudan keşfete gider',
      (tester) async {
    final container = ProviderContainer(overrides: mockBackendOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const UstaCepteApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(CustomerDashboardScreen), findsOneWidget);
  });
}
