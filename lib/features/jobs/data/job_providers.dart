import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_config.dart';
import '../../../data/models/job.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../artisan/data/artisan_providers.dart'
    show mockDatabaseProvider, premiumFreeForMeProvider;
import '../../auth/application/auth_controller.dart';
import 'firebase_job_repository.dart';
import 'job_repository.dart';
import 'mock_job_repository.dart';

/// Aktif iş ilanı repo'su. Backend seçimi [useFirebaseBackend] ile.
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  if (useFirebaseBackend) return FirebaseJobRepository();
  return MockJobRepository(ref.watch(mockDatabaseProvider));
});

/// HAM açık ilan akışı — iş ilanı + ürün talebi + kendi ilanların, hepsi bir
/// arada, en yeni üstte.
///
/// ⚠️ Bunu doğrudan EKRANA BAĞLAMA. Ürün talepleri ve kullanıcının kendi
/// ilanları burada durur; ekranların beklediği süzülmüş liste
/// [visibleJobFeedProvider]'dır. Bu provider yalnız türetilmiş provider'ların
/// ortak kaynağıdır (tek sorgu, tek dinleyici).
final openJobsProvider = StreamProvider<List<Job>>(
  (ref) => ref.watch(jobRepositoryProvider).watchOpenJobs(),
);

/// Ekrana çıkan iş ilanı listesi — ana sayfa "Son İş İlanları" şeridi ve
/// Keşfet > İlanlar paneli buradan beslenir.
///
/// [openJobsProvider]'ın üstüne üç eleme koyar:
///
///  1. **Ürün talepleri düşer.** Talep ile iş ilanı aynı `jobs` koleksiyonunda
///     durur; ayıran tek şey `category`. Talebin kitlesi satıcılardır.
///  2. **Kendi ilanın düşer.** Kimse kendi verdiği ilana teklif vermez; kendi
///     ilanı "İlanlarım"da görülür.
/// 2026-08-20 test bulgusu: bu elemeler yalnız [nearbyJobsProvider] ve push
/// bildiriminde (`onJobCreated`) vardı; ana sayfa ile Keşfet listesi tüm
/// Türkiye'nin ilanlarını, kendi ilanın ve ürün talepleri dahil gösteriyordu.
///
/// İL elemesi burada YAPILMAZ ve OTOMATİK FİLTRE DE YOKTUR (2026-08-23
/// kullanıcı kararı: "şimdilik tüm ilanları görsün").
///
/// 2026-08-20'de ustanın ili Keşfet filtresine VARSAYILAN olarak
/// yerleştirilmişti; kapalı testte ters etki verdi — usta piyasayı göremiyor,
/// filtrenin kendiliğinden dolduğunu fark etmiyor ve "ilan yok" sanıyordu.
///
/// Yerine ELEME DEĞİL VURGU geldi: liste herkese açıktır, ustanın mesleğine +
/// bölgesine uyan ilanlar yeşil çerçeveyle işaretlenir ve başa alınır
/// ([jobMatchesMeProvider] · [sortJobMatchesFirst]). İl filtresi hâlâ var,
/// ama kullanıcı kendi eliyle seçer.
final visibleJobFeedProvider = Provider<List<Job>>((ref) {
  final jobs = ref.watch(openJobsProvider).valueOrNull ?? const <Job>[];
  final uid = ref.watch(currentUserProvider)?.uid;
  return jobs.where((j) {
    if (j.isProductRequest) return false;
    if (uid != null && j.customerId == uid) return false;
    return true;
  }).toList(growable: false);
});

// `myFeedProvinceProvider` KALDIRILDI (2026-08-23).
//
// Keşfet > İlanlar filtresinin varsayılan ilini üretiyordu; otomatik filtre
// kalkınca çağıranı kalmadı. Yerine geçen ölçüt [jobMatchesMeProvider] —
// il TEK BAŞINA değil, meslek + bölge birlikte değerlendirilir ve sonuç
// eleme değil vurgu üretir.

/// Ana sayfadaki "Hemen Lazım" şeridi: açık Hemen Lazım ilanları, en yeni
/// üstte. [openJobsProvider] üzerinden süzülür — ayrı sorgu/indeks açmaz ve
/// ana sayfa yenilemesi (openJobs invalidate) bu bölümü de tazeler.
///
/// NOT: Buradaki liste açık ilanların son [AppConstants.openJobsFetchCap]
/// tanesinden süzülür; Hemen Lazım ilanı yoğun bir günde eskiler görünmeyebilir
/// — "Tümünü Gör" kendi listesine götürür.
final quickSupportJobsProvider = Provider<List<Job>>((ref) {
  // [visibleJobFeedProvider] üzerinden: il elemesi ve "kendi ilanın düşer"
  // kuralı Hemen Lazım şeridinde de geçerlidir.
  final jobs = ref.watch(visibleJobFeedProvider);
  return jobs.where((j) => j.isQuickSupport).toList(growable: false);
});

/// Mağaza > Talepler: açık ürün talepleri, en yeni üstte.
///
/// [openJobsProvider] üzerinden süzülür — [quickSupportJobsProvider] ile
/// aynı desen: ayrı sorgu/indeks açmaz. Bu talepler USTA feed'ine düşmez
/// (`Job.matchesArtisan` erken `false` döner); burası tek görünür yerleri.
final productRequestsProvider = Provider<List<Job>>((ref) {
  final jobs = ref.watch(openJobsProvider).valueOrNull ?? const <Job>[];
  return jobs.where((j) => j.isProductRequest).toList(growable: false);
});

/// Müşterinin kendi ilanları (İlanlarım).
final myJobsProvider = StreamProvider.family<List<Job>, String>(
  (ref, customerUid) =>
      ref.watch(jobRepositoryProvider).watchMyJobs(customerUid),
);

/// Tek bir ilanı canlı izler (detay ekranı).
final jobProvider = StreamProvider.family<Job?, String>(
  (ref, jobId) => ref.watch(jobRepositoryProvider).watchJob(jobId),
);

/// Oturum açmış ustaya uygun açık ilanlar (Yakındaki İşler).
///
/// ÖNEMLİ: `async*` + `await ref.watch(...future)` kullanma — Riverpod'da
/// async gap sonrası watch ANR / yeniden giriş döngüsü üretebiliyor.
/// Profil henüz yoksa boş liste; ekran profil loading'ini ayrıca gösterir.
final nearbyJobsProvider = StreamProvider<List<Job>>((ref) {
  final draft = ref.watch(myProfileControllerProvider).valueOrNull;
  if (draft == null) {
    return Stream.value(const <Job>[]);
  }
  final profile = draft.profile;
  // MÜSAİTLİK burada ELEMEZ (2026-08-10, kullanıcı kararı): müsait olmayan
  // usta ilanları GÖRÜR ve bildirim ALIR, yalnız MESAJ ATAMAZ. Eskiden feed
  // tamamen boşalıyordu; usta müsaitliğini açmadan piyasada ne olduğunu
  // göremiyordu. Mesaj kapısı yerinde duruyor (_ArtisanOfferSection).
  if (profile.professionCodes.isEmpty || profile.serviceAreas.isEmpty) {
    return Stream.value(const <Job>[]);
  }
  final uid = profile.uid;
  return ref.read(jobRepositoryProvider).watchNearbyJobs(
        professionCodes: profile.professionCodes,
        serviceAreas: profile.serviceAreas,
      ).map((jobs) => jobs.where((j) => j.customerId != uid).toList());
});

/// "Bu ilan BANA uygun mu?" sorusunun TEK cevabı (2026-08-23).
///
/// Uygun = ilanın kategorisi ustanın mesleklerinden biri VE ili hizmet
/// bölgelerinden biri — yani [Job.matchesArtisan]. Push bildirimi
/// (`onJobCreated`) ve [nearbyJobsProvider] aynı ölçütü kullanır; kart
/// vurgusu da buradan beslenir ki üç yer birbirinden ayrışmasın.
///
/// KAPI DEĞİLDİR: uygun olmayan ilan gizlenmez, yalnız vurgulanmaz. Liste
/// herkese açıktır (2026-08-23 kullanıcı kararı: "şimdilik tüm ilanları
/// görsün"); usta uygun olanları çerçeveden ayırt eder.
///
/// Müsaitlik BURADA elemez — müsait olmayan usta da uygun ilanı görmeli
/// ([nearbyJobsProvider] ile aynı gerekçe); mesaj kapısı ilan detayında.
///
/// Ustalık profili yoksa (müşteri, misafir) her zaman `false` döner —
/// vurgusuz düz liste.
final jobMatchesMeProvider = Provider<bool Function(Job)>((ref) {
  final draft = ref.watch(myProfileControllerProvider).valueOrNull;
  final profile = draft?.profile;
  if (profile == null ||
      profile.professionCodes.isEmpty ||
      profile.serviceAreas.isEmpty) {
    return (_) => false;
  }
  final codes = profile.professionCodes;
  final areas = profile.serviceAreas;
  return (job) => job.matchesArtisan(
        professionCodes: codes,
        serviceAreas: areas,
      );
});

/// Ustaya uyan ilanları listenin BAŞINA alır; grup içindeki sıra korunur.
///
/// Ana sayfa şeridi ile Keşfet listesi AYNI sırayı göstermeli — kullanıcı iki
/// yerde farklı dizilim görürse listeye güvenmez. Bu yüzden sıralama tek
/// yerde durur.
///
/// `List.sort` KARARLI DEĞİLDİR: eşit karşılaştırmada öğeleri yer
/// değiştirebilir ve kartlar her yeniden çizimde zıplardı. Bağ, kaynak
/// indeksiyle çözülerek sıralama kararlı hâle getirilir.
///
/// Hiç eşleşme yoksa (müşteri, misafir, profilsiz usta) liste OLDUĞU GİBİ
/// döner — boşuna kopya üretilmez.
List<Job> sortJobMatchesFirst(List<Job> jobs, bool Function(Job) matchesMe) {
  final indexed = [
    for (var i = 0; i < jobs.length; i++) (i, jobs[i], matchesMe(jobs[i])),
  ];
  if (!indexed.any((e) => e.$3)) return jobs;
  indexed.sort((a, b) {
    if (a.$3 != b.$3) return a.$3 ? -1 : 1;
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Ustanın şu an müsait olup olmadığı (feed/ekran mesajları için kısayol).
/// `users.available` ile vitrin müsaitliğini birlikte okur.
///
/// PREMIUM KAPISI ARTIK İL FARKINDA (2026-08-23): eskiden `profile.isAvailable`
/// çağrılıyordu ve o getter YEREL sabiti (`AppConstants.premiumFreeDuringBeta`)
/// okuyordu — remote yapılandırmayı hiç görmüyordu. Şehir bazlı geçişte bu
/// sessiz bir delik olurdu: Bursa ücretliye geçse bile bu provider "müsait"
/// demeye devam ederdi.
///
/// Şimdi karar tek yerden geliyor ([premiumFreeForMeProvider]): beta bayrağı
/// + kullanıcının ili + ücretli il listesi.
final artisanIsAvailableProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  if (!user.available) return false;
  final draft = ref.watch(myProfileControllerProvider).valueOrNull;
  if (draft != null &&
      !draft.profile.isAvailableAt(
        DateTime.now(),
        premiumFreeDuringBeta: ref.watch(premiumFreeForMeProvider),
      )) {
    return false;
  }
  return true;
});
