import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:usta_cepte/app.dart';
import 'package:usta_cepte/core/router/app_router.dart';
import 'package:usta_cepte/core/router/route_paths.dart';
import 'package:usta_cepte/features/auth/application/auth_controller.dart';
import 'package:usta_cepte/features/customer/presentation/customer_dashboard_screen.dart';
import 'package:usta_cepte/features/profile/presentation/profile_screen.dart';

import 'helpers/mock_backend.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  testWidgets('misafir keşfi görür; usta girişi + panel ana ekranı çalışır',
      (tester) async {
    // Uygulama Firebase backend'iyle derlenir; testte tüm repo'ları mock'a çevir.
    final container = ProviderContainer(overrides: mockBackendOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const UstaCepteApp(),
      ),
    );

    // Splash çözülür → misafir keşif ekranı (misafir-önce akış, Oturum 17).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CustomerDashboardScreen), findsOneWidget);

    // Usta olarak giriş yap. login() içindeki gecikmeleri pump ile ilerlet
    // (await etmeden — aksi halde test saatinin zamanlayıcısı beklenir).
    final loginFuture = container.read(authControllerProvider.notifier).login(
          email: 'usta@test.com',
          password: '123456',
        );
    await tester.pump(); // eylemi başlat
    await tester.pump(const Duration(seconds: 1)); // 600ms auth gecikmesi
    final ok = await loginFuture;
    expect(ok, isTrue);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Misafir-önce akış: giriş, keşiften otomatik profile ATMAZ. Usta eski
    // /panel adresine gider; router birleşik profile yönlendirir ve tek
    // birleşik profil sayfası (usta bölümleriyle) render olur.
    container.read(routerProvider).go(RoutePaths.panel);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('DÜKKÂNIM'), findsOneWidget); // usta modu bölümü
  });
}
