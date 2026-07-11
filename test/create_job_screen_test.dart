import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/core/theme/app_theme.dart';
import 'package:usta_cepte/data/models/app_user.dart';
import 'package:usta_cepte/features/auth/application/auth_controller.dart';
import 'package:usta_cepte/features/jobs/presentation/create_job_screen.dart';

import 'helpers/mock_backend.dart';

/// "Yeni İlan" ekranı smoke testi (regresyon: alt sabit yayınla barındaki
/// Align tabanlı ResponsiveCenter dikeyde tüm ekranı kaplıyor, gövdedeki form
/// 0 yükseklikte kalıyordu — kullanıcı "sayfa açılmıyor, yalnız buton
/// görünüyor" bildirdi). Ekran telefon boyutunda exception'sız açılmalı,
/// 4 bölüm kartı da (gerekirse kaydırarak) erişilebilir olmalı.
void main() {
  final testUser = AppUser(
    uid: 'customer_test',
    displayName: 'Test Müşteri',
    email: 'musteri@test.com',
    createdAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpScreen(WidgetTester tester, {required bool dark}) async {
    // Tipik telefon: 360x800 mantıksal piksel.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...mockBackendOverrides(),
        currentUserProvider.overrideWithValue(testUser),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const CreateJobScreen(),
      ),
    ));
    // pumpAndSettle KULLANMA: meslek/il dropdown'ları yüklenirken dönen
    // LinearProgressIndicator sonsuz animasyondur, settle zaman aşımına düşer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final dark in [false, true]) {
    testWidgets(
        'yeni ilan sayfası ${dark ? "koyu" : "açık"} temada eksiksiz açılır',
        (tester) async {
      await pumpScreen(tester, dark: dark);

      // Gövde build'i exception atmamalı (overflow dahil).
      expect(tester.takeException(), isNull);

      // İlk kartlar ve alt sabit buton doğrudan görünür.
      expect(find.text('İşi Tanımlayın'), findsOneWidget);
      expect(find.text('Konum'), findsOneWidget);
      expect(find.text('İlanı Yayınla'), findsOneWidget);

      // Son kart ekran dışında olabilir — kaydırarak eriş (gövde 0
      // yükseklikte kalsaydı kaydırma da onu asla getiremezdi).
      // İki ListView var (form + yatay foto şeridi) — dikey formu hedefle.
      await tester.dragUntilVisible(
        find.text('Yayın Ayarları'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      expect(find.text('Yayın Ayarları'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
