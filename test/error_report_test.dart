import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usta_cepte/core/widgets/status_views.dart';
import 'package:usta_cepte/features/help/presentation/help_screen.dart';

import 'helpers/mock_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ErrorView — Sorunu bildir', () {
    testWidgets('kapsam yokken düğme görünmez (admin/test ağaçları)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ErrorView(message: 'Liste yüklenemedi.')),
      ));
      expect(find.text('Sorunu bildir'), findsNothing);
    });

    testWidgets('kapsam varken düğme görünür; dokununca özet iletilir',
        (tester) async {
      String? reported;
      await tester.pumpWidget(MaterialApp(
        home: ErrorReportScope(
          onReport: (_, summary) => reported = summary,
          child: const Scaffold(
            body: ErrorView(
              title: 'Bir sorun oluştu',
              message: 'Liste yüklenemedi.',
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Sorunu bildir'));
      expect(reported, 'Bir sorun oluştu — Liste yüklenemedi.');
    });
  });

  group('HelpScreen — destek formu ön dolgu', () {
    testWidgets('konu/detay parametreleri form alanlarına yazılır',
        (tester) async {
      final container = ProviderContainer(overrides: mockBackendOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HelpScreen(
              initialSubject: 'Uygulama hata bildirimi',
              initialBody: 'Karşılaşılan durum: test',
            ),
          ),
        ),
      );
      await tester.pump();
      // Ön dolgu varsa sayfa forma kayar (400 ms animasyon).
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.widgetWithText(TextField, 'Uygulama hata bildirimi'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Karşılaşılan durum: test'),
        findsOneWidget,
      );
    });
  });
}
