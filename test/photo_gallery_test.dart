import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/core/widgets/photo_gallery_page.dart';

void main() {
  String read(String p) => File(p).readAsStringSync();

  group('Kaynak sözleşmesi', () {
    test('kendi profilindeki iş fotoğrafı galeriyi açar', () {
      final s = read('lib/features/profile/presentation/profile_screen.dart');
      expect(s.contains('PhotoGalleryPage.open'), isTrue,
          reason: 'Profil şeridindeki iş fotoğrafı önizleme açmalı.');
    });

    test('usta vitrinindeki iş fotoğrafı galeriyi açar', () {
      final s = read(
          'lib/features/customer/presentation/artisan_profile_screen.dart');
      expect(s.contains('PhotoGalleryPage.open'), isTrue);
      // Sertifika hâlâ ayrı diyalog; iş fotoğrafı _showCertificate'e gitmemeli.
      final grid = s.substring(
        s.indexOf('class _WorkPhotoGrid'),
        s.indexOf('class _ScheduleBlock'),
      );
      expect(grid.contains('_showCertificate'), isFalse,
          reason: 'İş fotoğrafı tekil diyalog değil, kaydırmalı galeri olmalı.');
    });
  });

  group('PhotoGalleryPage', () {
    Future<void> ac(
      WidgetTester tester, {
      List<String> handles = const ['a', 'b', 'c'],
      int initialIndex = 0,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => PhotoGalleryPage.open(
                    context,
                    handles: handles,
                    initialIndex: initialIndex,
                  ),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    testWidgets('çarpı profil/önceki sayfaya döner', (tester) async {
      await ac(tester);
      expect(find.byType(PhotoGalleryPage), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoGalleryPage), findsNothing);
      expect(find.text('aç'), findsOneWidget);
    });

    testWidgets('geri tuşu da kapatır', (tester) async {
      await ac(tester);
      expect(find.byType(PhotoGalleryPage), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.byType(PhotoGalleryPage), findsNothing);
      expect(find.text('aç'), findsOneWidget);
    });

    testWidgets('sağa-sola kaydırınca sayaç değişir', (tester) async {
      await ac(tester, initialIndex: 0);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('boş listede sayfa açılmaz', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => PhotoGalleryPage.open(
                    context,
                    handles: const [],
                  ),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoGalleryPage), findsNothing);
    });
  });
}
