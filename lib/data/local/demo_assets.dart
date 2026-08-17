/// Mağaza ekran görüntüsü setinin görselleri.
///
/// `assets/demo/` altındaki dosyaları okuyup depoya `local://demo/<tür>/<ad>`
/// handle'ıyla yükler. `AppImage` `local://` dalını zaten destekliyor
/// (`core/widgets/app_image.dart`) → görselleri göstermek için UI kodunda
/// hiçbir değişiklik gerekmez.
///
/// Görsel dosyası YOKSA sessizce atlanır: `AppAvatar` renkli baş harf
/// rozetine, ürün/iş kartları da kategori ikonuna düşer. Yani fotoğraflar
/// kaliteyi yükseltir, ön koşul değildir.
///
/// Yalnız mock modda çağrılır (bkz. `main.dart`). Ayrıntı ve dosya listesi:
/// `vault/06-Test/Demo-Veri-Seti.md`.
library;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../../features/storage/storage_repository.dart';

/// Persona avatarları — `assets/demo/avatar/<uid>.jpg`, 512×512 kare önerilir.
const kDemoAvatarNames = <String>[
  'demo_kerem',
  'demo_sevil',
  'demo_okan',
  'demo_zeynep',
  'demo_tolga',
  'demo_ayse',
  'demo_burak',
  'demo_hatice',
  'demo_serkan',
  'demo_elif',
];

/// Usta portfolyo görselleri — `assets/demo/work/<ad>.jpg`, 1200×900 (4:3).
/// Sohbetlerde gönderilen fotoğraflar da bu havuzdan gelir.
const kDemoWorkNames = <String>[
  'work_painter_1',
  'work_painter_2',
  'work_painter_3',
  'work_tiler_1',
  'work_tiler_2',
  'work_carpenter_1',
  'work_carpenter_2',
  'work_interior_1',
  'work_interior_2',
];

/// Ürün görselleri — `assets/demo/product/<ad>.jpg`, 1000×1000 kare.
const kDemoProductNames = <String>[
  'prod_1',
  'prod_2',
  'prod_3',
  'prod_4',
  'prod_5',
  'prod_6',
  'prod_7',
  'prod_8',
];

/// Depo handle'ı. `MockDatabase.demoPhoto` ile AYNI deseni üretir —
/// biri değişirse diğeri de değişmeli, yoksa görseller eşleşmez.
String demoAssetHandle(String kind, String name) => 'local://demo/$kind/$name';

/// Tanınan görsel uzantıları. Kullanıcı fotoğrafı nereden gelirse gelsin
/// (telefon, stok site, ekran görüntüsü) uzantısı bunlardan biri olur;
/// dosyayı yeniden adlandırmak zorunda kalmasın diye hepsi denenir.
/// Sıra önceliktir: aynı isim iki uzantıyla varsa ilki kullanılır.
/// `.jfif` Windows'un JPEG'i kaydederken sık kullandığı uzantıdır (aynı
/// biçim, farklı ad) — tarayıcıdan "farklı kaydet" ile inen görseller
/// çoğunlukla böyle gelir.
const _kImageExtensions = <String>[
  '.jpg',
  '.jpeg',
  '.jfif',
  '.png',
  '.webp',
  '.JPG',
  '.JPEG',
  '.JFIF',
  '.PNG',
  '.WEBP',
];

/// Demo görsellerini depoya yükler. Eksik dosyalar atlanır.
/// Yüklenen görsel sayısını döndürür (teşhis/log için).
///
/// Görsel eksikliği HATA DEĞİLDİR — fotoğrafsız çalışmak desteklenen durumdur.
/// Web'de eksik asset motor tarafından konsola 404 olarak yazılır; bunu
/// susturmak için önce manifest'e bakılıp yalnız GERÇEKTEN VAR OLAN dosyalar
/// istenir.
///
/// Uzantı serbesttir (bkz. [_kImageExtensions]) — `demo_kerem.jpg`,
/// `demo_kerem.jpeg` ve `demo_kerem.png` aynı şekilde bulunur. Görselin
/// çözünürlüğü/oranı da önemsizdir; `AppImage` `BoxFit.cover` ile yerleştirir.
Future<int> seedDemoAssets(StorageRepository storage) async {
  final available = await _availableDemoAssets();
  var loaded = 0;

  Future<void> load(String kind, String name) async {
    final path = _resolveAsset(available, kind, name);
    if (path == null) return;
    try {
      final data = await rootBundle.load(path);
      await storage.uploadBytes(
        // uploadBytes handle'ı `local://$path` olarak BİREBİR üretir →
        // demoAssetHandle ile aynı sonuç. Uzantı handle'a GİRMEZ, böylece
        // personadaki sabit anahtar dosya uzantısından bağımsız kalır.
        path: 'demo/$kind/$name',
        bytes: data.buffer.asUint8List(),
        contentType: _contentTypeFor(path),
      );
      loaded++;
    } catch (_) {
      // Okunamadı → baş harf/ikon yedeğine düşer.
    }
  }

  for (final n in kDemoAvatarNames) {
    await load('avatar', n);
  }
  for (final n in kDemoWorkNames) {
    await load('work', n);
  }
  for (final n in kDemoProductNames) {
    await load('product', n);
  }

  return loaded;
}

/// `avatar` + `demo_kerem` → pakette gerçekten bulunan tam yol (uzantısıyla).
/// Hiçbir uzantıyla bulunamazsa null.
String? _resolveAsset(Set<String> available, String kind, String name) {
  for (final ext in _kImageExtensions) {
    final path = 'assets/demo/$kind/$name$ext';
    if (available.contains(path)) return path;
  }
  return null;
}

String _contentTypeFor(String path) {
  final p = path.toLowerCase();
  if (p.endsWith('.png')) return 'image/png';
  if (p.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Pakete gerçekten girmiş demo görsellerinin yolları (AssetManifest).
/// Manifest okunamazsa boş küme döner → hiç görsel yüklenmez, yedeğe düşülür.
Future<Set<String>> _availableDemoAssets() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest
        .listAssets()
        .where((p) => p.startsWith('assets/demo/'))
        .toSet();
  } catch (_) {
    return const {};
  }
}
