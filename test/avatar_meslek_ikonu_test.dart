import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/theme/app_theme.dart';
import 'package:sepette_hizmet/core/widgets/app_image.dart';
import 'package:sepette_hizmet/core/widgets/job_thumb.dart';

import 'helpers/mock_backend.dart';

/// Fotoğrafı olmayan kullanıcılarda avatar yedeği.
///
/// Mock veride 900 ustanın neredeyse hiçbirinde fotoğraf yok; hepsi aynı
/// baş harf rozetiyle çizilince liste tek tip görünüyordu. Meslek kodu
/// verilirse artık mesleğin ikonu ve rengi çizilir — kartlar ayırt edilebilir.
/// Kod verilmezse ESKİ davranış (baş harf) korunur.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(ProviderScope(
      overrides: mockBackendOverrides(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      ),
    ));
    await tester.pump();
  }

  testWidgets('meslek kodu verilince MESLEK İKONU çizilir', (tester) async {
    await pump(
      tester,
      const AppAvatar(name: 'Kerem Alptekin', professionCode: 'painter'),
    );

    final beklenen = jobVisualFor('painter').icon;
    expect(find.byIcon(beklenen), findsOneWidget);
    expect(find.text('K'), findsNothing,
        reason: 'Meslek ikonu varken baş harf çizilmemeli.');
  });

  testWidgets('farklı meslek → farklı ikon', (tester) async {
    await pump(
      tester,
      const AppAvatar(name: 'Okan Beyazıt', professionCode: 'plumber'),
    );

    expect(find.byIcon(jobVisualFor('plumber').icon), findsOneWidget);
    expect(find.byIcon(jobVisualFor('painter').icon), findsNothing);
  });

  testWidgets('meslek kodu YOKSA baş harf çizilir (geri uyum)',
      (tester) async {
    await pump(tester, const AppAvatar(name: 'Zeynep Uçar'));

    expect(find.text('Z'), findsOneWidget);
  });

  testWidgets('boş meslek kodu baş harfe düşer', (tester) async {
    await pump(
      tester,
      const AppAvatar(name: 'Ayşe Nur Tunç', professionCode: '   '),
    );

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('adsız kullanıcı "?" gösterir', (tester) async {
    await pump(tester, const AppAvatar(name: '   '));

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('bilinmeyen meslek kodu yine de ikon verir (çökmez)',
      (tester) async {
    await pump(
      tester,
      const AppAvatar(name: 'Test', professionCode: 'boyle_bir_meslek_yok'),
    );

    // jobVisualFor tanımadığı kodda genel handyman ikonuna düşer.
    expect(find.byIcon(jobVisualFor('boyle_bir_meslek_yok').icon),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
