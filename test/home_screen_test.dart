import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sepette_hizmet/core/theme/app_theme.dart';
import 'package:sepette_hizmet/features/home/presentation/home_screen.dart';

import 'helpers/mock_backend.dart';

/// Ana Sayfa (platform dashboard) smoke testi: misafir olarak exception'sız
/// açılır; karşılama + hızlı erişim bölümleri görünür.
/// (İstatistik/duyuru bölümleri veri yoksa gizlenir — burada beklenmez.)
///
/// NOT: "Usta Araçları" bölümü, Usta Çantası (toolkit) üründen kaldırılınca
/// (2026-08-07) silindi — içindeki dört kısayolun ikisi toolkit'e, ikisi
/// Ajanda'ya gidiyordu; toolkit gidince bölümün anlamı kalmadı.
void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: mockBackendOverrides(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('misafir Ana Sayfa açılır; hızlı erişim görünür',
      (tester) async {
    await pump(tester);

    // Sade karşılama başlığı.
    expect(find.text('Bugün ne yapalım?'), findsOneWidget);
    // Misafir giriş şeridi.
    expect(find.text('Giriş yap, sana özel öneriler'), findsOneWidget);
    // 3 ana aksiyon (misafir/müşteri: Usta Bul). Eleman kaldırıldı.
    expect(find.text('Usta Bul'), findsOneWidget);
    expect(find.text('İş İlanı Ver'), findsOneWidget);
    expect(find.text('Mağaza İçin Ürün Talebi Oluştur'), findsOneWidget);
    expect(find.text('Eleman'), findsNothing);

    // Toolkit kaldırıldı: araç bölümü ve kısayolları HİÇ görünmemeli.
    expect(find.text('Usta Araçları'), findsNothing);
    expect(find.text('Ölç & Hesapla'), findsNothing);
    expect(find.text('Usta Çantası'), findsNothing);
  });
}
