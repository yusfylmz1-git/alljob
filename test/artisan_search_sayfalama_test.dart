import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sepette_hizmet/data/local/mock_database.dart';
import 'package:sepette_hizmet/features/artisan/data/artisan_providers.dart';
import 'package:sepette_hizmet/features/artisan/data/artisan_repository.dart';
import 'package:sepette_hizmet/features/artisan/data/mock_artisan_repository.dart';
import 'package:sepette_hizmet/features/customer/application/artisan_search_controller.dart';

/// REGRESYON: Keşfet'te filtreyi "Tümü"ye alınca arayüz donuyordu.
///
/// Sebep: kaydırma dinleyicisi saniyede onlarca kez `loadMore()` çağırır.
/// Koruma yalnız `state.isLoadingMore` bayrağındaydı; `state` ataması bir
/// sonraki mikro-göreve kaldığı için aradaki çağrılar bayrağı hâlâ `false`
/// görüp AYNI sayfayı defalarca istiyordu. Filtre boşken liste 900 kayda
/// kadar büyüdüğünden bu, istek yığılmasına ve donmaya yol açıyordu.
///
/// Düzeltme: senkron `_loadingMore` kilidi (fonksiyonun ilk satırında).
///
/// Çift test: (1) eşzamanlı çağrılar tek isteğe iner, (2) sayfalama
/// yine de doğru çalışır — kilit "fazlasını yapıp" sayfalamayı kırmamalı.
class _SayacliRepository implements ArtisanRepository {
  _SayacliRepository(this._tumu);

  final List<ArtisanSummary> _tumu;
  int cagriSayisi = 0;

  @override
  Future<ArtisanSearchPage> searchArtisans({
    required ArtisanFilter filter,
    required int offset,
    required int limit,
    bool? premiumFreeDuringBeta,
  }) async {
    cagriSayisi++;
    // Gerçek repo gibi asenkron davran (yarış durumu ancak böyle görünür).
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final end = (offset + limit).clamp(0, _tumu.length);
    final items = offset >= _tumu.length
        ? <ArtisanSummary>[]
        : _tumu.sublist(offset, end);
    return ArtisanSearchPage(items: items, hasMore: end < _tumu.length);
  }

  @override
  Future<ArtisanDetail?> getArtisanDetail(String uid) async => null;
}

ArtisanSummary _usta(int i) => ArtisanSummary(
      uid: 'u$i',
      displayName: 'Usta $i',
      professionCode: 'painter',
      professionNameTR: 'Boyacı',
      experienceYears: 5,
      averageRating: 4.5,
      totalReviews: 10,
      isAvailable: true,
      isPremium: false,
      topTags: const [],
      isVerified: false,
      isNewArtisan: false,
    );

void main() {
  late _SayacliRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _SayacliRepository(List.generate(200, _usta));
    container = ProviderContainer(
      overrides: [artisanRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  Future<ArtisanSearchController> aramaYap() async {
    final c = container.read(artisanSearchControllerProvider.notifier);
    await c.search();
    return c;
  }

  test('eşzamanlı 20 loadMore çağrısı TEK sayfa ister', () async {
    final c = await aramaYap();
    final ilkCagri = repo.cagriSayisi; // search() = 1

    // Kaydırma dinleyicisinin davranışı: art arda, beklemeden.
    await Future.wait([for (var i = 0; i < 20; i++) c.loadMore()]);

    expect(repo.cagriSayisi - ilkCagri, 1,
        reason: '20 çağrı 20 ayrı istek üretirse istekler yığılır ve arayüz '
            'donar — "Tümü" filtresindeki donmanın sebebi buydu.');
  });

  test('eşzamanlı çağrılar sonrası liste TEKRARSIZ', () async {
    final c = await aramaYap();
    await Future.wait([for (var i = 0; i < 20; i++) c.loadMore()]);

    final items = container
        .read(artisanSearchControllerProvider)
        .valueOrNull!
        .items;
    final uidler = items.map((e) => e.uid).toList();

    expect(uidler.toSet().length, uidler.length,
        reason: 'Aynı sayfa iki kez eklenirse listede tekrar eden kart çıkar.');
  });

  test('sayfalama HÂLÂ çalışıyor (kilit fazlasını yapmıyor)', () async {
    final c = await aramaYap();
    final ilkAdet = container
        .read(artisanSearchControllerProvider)
        .valueOrNull!
        .items
        .length;

    await c.loadMore();
    await c.loadMore();

    final sonAdet = container
        .read(artisanSearchControllerProvider)
        .valueOrNull!
        .items
        .length;

    expect(sonAdet, greaterThan(ilkAdet),
        reason: 'Kilit, sıralı loadMore çağrılarını da engellememeli.');
  });

  test('liste sonuna gelince hasMore kapanır ve istek durur', () async {
    final c = await aramaYap();

    // 200 kayıt bitene kadar sırayla yükle.
    for (var i = 0; i < 30; i++) {
      final s = container.read(artisanSearchControllerProvider).valueOrNull!;
      if (!s.hasMore) break;
      await c.loadMore();
    }

    final son = container.read(artisanSearchControllerProvider).valueOrNull!;
    expect(son.items, hasLength(200));
    expect(son.hasMore, isFalse);

    final durduktanSonra = repo.cagriSayisi;
    await c.loadMore(); // hasMore false → istek gitmemeli
    expect(repo.cagriSayisi, durduktanSonra,
        reason: 'Liste bitince kaydırma yeni istek üretmemeli.');
  });

  test('yeni arama devam eden sayfalamayı kilitlemez', () async {
    final c = await aramaYap();

    // loadMore'u başlat ama BEKLEME; hemen yeni arama yap.
    final bekleyen = c.loadMore();
    await c.search();
    await bekleyen;

    // Kilit düşmüş olmalı → sayfalama tekrar çalışır.
    final oncekiAdet = container
        .read(artisanSearchControllerProvider)
        .valueOrNull!
        .items
        .length;
    await c.loadMore();
    final sonrakiAdet = container
        .read(artisanSearchControllerProvider)
        .valueOrNull!
        .items
        .length;

    expect(sonrakiAdet, greaterThan(oncekiAdet),
        reason: 'search() kilidi sıfırlamazsa "daha fazla yükle" bir daha '
            'hiç çalışmazdı.');
  });

  test('arama yapılmadan loadMore istek üretmez', () async {
    final c = container.read(artisanSearchControllerProvider.notifier);
    await c.loadMore();

    expect(repo.cagriSayisi, 0);
  });

  group('Mock gecikmesi — "Tümü" filtresindeki donmanın ASIL sebebi', () {
    // Ölçüm: filtresiz listede 900 usta var → 45 sayfa. Her sayfada 400 ms
    // yapay gecikme = 18 saniye bekleme; kullanıcı bunu "donma" olarak
    // görüyordu. Sayfalama gecikmesi kısaltılınca 3.3 saniyeye indi.
    test('sayfalama gecikmesi ilk sayfadan belirgin KISA', () async {
      final r = MockArtisanRepository(MockDatabase());

      final ilk = Stopwatch()..start();
      await r.searchArtisans(
          filter: const ArtisanFilter(), offset: 0, limit: 20);
      ilk.stop();

      final sonraki = Stopwatch()..start();
      await r.searchArtisans(
          filter: const ArtisanFilter(), offset: 20, limit: 20);
      sonraki.stop();

      expect(sonraki.elapsedMilliseconds * 2,
          lessThan(ilk.elapsedMilliseconds),
          reason: 'Sonsuz kaydırmada her sayfa ilk yükleme kadar beklerse '
              'uzun liste donmuş gibi görünür.');
    });

    test('900 kayıtlık liste makul sürede kaydırılabilir', () async {
      final r = MockArtisanRepository(MockDatabase(withDemoPersonas: true));

      final sw = Stopwatch()..start();
      var offset = 0, tur = 0;
      while (tur < 60) {
        final p = await r.searchArtisans(
            filter: const ArtisanFilter(), offset: offset, limit: 20);
        offset += 20;
        tur++;
        if (!p.hasMore) break;
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(8000),
          reason: 'Tüm listeyi gezmek 8 saniyeyi aşarsa kullanıcı donma '
              'olarak algılar (düzeltme öncesi 18 saniyeydi).');
    });
  });
}
