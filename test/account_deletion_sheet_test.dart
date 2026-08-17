import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/theme/app_theme.dart';
import 'package:sepette_hizmet/features/profile/presentation/widgets/account_deletion_sheet.dart';

import 'helpers/mock_backend.dart';

void main() {
  testWidgets('AccountDeletionSheet güvenlik doğrulaması ve kaza önleme kalkanı',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mockBackendOverrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AccountDeletionSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1) Başlık ve uyarılar görüntülenmeli
    expect(find.text('Hesabı Kalıcı Olarak Sil'), findsOneWidget);
    expect(find.text('Bu işlem geri alınamaz'), findsOneWidget);
    expect(find.text('Silinecek ve Temizlenecek Veriler:'), findsOneWidget);
    expect(find.text('Anonimleştirilecek Kayıtlar (Hukuki & Güvenlik):'), findsOneWidget);

    // 2) Başlangıçta "Hesabımı Sil" butonu pasif olmalı
    final deleteButtonFinder = find.widgetWithText(FilledButton, 'Hesabımı Sil');
    expect(deleteButtonFinder, findsOneWidget);
    FilledButton button = tester.widget(deleteButtonFinder);
    expect(button.onPressed, isNull);

    // 3) Onay kutusu işaretlenince "Hesabımı Sil" butonu aktif olmalı
    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    button = tester.widget(deleteButtonFinder);
    expect(button.onPressed, isNotNull);

    // 4) Onay kutusu kaldırılınca buton tekrar pasif olmalı
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    button = tester.widget(deleteButtonFinder);
    expect(button.onPressed, isNull);
  });
}
