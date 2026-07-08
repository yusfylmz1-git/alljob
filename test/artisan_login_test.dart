import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:usta_cepte/app.dart';
import 'package:usta_cepte/features/artisan/presentation/artisan_home_screen.dart';
import 'package:usta_cepte/features/auth/application/auth_controller.dart';
import 'package:usta_cepte/features/customer/presentation/customer_dashboard_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  testWidgets('misafir açılışta keşfi görür; usta girişi panele götürür',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const UstaCepteApp(),
      ),
    );

    // Splash çözülür → misafir keşif ekranı.
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

    // Router yönlendirir + profil taslağı yüklenir (200ms) → usta ana ekranı.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ArtisanHomeScreen), findsOneWidget);
  });
}
