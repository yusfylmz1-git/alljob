import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:usta_cepte/features/toolkit/application/toolkit_cost.dart';
import 'package:usta_cepte/features/toolkit/application/toolkit_pdf.dart';

/// Teklif PDF üretimi: Türkçe karakter + font gömme çökmeden geçerli bir PDF
/// bayt dizisi üretmeli. (Görsel doğrulama manuel; burada üretim + imza kontrolü.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('tr_TR', null));

  test('teklifPdfOlustur geçerli PDF baytları üretir (Türkçe içerik)',
      () async {
    final sonuc = teklifHesapla(
      kalemler: const [
        TeklifKalemi(
            aciklama: 'Salon duvarı boyası (İşçilik)',
            miktar: 24,
            birimFiyat: 150),
        TeklifKalemi(aciklama: 'Şap + astar', miktar: 1, birimFiyat: 800),
      ],
      kdvOrani: 0.20,
      not: 'Fiyata malzeme dâhildir. Ödeme peşin.',
    );

    final bytes = await teklifPdfOlustur(sonuc, hazirlayan: 'Ömer Çelik');

    // Geçerli PDF "%PDF" (0x25 0x50 0x44 0x46) ile başlar.
    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });
}
