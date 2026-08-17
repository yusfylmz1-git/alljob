/// Ürün kategorileri — Mağaza vitrini için (2026-08-10).
///
/// **Neden mesleklerden ayrı:** `professions.json` bir HİZMET listesidir.
/// Bu liste ÜRÜNÜN KENDİSİNİ tarif eder.
///
/// **Kaynak:** Admin `adminConfig/productCategories` dokümanını yönetir.
/// İstemci [ProductCategoryCatalog] ile canlı okur. Firestore boşsa
/// [ProductCategory.defaults] yedek listesi kullanılır (offline / ilk kurulum).
///
/// ⚠️ Kodlar Firestore'daki `products.categoryCode` alanına yazılır —
/// yeniden adlandırmak veri göçüdür (CLAUDE.md kural 6). Görünen ad
/// serbestçe değişebilir, kod değişemez.
class ProductCategoryItem {
  const ProductCategoryItem({
    required this.code,
    required this.label,
    this.order = 0,
    this.active = true,
  });

  final String code;
  final String label;
  final int order;
  final bool active;

  Map<String, dynamic> toMap() => {
        'code': code,
        'label': label,
        'order': order,
        'active': active,
      };

  factory ProductCategoryItem.fromMap(Map<String, dynamic> m) {
    final code = (m['code'] as String?)?.trim() ?? '';
    final label = (m['label'] as String?)?.trim() ?? '';
    return ProductCategoryItem(
      code: code,
      label: label.isEmpty ? code : label,
      order: (m['order'] as num?)?.toInt() ?? 0,
      active: m['active'] != false,
    );
  }

  ProductCategoryItem copyWith({
    String? code,
    String? label,
    int? order,
    bool? active,
  }) =>
      ProductCategoryItem(
        code: code ?? this.code,
        label: label ?? this.label,
        order: order ?? this.order,
        active: active ?? this.active,
      );
}

/// Canlı (veya yedek) ürün kategorisi kataloğu.
class ProductCategoryCatalog {
  const ProductCategoryCatalog(this.items);

  final List<ProductCategoryItem> items;

  /// Aktif kategoriler, order + "diger" sonda.
  List<ProductCategoryItem> get activeItems {
    final list = items.where((e) => e.active && e.code.isNotEmpty).toList()
      ..sort((a, b) {
        if (a.code == ProductCategory.diger) return 1;
        if (b.code == ProductCategory.diger) return -1;
        final c = a.order.compareTo(b.order);
        if (c != 0) return c;
        return a.label.compareTo(b.label);
      });
    return list;
  }

  /// Aktif kodlar (form / filtre seçicileri).
  List<String> get sirali =>
      activeItems.map((e) => e.code).toList(growable: false);

  /// Kod → görünen ad; bilinmeyen kod yedek listede aranır, yoksa "Diğer".
  String label(String code) {
    for (final e in items) {
      if (e.code == code) return e.label;
    }
    return ProductCategory.label(code);
  }

  bool tanidik(String code) {
    for (final e in items) {
      if (e.code == code) return true;
    }
    return ProductCategory.tanidik(code);
  }

  int order(String code) {
    for (final e in items) {
      if (e.code == code) return e.order;
    }
    return ProductCategory.order(code);
  }

  /// Firestore `adminConfig/productCategories` → katalog.
  /// Boş / geçersiz → yedek varsayılanlar.
  factory ProductCategoryCatalog.fromRemote(Map<String, dynamic>? map) {
    if (map == null) return ProductCategoryCatalog.defaults;
    final raw = map['items'];
    if (raw is! List || raw.isEmpty) {
      return ProductCategoryCatalog.defaults;
    }
    final items = <ProductCategoryItem>[];
    final seen = <String>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final item = ProductCategoryItem.fromMap(e.cast<String, dynamic>());
      if (item.code.isEmpty || !seen.add(item.code)) continue;
      items.add(item);
    }
    if (items.isEmpty) return ProductCategoryCatalog.defaults;
    return ProductCategoryCatalog(items);
  }

  /// Uygulama içi yedek (kod gömülü liste).
  static ProductCategoryCatalog get defaults {
    final items = <ProductCategoryItem>[
      for (var i = 0; i < ProductCategory.sirali.length; i++)
        ProductCategoryItem(
          code: ProductCategory.sirali[i],
          label: ProductCategory.label(ProductCategory.sirali[i]),
          order: i,
          active: true,
        ),
    ];
    return ProductCategoryCatalog(items);
  }
}

/// Gömülü yedek kodlar + statik yardımcılar (offline / bilinmeyen kod).
class ProductCategory {
  ProductCategory._();

  static const String yapiMalzeme = 'yapi_malzeme';
  static const String hirdavat = 'hirdavat';
  static const String mobilya = 'mobilya';
  static const String beyazEsya = 'beyaz_esya';
  static const String elektronik = 'elektronik';
  static const String tesisatMalzeme = 'tesisat_malzeme';
  static const String aracParca = 'arac_parca';
  static const String bahce = 'bahce';
  static const String evTekstil = 'ev_tekstil';
  static const String mutfak = 'mutfak';
  static const String hobiSpor = 'hobi_spor';
  static const String bebekCocuk = 'bebek_cocuk';
  static const String isMakinesi = 'is_makinesi';

  // — Mağaza senaryosu genişletmesi (2026-08-14, new.md madde 4) —
  // Vitrin yalnız tadilat/hırdavat mağazalarına göre kurulmuştu; giyim,
  // market, kozmetik gibi yaygın esnaf "Diğer"e düşüyordu. Kodlar YENİ
  // eklendi, mevcutlar değişmedi (kural 6: kod = Firestore verisi).
  static const String aydinlatma = 'aydinlatma';
  static const String banyoSeramik = 'banyo_seramik';
  static const String boyaKimyasal = 'boya_kimyasal';
  static const String isitmaSogutma = 'isitma_sogutma';
  static const String kapiPencere = 'kapi_pencere';
  static const String giyimAksesuar = 'giyim_aksesuar';
  static const String kozmetikKisisel = 'kozmetik_kisisel';
  static const String gidaMarket = 'gida_market';
  static const String petHayvan = 'pet_hayvan';
  static const String kirtasiyeOfis = 'kirtasiye_ofis';
  static const String tarimHayvancilik = 'tarim_hayvancilik';
  static const String guvenlikKamera = 'guvenlik_kamera';
  static const String temizlikHijyen = 'temizlik_hijyen';
  static const String hediyelikSus = 'hediyelik_sus';

  static const String diger = 'diger';

  /// Gösterim sırası (yedek). İlgili olanlar yan yana: önce yapı/tadilat
  /// ekseni, sonra ev, sonra genel perakende. `diger` HER ZAMAN sonda.
  static const List<String> sirali = [
    // Yapı & tadilat
    yapiMalzeme,
    hirdavat,
    tesisatMalzeme,
    boyaKimyasal,
    banyoSeramik,
    kapiPencere,
    aydinlatma,
    isitmaSogutma,
    guvenlikKamera,
    // Ev & yaşam
    mobilya,
    beyazEsya,
    elektronik,
    evTekstil,
    mutfak,
    temizlikHijyen,
    hediyelikSus,
    // Araç & iş
    aracParca,
    isMakinesi,
    bahce,
    tarimHayvancilik,
    // Genel perakende
    giyimAksesuar,
    kozmetikKisisel,
    gidaMarket,
    petHayvan,
    kirtasiyeOfis,
    hobiSpor,
    bebekCocuk,
    diger,
  ];

  static const Map<String, String> _adlar = {
    yapiMalzeme: 'Yapı Malzemesi',
    hirdavat: 'Hırdavat & El Aleti',
    tesisatMalzeme: 'Tesisat & Elektrik Malzemesi',
    mobilya: 'Mobilya & Dekorasyon',
    beyazEsya: 'Beyaz Eşya',
    elektronik: 'Elektronik',
    aracParca: 'Araç & Yedek Parça',
    isMakinesi: 'İş Makinesi & Ekipman',
    bahce: 'Bahçe & Tarım',
    evTekstil: 'Ev Tekstili',
    mutfak: 'Mutfak & Züccaciye',
    hobiSpor: 'Hobi & Spor',
    bebekCocuk: 'Bebek & Çocuk',
    aydinlatma: 'Aydınlatma',
    banyoSeramik: 'Banyo & Seramik',
    boyaKimyasal: 'Boya & Kimyasal',
    isitmaSogutma: 'Isıtma & Soğutma',
    kapiPencere: 'Kapı & Pencere',
    giyimAksesuar: 'Giyim & Aksesuar',
    kozmetikKisisel: 'Kozmetik & Kişisel Bakım',
    gidaMarket: 'Gıda & Market',
    petHayvan: 'Pet & Evcil Hayvan',
    kirtasiyeOfis: 'Kırtasiye & Ofis',
    tarimHayvancilik: 'Tarım & Hayvancılık',
    guvenlikKamera: 'Güvenlik & Kamera',
    temizlikHijyen: 'Temizlik & Hijyen',
    hediyelikSus: 'Hediyelik & Süs',
    diger: 'Diğer',
  };

  /// Kategorinin Türkçe adı; bilinmeyen kod "Diğer" sayılır.
  static String label(String code) => _adlar[code] ?? _adlar[diger]!;

  static int order(String code) {
    final i = sirali.indexOf(code);
    return i < 0 ? sirali.length : i;
  }

  static bool tanidik(String code) => _adlar.containsKey(code);

  /// Etiketten güvenli kod üretir (`Ahşap & Mobilya` → `ahsap_mobilya`).
  static String codeFromLabel(String label) {
    final folded = label
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c')
        .toLowerCase();
    final buf = StringBuffer();
    var prevUnderscore = false;
    for (final r in folded.runes) {
      final ch = String.fromCharCode(r);
      final ok = RegExp(r'[a-z0-9]').hasMatch(ch);
      if (ok) {
        buf.write(ch);
        prevUnderscore = false;
      } else if (!prevUnderscore && buf.isNotEmpty) {
        buf.write('_');
        prevUnderscore = true;
      }
    }
    var code = buf.toString().replaceAll(RegExp(r'_+$'), '');
    if (code.isEmpty) code = 'kategori';
    if (code.length > 40) code = code.substring(0, 40);
    if (!RegExp(r'^[a-z]').hasMatch(code)) code = 'k_$code';
    return code;
  }

  /// Kod biçimi geçerli mi? (`a-z`, rakam, `_`; 2–40 karakter.)
  static bool isValidCode(String code) =>
      RegExp(r'^[a-z][a-z0-9_]{1,39}$').hasMatch(code);
}
