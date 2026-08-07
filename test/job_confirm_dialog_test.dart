import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/features/jobs/presentation/job_completion.dart';

/// B-18 regresyonu — tamamlama onayı ("İşi teslim ettim" / "İş bitti,
/// onaylıyorum") kullanıcıya SORULMADAN uygulanmamalı.
///
/// `confirmDone` geri alınamaz: istemcide onayı geri alma yolu yok ve karşı
/// taraf da onaylarsa ilan `completed` olur. Düğme ayrıca "Sohbete Git" ile
/// bitişik duruyor — onaysız hâlinde yanlış dokunuş işi kapatıyordu.
void main() {
  /// Diyaloğu açar ve dönen kararı yakalar.
  Future<bool?> openDialog(
    WidgetTester tester, {
    required bool isOwner,
  }) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await confirmJobDoneDialog(context, isOwner: isOwner);
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    return result;
  }

  group('B-18 · tamamlama onayı diyaloğu', () {
    testWidgets('müşteriye "geri alınamaz" uyarısı gösterilir', (tester) async {
      await openDialog(tester, isOwner: true);

      expect(find.text('İşi onaylıyor musunuz?'), findsOneWidget);
      expect(
        find.textContaining('Bu işlem geri alınamaz'),
        findsOneWidget,
        reason: 'Geri alınamazlık uyarısı kaldırılmamalı.',
      );
      // Vazgeçme yolu her zaman açık olmalı.
      expect(find.text('Vazgeç'), findsOneWidget);
    });

    testWidgets('ustaya teslim metni gösterilir', (tester) async {
      await openDialog(tester, isOwner: false);

      expect(find.text('İşi teslim ettiniz mi?'), findsOneWidget);
      expect(find.textContaining('Bu işlem geri alınamaz'), findsOneWidget);
      expect(find.text('Teslim ettim'), findsOneWidget);
    });

    testWidgets('"Vazgeç" false döner — onay UYGULANMAZ', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmJobDoneDialog(context, isOwner: true);
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(result, isFalse,
          reason: 'Vazgeçince çağıran taraf confirmDone ÇAĞIRMAMALI.');
    });

    testWidgets('onaylayınca true döner', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmJobDoneDialog(context, isOwner: true);
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onaylıyorum'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('diyalog dışına dokunup kapatınca false döner', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await confirmJobDoneDialog(context, isOwner: false);
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      // Barrier'a dokun → showDialog null döner; fonksiyon false'a çevirmeli.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isFalse,
          reason: 'null (kapatma) sessizce true sayılmamalı.');
    });
  });
}
