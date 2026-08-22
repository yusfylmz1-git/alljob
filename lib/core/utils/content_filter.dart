import 'search_fold.dart';

/// Argo / müstehcen içerik denetimi (2026-08-23).
///
/// Kapalı test bulgusu: "mesajlarda argo kelime filtreleme yapmıyoruz;
/// müstehcen yazıların denetlemesini nasıl yaparız?"
///
/// ── TASARIM: ENGELLEME DEĞİL, KADEMELİ MÜDAHALE ──
///
/// Kelime listesiyle mesaj SİLMEK kötü bir denge kurar: Türkçede bağlama göre
/// masum kullanımlar vardır ("sikke", "pisliği temizledim") ve yanlış pozitif
/// kullanıcının meşru mesajını yutar — üstelik sessizce. Onun yerine iki
/// eşik:
///
///  * [ContentSeverity.mild] — kaba dil. İstemci "böyle göndermek istediğine
///    emin misin?" diye sorar, kullanıcı ısrar ederse GÖNDERİLİR. Amaç
///    öfkeyle yazılan mesajı bir saniye geciktirmek.
///  * [ContentSeverity.severe] — cinsel içerik / ağır hakaret / taciz. Mesaj
///    yine gönderilebilir ama sunucu tarafında moderasyon kuyruğuna
///    OTOMATİK düşer (`onMessageCreated`). Karar insanındır, filtrenin
///    değil.
///
/// ── KAÇIŞ NORMALİZASYONU ──
///
/// Ham `contains` işe yaramaz: "s.i.k", "sıkkk", "s1k", "S İ K" hepsi aynı
/// kelimedir. [normalizeForFilter] Türkçe katlama + leetspeak çözümü + harf
/// tekrarı daraltma + ayraç temizliği yapar.
///
/// ── SINIRLARI ──
///
/// Bu bir sözlük eşleştiricidir, anlam çözümleyici DEĞİLDİR. Yeni argo,
/// yaratıcı kaçışlar ve bağlamsal taciz kaçar. Bu yüzden ŞİKÂYET YOLU
/// (`reports` koleksiyonu + admin kuyruğu) asıl mekanizmadır; filtre onun
/// önüne konan ucuz bir ilk süzgeçtir.
class ContentFilter {
  ContentFilter._();

  /// Ağır içerik: cinsel içerik, ağır hakaret, taciz.
  /// Normalize edilmiş (Türkçe katlanmış, leet çözülmüş) biçimde tutulur.
  static const List<String> _severe = [
    'amcik', 'amcigi', 'amina', 'aminakoyayim', 'amk', 'aq',
    'sikeyim', 'sikerim', 'siktir', 'sikik', 'sikis', 'siktimin',
    'yarak', 'tasak', 'gotveren', 'ibne', 'pust',
    'orospu', 'orospucocugu', 'kahpe', 'kaltak', 'surtuk',
    'pezevenk', 'godos', 'piclik', 'picfendi',
    'gavat', 'kancik', 'zikeyim', 'zikerim',
    'anani', 'avradini', 'sulaleni',
  ];

  /// Kaba dil: hakaret sayılır ama ağır değil. Uyarı eşiği.
  ///
  /// LİSTEYE ALINMAYANLAR ve nedeni — "lan" / "ulan" / "bok": günlük Türkçede
  /// dolgu sözcüğü olarak o kadar yaygın ki ("lan unuttum", "bok gibi hava")
  /// uyarı diyaloğu sürekli çıkar, kullanıcı öğrenip her seferinde geçer ve
  /// uyarı GERÇEK hakarette de anlamsızlaşır. Filtrenin işe yaraması için
  /// nadiren konuşması gerekir.
  static const List<String> _mild = [
    'salak', 'aptal', 'gerizekali', 'gerizeka',
    'serefsiz', 'namusuz', 'alcak', 'ahmak',
    'dangalak', 'gerzek', 'embesil', 'moron',
    'defol', 'gebermek', 'geberesin',
  ];

  /// Yanlış pozitif kalkanı — normalize metinde bu kalıplar varsa, içine
  /// gömülü yasak kelime SAYILMAZ.
  ///
  /// ⚠️ NORMALİZE BİÇİMDE yazılır: kalkan [normalizeForFilter] çıktısı
  /// üzerinde çalışır ve o çıktıda çift harfler teke inmiştir
  /// ("sikke" → "sike"). Ham hâliyle yazılan bir madde hiç eşleşmez ve
  /// kalkan sessizce devre dışı kalır.
  ///
  /// Liste küçük tutulur: her madde aynı zamanda bir kaçış deliğidir
  /// (kullanıcı "malzeme" yazıp içine küfür saklayamaz, çünkü maskeleme
  /// yalnız kelimenin kendisini boşluğa çevirir).
  static const List<String> _allowList = [
    // sikke → sike · sikkeler → sikeler (çift harf teke iner)
    'sike', 'sikeler', 'siklet', 'sirkeci', 'siklon',
    'analiz', 'anayasa', 'anahtar', 'anadolu', 'anaokulu',
    'malzeme', 'maliyet', 'malikane', 'malatya',
    'bokser', 'boksor',
  ];

  /// Metni denetler. Hiçbir şey bulunmazsa [ContentVerdict.clean].
  static ContentVerdict inspect(String? input) {
    final ham = input?.trim() ?? '';
    if (ham.isEmpty) return ContentVerdict.clean;

    final norm = normalizeForFilter(ham);
    if (norm.isEmpty) return ContentVerdict.clean;

    // Kalkan: izinli kelimeler maskelenir ki içlerindeki dizi eşleşmesin.
    var arama = norm;
    for (final ok in _allowList) {
      arama = arama.replaceAll(ok, ' ');
    }

    final bulunan = <String>[];
    for (final w in _severe) {
      if (_contains(arama, w)) bulunan.add(w);
    }
    if (bulunan.isNotEmpty) {
      return ContentVerdict(
        severity: ContentSeverity.severe,
        matches: List.unmodifiable(bulunan),
      );
    }

    for (final w in _mild) {
      if (_contains(arama, w)) bulunan.add(w);
    }
    if (bulunan.isNotEmpty) {
      return ContentVerdict(
        severity: ContentSeverity.mild,
        matches: List.unmodifiable(bulunan),
      );
    }
    return ContentVerdict.clean;
  }

  /// Kelime sınırına saygılı arama.
  ///
  /// Düz `contains` "malzeme" içinde "mal"ı bulur ve masum mesajı yakalar.
  /// Sınır: harf/rakam OLMAYAN karakter ya da dize ucu.
  static bool _contains(String haystack, String needle) {
    if (needle.isEmpty) return false;
    var from = 0;
    while (true) {
      final i = haystack.indexOf(needle, from);
      if (i < 0) return false;
      final oncesi = i == 0 ? '' : haystack[i - 1];
      final sonrasiIdx = i + needle.length;
      final sonrasi =
          sonrasiIdx >= haystack.length ? '' : haystack[sonrasiIdx];
      final solBos = oncesi.isEmpty || !_harfMi(oncesi);
      final sagBos = sonrasi.isEmpty || !_harfMi(sonrasi);
      if (solBos && sagBos) return true;
      from = i + 1;
    }
  }

  static bool _harfMi(String c) => RegExp(r'[a-z0-9]').hasMatch(c);
}

/// Filtre için metni sadeleştirir — kaçış denemelerini geri açar.
///
/// Adımlar (sıra önemlidir):
///  1. Türkçe katlama (`İ→i`, `ş→s`, …) ve küçük harfe indirme.
///  2. Leetspeak çözümü (`0→o`, `1→i`, `3→e`, `4→a`, `5→s`, `7→t`, `@→a`,
///     `$→s`). "s1kt1r" → "siktir".
///  3. Harf/rakam dışındaki her şey tek boşluğa iner — "s.i.k" → "s i k".
///  4. TEK harflik parçalar birleştirilir: "s i k t i r" → "siktir".
///     (Kaçışın en yaygın biçimi budur; normal Türkçe metinde arka arkaya
///     üçten fazla tek harf gelmez.)
///  5. Üç ve daha fazla tekrar eden harf ikiye iner: "sikkkkk" → "sikk",
///     ardından çift harf teke iner: "sikk" → "sik".
String normalizeForFilter(String input) {
  var s = foldTrSearch(input);

  const leet = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a',
    '5': 's', '7': 't', '@': 'a', r'$': 's', '!': 'i',
  };
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    sb.write(leet[ch] ?? ch);
  }
  s = sb.toString();

  // Harf/rakam dışı → boşluk.
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  if (s.isEmpty) return '';

  // Tek harflik parçaları birleştir ("s i k t i r" → "siktir").
  final parcalar = s.split(' ');
  final cikti = <String>[];
  var tampon = StringBuffer();
  for (final p in parcalar) {
    if (p.length == 1) {
      tampon.write(p);
    } else {
      if (tampon.isNotEmpty) {
        cikti.add(tampon.toString());
        tampon = StringBuffer();
      }
      cikti.add(p);
    }
  }
  if (tampon.isNotEmpty) cikti.add(tampon.toString());
  s = cikti.join(' ');

  // Tekrar daraltma: 3+ → 2, sonra 2 → 1.
  s = s.replaceAllMapped(RegExp(r'(.)\1{2,}'), (m) => '${m[1]}${m[1]}');
  s = s.replaceAllMapped(RegExp(r'(.)\1'), (m) => m[1]!);

  return s;
}

/// Denetim sonucu.
class ContentVerdict {
  const ContentVerdict({required this.severity, required this.matches});

  static const ContentVerdict clean = ContentVerdict(
    severity: ContentSeverity.clean,
    matches: [],
  );

  final ContentSeverity severity;

  /// Eşleşen (normalize edilmiş) kelimeler — moderasyon kaydı için.
  /// KULLANICIYA GÖSTERİLMEZ: hangi kelimenin yakalandığını söylemek
  /// filtreyi atlatmayı öğretir.
  final List<String> matches;

  bool get isClean => severity == ContentSeverity.clean;
  bool get needsWarning => severity == ContentSeverity.mild;
  bool get needsReview => severity == ContentSeverity.severe;
}

/// İçerik ağırlığı. `apiValue` Firestore'a yazılan değerdir (kural 6).
enum ContentSeverity {
  clean('clean'),
  mild('mild'),
  severe('severe');

  const ContentSeverity(this.apiValue);
  final String apiValue;

  static ContentSeverity fromString(String? v) => switch (v) {
        'mild' => ContentSeverity.mild,
        'severe' => ContentSeverity.severe,
        _ => ContentSeverity.clean,
      };
}
