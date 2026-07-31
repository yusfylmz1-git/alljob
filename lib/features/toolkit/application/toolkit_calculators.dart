/// Usta Çantası (PRD-007 Faz B) ölçüm hesaplayıcıları — saf Dart, test edilebilir.
///
/// Girdi doğrulama UI katmanındadır (`Validators.parseTrAmount`); bu motor
/// yalnız sayı alır ve tahmini sonuç üretir. Tüm sonuçlar [HesapSonucu]
/// sözleşmesini izler (tahmini hep true, `ozet` paylaşılabilir metin).
library;

import 'dart:math' as math;

import 'toolkit_models.dart';

/// TR yazımlı sayı biçimi: ondalık virgül, binlik nokta. Örn. 1234.5 → "1.234,5".
/// Paket eklemeden (intl gerektirmeden) sonuç metinlerini yerelleştirir.
String trSayi(double value, {int ondalik = 2}) {
  if (value.isNaN || value.isInfinite) return '0';
  final negatif = value < 0;
  final v = value.abs();
  // Ondalığı istenen basamağa yuvarla, gereksiz sondaki sıfırları at.
  var s = v.toStringAsFixed(ondalik);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  final parts = s.split('.');
  final intPart = parts[0];
  // Binlik ayracı ekle.
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  final withThousands = buf.toString();
  final result =
      parts.length > 1 ? '$withThousands,${parts[1]}' : withThousands;
  return negatif ? '-$result' : result;
}

// ---------------------------------------------------------------------------
// AR uzunluk (Faz D)
// ---------------------------------------------------------------------------

/// İki 3B nokta arasındaki Öklid mesafesi (m). AR hit-test dünya koordinatları
/// `[x, y, z]` metre cinsindendir; bu fonksiyon UI/AR paketinden bağımsız test
/// edilebilir olsun diye saf Dart tutulur.
double uzunlukM(List<double> a, List<double> b) {
  if (a.length < 3 || b.length < 3) return 0;
  final dx = a[0] - b[0];
  final dy = a[1] - b[1];
  final dz = a[2] - b[2];
  return math.sqrt(dx * dx + dy * dy + dz * dz);
}

/// AR ölçüm sonucu: iki nokta arası tahmini uzunluk (m). Kaynak her zaman AR.
class ArUzunlukSonucu extends HesapSonucu {
  const ArUzunlukSonucu({required this.metre});

  final double metre;

  @override
  String get ozet => 'AR ölçüm (tahmini)\n'
      'İki nokta arası uzunluk: ${trSayi(metre)} m';
}

// ---------------------------------------------------------------------------
// Alan
// ---------------------------------------------------------------------------

/// Alan hesap sonucu: brüt / düşüm / net alan (m²) + fire uygulanmış alan.
class AlanSonucu extends HesapSonucu {
  const AlanSonucu({
    required this.brutM2,
    required this.dususmM2,
    required this.netM2,
    required this.fire,
    required this.fireliM2,
  });

  final double brutM2;
  final double dususmM2;
  final double netM2;
  final FireOrani fire;

  /// Fire eklenmiş alan (malzeme siparişi için). Fire yoksa netM2'ye eşit.
  final double fireliM2;

  @override
  String get ozet {
    final b = StringBuffer()
      ..writeln('Alan hesabı (tahmini)')
      ..writeln('Brüt: ${trSayi(brutM2)} m²');
    if (dususmM2 > 0) b.writeln('Düşüm: ${trSayi(dususmM2)} m²');
    b.write('Net: ${trSayi(netM2)} m²');
    if (fire.oran > 0) {
      b.write('\nFire (${fire.etiket}) dahil: ${trSayi(fireliM2)} m²');
    }
    return b.toString();
  }
}

/// Bir ölçüm seansının net alanına fire uygulayıp [AlanSonucu] üretir.
///
/// [fireOrani] `FireOrani.ozel` için doğrudan verilir (0.0–1.0); diğer
/// durumlarda enum'ın kendi oranı kullanılır.
AlanSonucu alanHesapla(
  OlcumSeansi seans, {
  FireOrani fire = FireOrani.yok,
  double? ozelFireOrani,
}) {
  final brut = seans.yuzeyler.fold<double>(0, (s, y) => s + y.brutAlanM2);
  final dususm = seans.yuzeyler.fold<double>(0, (s, y) => s + y.dususmM2);
  final net = seans.toplamNetAlanM2;
  final oran = fire == FireOrani.ozel ? (ozelFireOrani ?? 0) : fire.oran;
  final fireli = net * (1 + math.max(0.0, oran));
  return AlanSonucu(
    brutM2: brut,
    dususmM2: dususm,
    netM2: net,
    fire: fire,
    fireliM2: fireli,
  );
}

// ---------------------------------------------------------------------------
// Boya
// ---------------------------------------------------------------------------

/// Boya hesap sonucu: tahmini litre + kutu ipucu.
class BoyaSonucu extends HesapSonucu {
  const BoyaSonucu({
    required this.alanM2,
    required this.katSayisi,
    required this.verimM2PerLitre,
    required this.litre,
  });

  final double alanM2;
  final int katSayisi;

  /// 1 litre boyanın kapladığı alan (m²/L). Tipik iç cephe ~10-12.
  final double verimM2PerLitre;
  final double litre;

  @override
  String get ozet => 'Boya hesabı (tahmini)\n'
      'Alan: ${trSayi(alanM2)} m² × $katSayisi kat\n'
      'Verim: ${trSayi(verimM2PerLitre)} m²/L\n'
      'Tahmini boya ihtiyacı: ${trSayi(litre)} litre';
}

/// Boyanacak alan + kat + verim → tahmini litre.
///
/// [alanM2] doğrudan alan (ör. Alan hesabının netM2'si). [verimM2PerLitre]
/// ürün etiketindeki kapama verimi; 0 veya negatifse güvenli varsayılan 10.
BoyaSonucu boyaHesapla({
  required double alanM2,
  int katSayisi = 1,
  double verimM2PerLitre = 10,
}) {
  final verim = verimM2PerLitre > 0 ? verimM2PerLitre : 10.0;
  final katlar = katSayisi < 1 ? 1 : katSayisi;
  final litre = (math.max(0.0, alanM2) * katlar) / verim;
  return BoyaSonucu(
    alanM2: alanM2,
    katSayisi: katlar,
    verimM2PerLitre: verim,
    litre: litre,
  );
}

// ---------------------------------------------------------------------------
// Fayans
// ---------------------------------------------------------------------------

/// Fayans hesap sonucu: tek fayans alanı + fire dahil yaklaşık adet.
class FayansSonucu extends HesapSonucu {
  const FayansSonucu({
    required this.alanM2,
    required this.fayansEnCm,
    required this.fayansBoyCm,
    required this.tekFayansM2,
    required this.fire,
    required this.adet,
  });

  final double alanM2;
  final double fayansEnCm;
  final double fayansBoyCm;
  final double tekFayansM2;
  final FireOrani fire;

  /// Fire dâhil yukarı yuvarlanmış adet.
  final int adet;

  @override
  String get ozet => 'Fayans hesabı (tahmini)\n'
      'Kaplama alanı: ${trSayi(alanM2)} m²\n'
      'Fayans: ${trSayi(fayansEnCm)}×${trSayi(fayansBoyCm)} cm '
      '(${trSayi(tekFayansM2, ondalik: 3)} m²/adet)\n'
      'Fire: ${fire.etiket}\n'
      'Tahmini ihtiyaç: ~$adet adet';
}

/// Kaplama alanı + fayans ebadı + fire → yaklaşık adet (yukarı yuvarlanır).
///
/// Derz (fuga) payı tek fayansın etkin alanını büyütür: en+derz, boy+derz.
/// [derzMm] mm cinsinden; 0 ise derzsiz.
FayansSonucu fayansHesapla({
  required double alanM2,
  required double fayansEnCm,
  required double fayansBoyCm,
  double derzMm = 0,
  FireOrani fire = FireOrani.on,
  double? ozelFireOrani,
}) {
  final derzCm = math.max(0.0, derzMm) / 10.0;
  final enM = (math.max(0.0, fayansEnCm) + derzCm) / 100.0;
  final boyM = (math.max(0.0, fayansBoyCm) + derzCm) / 100.0;
  final tekM2 = enM * boyM;
  final oran = fire == FireOrani.ozel ? (ozelFireOrani ?? 0) : fire.oran;

  int adet;
  if (tekM2 <= 0 || alanM2 <= 0) {
    adet = 0;
  } else {
    final ham = (alanM2 / tekM2) * (1 + math.max(0.0, oran));
    adet = ham.ceil();
  }
  // Rapor edilen "tek fayans alanı" derz HARİÇ fiziksel alandır (kullanıcı
  // beklentisi); adet hesabı derz DAHİL efektif alanı kullanır.
  final fizikselTekM2 =
      (math.max(0.0, fayansEnCm) / 100.0) * (math.max(0.0, fayansBoyCm) / 100.0);
  return FayansSonucu(
    alanM2: alanM2,
    fayansEnCm: fayansEnCm,
    fayansBoyCm: fayansBoyCm,
    tekFayansM2: fizikselTekM2,
    fire: fire,
    adet: adet,
  );
}

// ---------------------------------------------------------------------------
// Parke / Laminat
// ---------------------------------------------------------------------------

/// Parke hesap sonucu: fire dâhil alan + paket adedi.
class ParkeSonucu extends HesapSonucu {
  const ParkeSonucu({
    required this.alanM2,
    required this.paketM2,
    required this.fire,
    required this.fireliM2,
    required this.paketAdedi,
  });

  final double alanM2;

  /// Bir paketin kapladığı alan (m²). Etikette yazar; tipik ~1.5–2.5 m².
  final double paketM2;
  final FireOrani fire;
  final double fireliM2;

  /// Fire dâhil gereken paket sayısı (yukarı yuvarlanır).
  final int paketAdedi;

  @override
  String get ozet => 'Parke hesabı (tahmini)\n'
      'Zemin alanı: ${trSayi(alanM2)} m²\n'
      'Paket: ${trSayi(paketM2, ondalik: 2)} m²/paket\n'
      'Fire: ${fire.etiket}\n'
      'Tahmini ihtiyaç: ~$paketAdedi paket (${trSayi(fireliM2)} m²)';
}

/// Zemin alanı + paket başına m² + fire → gereken paket adedi.
///
/// Parke/laminatta kesim kaybı olur; [fire] varsayılan %10. [paketM2] 0 veya
/// negatifse güvenli varsayılan 2.0 m² kullanılır.
ParkeSonucu parkeHesapla({
  required double alanM2,
  double paketM2 = 2.0,
  FireOrani fire = FireOrani.on,
  double? ozelFireOrani,
}) {
  final alan = math.max(0.0, alanM2);
  final paket = paketM2 > 0 ? paketM2 : 2.0;
  final oran = fire == FireOrani.ozel ? (ozelFireOrani ?? 0) : fire.oran;
  final fireli = alan * (1 + math.max(0.0, oran));
  final adet = (paket <= 0 || fireli <= 0) ? 0 : (fireli / paket).ceil();
  return ParkeSonucu(
    alanM2: alan,
    paketM2: paket,
    fire: fire,
    fireliM2: fireli,
    paketAdedi: adet,
  );
}
