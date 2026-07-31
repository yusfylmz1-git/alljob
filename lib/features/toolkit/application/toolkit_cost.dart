/// Usta Çantası (PRD-007 Faz C) iş & maliyet motorları — saf Dart, test edilebilir.
///
/// Maliyet, kâr, teklif, birim dönüşümü ve iş süresi. Tüm sonuçlar tahmini
/// ([HesapSonucu] sözleşmesi); para birimi TL varsayılır, biçim `trSayi`.
library;

import 'dart:math' as math;

import 'toolkit_calculators.dart' show trSayi;
import 'toolkit_models.dart';

// ---------------------------------------------------------------------------
// Maliyet
// ---------------------------------------------------------------------------

/// Toplam maliyet sonucu: bileşen kırılımı + toplam.
class MaliyetSonucu extends HesapSonucu {
  const MaliyetSonucu({
    required this.malzeme,
    required this.iscilik,
    required this.yol,
    required this.diger,
    required this.toplam,
  });

  final double malzeme;
  final double iscilik;
  final double yol;
  final double diger;
  final double toplam;

  @override
  String get ozet => 'Maliyet (tahmini)\n'
      'Malzeme: ${trSayi(malzeme)} TL\n'
      'İşçilik: ${trSayi(iscilik)} TL\n'
      'Yol: ${trSayi(yol)} TL\n'
      'Diğer: ${trSayi(diger)} TL\n'
      'Toplam: ${trSayi(toplam)} TL';
}

/// Bileşenleri toplayıp [MaliyetSonucu] üretir (negatifler 0'a sıkışır).
MaliyetSonucu maliyetHesapla({
  double malzeme = 0,
  double iscilik = 0,
  double yol = 0,
  double diger = 0,
}) {
  double p(double v) => math.max(0.0, v);
  final m = p(malzeme), i = p(iscilik), y = p(yol), d = p(diger);
  return MaliyetSonucu(
    malzeme: m,
    iscilik: i,
    yol: y,
    diger: d,
    toplam: m + i + y + d,
  );
}

// ---------------------------------------------------------------------------
// Kâr
// ---------------------------------------------------------------------------

/// Kâr yöntemi: maliyet üstüne yüzde ekle veya sabit tutar ekle.
enum KarYontemi { yuzde, sabit }

/// Kâr sonucu: maliyet + kâr → satış fiyatı.
class KarSonucu extends HesapSonucu {
  const KarSonucu({
    required this.maliyet,
    required this.karTutari,
    required this.satis,
    required this.efektifYuzde,
  });

  final double maliyet;
  final double karTutari;
  final double satis;

  /// Satışa göre gerçekleşen kâr yüzdesi (rapor için).
  final double efektifYuzde;

  @override
  String get ozet => 'Kâr / satış (tahmini)\n'
      'Maliyet: ${trSayi(maliyet)} TL\n'
      'Kâr: ${trSayi(karTutari)} TL (%${trSayi(efektifYuzde)})\n'
      'Satış fiyatı: ${trSayi(satis)} TL';
}

/// Maliyete kâr uygulayıp satış fiyatı üretir.
///
/// [yontem] yuzde → [deger] % olarak; sabit → [deger] TL olarak eklenir.
KarSonucu karHesapla({
  required double maliyet,
  required KarYontemi yontem,
  required double deger,
}) {
  final m = math.max(0.0, maliyet);
  final d = math.max(0.0, deger);
  final kar = yontem == KarYontemi.yuzde ? m * (d / 100.0) : d;
  final satis = m + kar;
  final efektif = satis > 0 ? (kar / satis) * 100.0 : 0.0;
  return KarSonucu(
    maliyet: m,
    karTutari: kar,
    satis: satis,
    efektifYuzde: efektif,
  );
}

// ---------------------------------------------------------------------------
// Teklif
// ---------------------------------------------------------------------------

/// Teklif kalemi: açıklama + miktar × birim fiyat.
class TeklifKalemi {
  const TeklifKalemi({
    required this.aciklama,
    required this.miktar,
    required this.birimFiyat,
  });

  final String aciklama;
  final double miktar;
  final double birimFiyat;

  double get tutar => math.max(0.0, miktar) * math.max(0.0, birimFiyat);
}

/// Teklif sonucu: ara toplam + KDV + genel toplam + paylaşılabilir metin.
class TeklifSonucu extends HesapSonucu {
  const TeklifSonucu({
    required this.kalemler,
    required this.araToplam,
    required this.kdvOrani,
    required this.kdvTutari,
    required this.genelToplam,
    required this.not,
  });

  final List<TeklifKalemi> kalemler;
  final double araToplam;

  /// KDV oranı (0.0–1.0; TR standart 0.20).
  final double kdvOrani;
  final double kdvTutari;
  final double genelToplam;
  final String not;

  @override
  String get ozet {
    final b = StringBuffer()..writeln('TEKLİF (tahmini)');
    for (final k in kalemler) {
      b.writeln('- ${k.aciklama}: ${trSayi(k.miktar)} × '
          '${trSayi(k.birimFiyat)} = ${trSayi(k.tutar)} TL');
    }
    b.writeln('Ara toplam: ${trSayi(araToplam)} TL');
    if (kdvOrani > 0) {
      b.writeln('KDV (%${trSayi(kdvOrani * 100)}): ${trSayi(kdvTutari)} TL');
    }
    b.write('GENEL TOPLAM: ${trSayi(genelToplam)} TL');
    if (not.trim().isNotEmpty) b.write('\n\nNot: ${not.trim()}');
    return b.toString();
  }
}

/// Kalemlerden teklif üretir (ara toplam + KDV + genel toplam).
TeklifSonucu teklifHesapla({
  required List<TeklifKalemi> kalemler,
  double kdvOrani = 0.20,
  String not = '',
}) {
  final ara = kalemler.fold<double>(0, (s, k) => s + k.tutar);
  final oran = math.max(0.0, kdvOrani);
  final kdv = ara * oran;
  return TeklifSonucu(
    kalemler: List.unmodifiable(kalemler),
    araToplam: ara,
    kdvOrani: oran,
    kdvTutari: kdv,
    genelToplam: ara + kdv,
    not: not,
  );
}

// ---------------------------------------------------------------------------
// Birim dönüştürücü
// ---------------------------------------------------------------------------

/// Desteklenen dönüşüm grupları. Her grup ortak temel birime çevirir.
enum BirimGrubu { uzunluk, alan, hacim, agirlik }

/// Bir birimin grup içindeki temel birime (m, m², L, kg) çarpanı.
class Birim {
  const Birim(this.ad, this.temeleCarpan);
  final String ad;
  final double temeleCarpan;
}

const Map<BirimGrubu, List<Birim>> kBirimTablosu = {
  BirimGrubu.uzunluk: [
    Birim('mm', 0.001),
    Birim('cm', 0.01),
    Birim('m', 1),
    Birim('inç', 0.0254),
  ],
  BirimGrubu.alan: [
    Birim('cm²', 0.0001),
    Birim('m²', 1),
  ],
  BirimGrubu.hacim: [
    Birim('mL', 0.001),
    Birim('L', 1),
  ],
  BirimGrubu.agirlik: [
    Birim('g', 0.001),
    Birim('kg', 1),
  ],
};

/// [deger]'i [kaynak] biriminden [hedef] birimine çevirir (aynı grup).
double birimCevir(double deger, Birim kaynak, Birim hedef) {
  if (hedef.temeleCarpan == 0) return 0;
  return deger * kaynak.temeleCarpan / hedef.temeleCarpan;
}

// ---------------------------------------------------------------------------
// İş süresi tahmini
// ---------------------------------------------------------------------------

/// İş süresi sonucu: toplam saat + gün (çalışma saatine göre).
class SureSonucu extends HesapSonucu {
  const SureSonucu({
    required this.alanM2,
    required this.m2PerSaat,
    required this.saat,
    required this.gunlukSaat,
    required this.gun,
  });

  final double alanM2;
  final double m2PerSaat;
  final double saat;
  final double gunlukSaat;
  final double gun;

  @override
  String get ozet => 'İş süresi (tahmini)\n'
      'Alan: ${trSayi(alanM2)} m²\n'
      'Hız: ${trSayi(m2PerSaat)} m²/saat\n'
      'Tahmini süre: ${trSayi(saat)} saat (~${trSayi(gun)} gün)';
}

/// Alan + hız (m²/saat) + günlük çalışma saati → tahmini saat/gün.
SureSonucu sureHesapla({
  required double alanM2,
  required double m2PerSaat,
  double gunlukSaat = 8,
}) {
  final alan = math.max(0.0, alanM2);
  final hiz = m2PerSaat > 0 ? m2PerSaat : 1.0;
  final gunluk = gunlukSaat > 0 ? gunlukSaat : 8.0;
  final saat = alan / hiz;
  return SureSonucu(
    alanM2: alan,
    m2PerSaat: hiz,
    saat: saat,
    gunlukSaat: gunluk,
    gun: saat / gunluk,
  );
}
