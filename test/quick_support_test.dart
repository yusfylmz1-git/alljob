import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sepette_hizmet/core/theme/app_theme.dart';
import 'package:sepette_hizmet/data/models/job.dart';
import 'package:sepette_hizmet/features/home/presentation/widgets/home_quick_support.dart';
import 'package:sepette_hizmet/features/jobs/data/job_providers.dart';

import 'helpers/mock_backend.dart';

/// "Hemen Lazım" ana sayfa şeridi (PRD: kısa işlerin vitrini).
void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  Job job({
    required String id,
    required String title,
    String category = kQuickSupportCategory,
    String customerName = 'Ayşe K.',
    String district = 'Osmangazi',
  }) =>
      Job(
        jobId: id,
        customerId: 'cust_$id',
        customerName: customerName,
        title: title,
        description: 'Açıklama',
        category: category,
        province: 'Bursa',
        district: district,
        photos: const [],
        priceType: JobPriceType.fixed,
        status: JobStatus.open,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 3)),
      );

  Future<void> pump(WidgetTester tester, List<Job> openJobs) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...mockBackendOverrides(),
        openJobsProvider.overrideWith((ref) => Stream.value(openJobs)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: HomeQuickSupport()),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Hemen Lazım ilanı yoksa bölüm TAMAMEN gizlenir',
      (tester) async {
    // Yalnız klasik ilan var → başlık bile görünmemeli (boş başlık bırakmaz).
    await pump(tester, [job(id: 'j1', title: 'Duvar boyama', category: 'painter')]);

    expect(find.text(kQuickSupportName), findsNothing);
    expect(find.text('Tümünü Gör →'), findsNothing);
  });

  testWidgets('Hemen Lazım ilanları kart olarak listelenir', (tester) async {
    await pump(tester, [
      job(id: 'j1', title: 'Duvar boyama', category: 'painter'),
      job(id: 'j2', title: 'Marketten alışveriş', customerName: 'Ayşe K.'),
      job(id: 'j3', title: 'Koli taşınacak', customerName: 'Mehmet Y.'),
    ]);

    // Başlık + tümünü gör bağlantısı.
    expect(find.text(kQuickSupportName), findsWidgets);
    expect(find.text('Tümünü Gör →'), findsOneWidget);

    // Yalnız Hemen Lazım ilanları — klasik ilan şeride SIZMAMALI.
    expect(find.text('Marketten alışveriş'), findsOneWidget);
    expect(find.text('Koli taşınacak'), findsOneWidget);
    expect(find.text('Duvar boyama'), findsNothing);

    // İlçe kartta görünür. Sahibinin ADI artık GÖSTERİLMİYOR (2026-08-08):
    // dar kartta ilanın kendi görseli + başlığı öncelikli, sahip bilgisi
    // ilan detayında duruyor.
    expect(find.text('Osmangazi'), findsWidgets);
    expect(find.text('Ayşe K.'), findsNothing);
  });

  testWidgets('fotoğrafsız ilanda kategori ikonu gösterilir', (tester) async {
    await pump(tester, [
      job(id: 'j1', title: 'Eczaneye gidilecek'),
    ]);

    // Boş gri kutu yerine "Hemen Lazım" kategorisinin şimşek ikonu.
    expect(find.text('Eczaneye gidilecek'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
  });

  test('quickSupportJobsProvider yalnız Hemen Lazım ilanlarını süzer', () {
    final c = ProviderContainer(overrides: [
      ...mockBackendOverrides(),
      openJobsProvider.overrideWith((ref) => Stream.value([
            job(id: 'j1', title: 'Boya', category: 'painter'),
            job(id: 'j2', title: 'Market'),
          ])),
    ]);
    addTearDown(c.dispose);

    // Stream'in ilk değeri okunana kadar liste boş olabilir; dinleyip bekleriz.
    c.listen(openJobsProvider, (_, _) {});
    return c.read(openJobsProvider.future).then((_) {
      final quick = c.read(quickSupportJobsProvider);
      expect(quick.map((j) => j.jobId), ['j2']);
    });
  });
}
