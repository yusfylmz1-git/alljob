import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/product_category.dart';

/// Sıralı sayaç satırı (ör. "İstanbul · 42").
class NamedCount {
  const NamedCount({required this.key, required this.label, required this.count});

  final String key;
  final String label;
  final int count;
}

/// Platform içgörüleri — superadmin özet paneli.
///
/// Tam tarama DEĞİL: son [sampleSize] kayıt üzerinde istemci toplama.
/// `adminStats/global` sayaçlarından farklı; dağılım ve "nerede yoğun?" sorusu
/// için. Etiketlerde örneklem boyutu açık yazılır.
class AdminInsights {
  const AdminInsights({
    required this.generatedAt,
    required this.jobsSampled,
    required this.artisansSampled,
    required this.productsSampled,
    required this.usersSampled,
    this.jobProvinces = const [],
    this.jobCategories = const [],
    this.jobStatus = const [],
    this.jobsLast7d = 0,
    this.jobsOpenInSample = 0,
    this.artisanProfessions = const [],
    this.artisanProvinces = const [],
    this.artisansVerified = 0,
    this.artisansAdminVerified = 0,
    this.artisansFeatured = 0,
    this.artisansPremium = 0,
    this.artisansCertPending = 0,
    this.artisansHidden = 0,
    this.productCategories = const [],
    this.productStatus = const [],
    this.productsPendingReview = 0,
    this.productsHidden = 0,
    this.productsActive = 0,
    this.usersWithArtisan = 0,
    this.usersPhoneVerified = 0,
    this.usersSuspended = 0,
    this.usersLast7d = 0,
  });

  final DateTime generatedAt;

  final int jobsSampled;
  final int artisansSampled;
  final int productsSampled;
  final int usersSampled;

  final List<NamedCount> jobProvinces;
  final List<NamedCount> jobCategories;
  final List<NamedCount> jobStatus;
  final int jobsLast7d;
  final int jobsOpenInSample;

  final List<NamedCount> artisanProfessions;

  /// Ustaların HİZMET VERDİĞİ iller (`serviceProvinces`).
  ///
  /// İlan il dağılımıyla (`jobProvinces`) yan yana konduğunda arz–talep
  /// haritası çıkar: ilanın çok, ustanın az olduğu il büyüme hedefidir.
  /// Bir usta birden çok ilde hizmet verebilir; her il ayrı sayılır.
  final List<NamedCount> artisanProvinces;

  final int artisansVerified;
  final int artisansAdminVerified;
  final int artisansFeatured;
  final int artisansPremium;
  final int artisansCertPending;
  final int artisansHidden;

  final List<NamedCount> productCategories;
  final List<NamedCount> productStatus;
  final int productsPendingReview;
  final int productsHidden;
  final int productsActive;

  final int usersWithArtisan;
  final int usersPhoneVerified;
  final int usersSuspended;
  final int usersLast7d;

  bool get isEmpty =>
      jobsSampled == 0 &&
      artisansSampled == 0 &&
      productsSampled == 0 &&
      usersSampled == 0;
}

/// Saf toplama yardımcıları (test edilebilir).
List<NamedCount> rankCounts(
  Map<String, int> raw, {
  required String Function(String key) labelOf,
  int top = 8,
  String emptyKey = '',
  String emptyLabel = 'Belirtilmemiş',
}) {
  final entries = raw.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      if (c != 0) return c;
      return a.key.compareTo(b.key);
    });
  return [
    for (final e in entries.take(top))
      NamedCount(
        key: e.key,
        label: e.key.trim().isEmpty ? emptyLabel : labelOf(e.key),
        count: e.value,
      ),
  ];
}

void bump(Map<String, int> m, String? key) {
  final k = (key ?? '').trim();
  m[k] = (m[k] ?? 0) + 1;
}

/// Arz–talep satırları: (il, ilan sayısı, usta sayısı).
///
/// İki dağılımın BİRLEŞİMİ alınır — yalnız ilan listesindeki iller alınsaydı
/// "ustası olan ama hiç ilan gelmeyen il" görünmezdi; tersi de aynı şekilde
/// kaybolurdu. Sıralama ilan sayısına göre (talep önce), eşitlikte usta
/// sayısına göre.
///
/// Saf fonksiyon: UI'dan bağımsız test edilir.
List<(String, int, int)> arzTalepSatirlari(
  List<NamedCount> ilanIlleri,
  List<NamedCount> ustaIlleri, {
  int top = 8,
}) {
  final ilan = {for (final r in ilanIlleri) r.label: r.count};
  final usta = {for (final r in ustaIlleri) r.label: r.count};
  final tumIller = <String>{...ilan.keys, ...usta.keys}
      .where((k) => k.trim().isNotEmpty)
      .toList();
  tumIller.sort((a, b) {
    final c = (ilan[b] ?? 0).compareTo(ilan[a] ?? 0);
    if (c != 0) return c;
    final d = (usta[b] ?? 0).compareTo(usta[a] ?? 0);
    if (d != 0) return d;
    return a.compareTo(b);
  });
  return [
    for (final il in tumIller.take(top)) (il, ilan[il] ?? 0, usta[il] ?? 0),
  ];
}

/// Ham döküman haritalarından [AdminInsights] üretir (repo + test ortak).
AdminInsights buildInsightsFromSamples({
  required List<Map<String, dynamic>> jobs,
  required List<Map<String, dynamic>> artisans,
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> users,
  required String Function(String code) professionLabel,
  required String Function(String code) productCategoryLabel,
  required String Function(String status) jobStatusLabel,
  required String Function(String status) productStatusLabel,
  DateTime? now,
}) {
  final t = now ?? DateTime.now().toUtc();
  final weekAgo = t.subtract(const Duration(days: 7));

  final jobProv = <String, int>{};
  final jobCat = <String, int>{};
  final jobSt = <String, int>{};
  var jobs7 = 0;
  var jobsOpen = 0;
  for (final m in jobs) {
    bump(jobProv, m['province'] as String?);
    bump(jobCat, m['category'] as String?);
    final st = (m['status'] as String?) ?? '';
    bump(jobSt, st);
    if (st == 'open') jobsOpen++;
    final created = DateTime.tryParse(m['createdAt']?.toString() ?? '');
    if (created != null && !created.toUtc().isBefore(weekAgo)) jobs7++;
  }

  final artProf = <String, int>{};
  final artProv = <String, int>{};
  var artVer = 0;
  var artAdmin = 0;
  var artFeat = 0;
  var artPrem = 0;
  var artCert = 0;
  var artHide = 0;
  for (final m in artisans) {
    // Çoklu meslek: her kodu say (vitrin yoğunluğu).
    final list = (m['professions'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    if (list.isEmpty) {
      bump(artProf, m['profession'] as String?);
    } else {
      for (final p in list) {
        bump(artProf, p);
      }
    }
    // Hizmet verilen iller. `serviceProvinces` denormalize + tekilleştirilmiş
    // (kurallar için yazılıyor); yoksa `serviceAreas` içinden çıkarılır —
    // eski kayıtlarda o alan olmayabilir.
    final provList = (m['serviceProvinces'] as List?)
        ?.map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (provList != null && provList.isNotEmpty) {
      for (final p in provList) {
        bump(artProv, p);
      }
    } else {
      final areas = (m['serviceAreas'] as List?) ?? const [];
      final tekil = <String>{};
      for (final a in areas) {
        if (a is Map && a['province'] != null) {
          final p = a['province'].toString().trim();
          if (p.isNotEmpty) tekil.add(p);
        }
      }
      for (final p in tekil) {
        bump(artProv, p);
      }
    }
    if (m['isVerified'] == true) artVer++;
    if (m['adminVerified'] == true) artAdmin++;
    if (m['featured'] == true) artFeat++;
    if (m['isPremium'] == true) artPrem++;
    if (m['certificateStatus'] == 'pending') artCert++;
    if (m['moderationHidden'] == true) artHide++;
  }

  final prodCat = <String, int>{};
  final prodSt = <String, int>{};
  var prodPend = 0;
  var prodHide = 0;
  var prodAct = 0;
  for (final m in products) {
    bump(prodCat, m['categoryCode'] as String?);
    final st = (m['status'] as String?) ?? '';
    bump(prodSt, st);
    if (st == 'pending_review') prodPend++;
    if (st == 'active') prodAct++;
    if (m['moderationHidden'] == true) prodHide++;
  }

  var uArt = 0;
  var uPhone = 0;
  var uSus = 0;
  var u7 = 0;
  for (final m in users) {
    if (m['hasArtisanProfile'] == true) uArt++;
    if (m['phoneVerified'] == true) uPhone++;
    if (m['suspended'] == true) uSus++;
    final created = DateTime.tryParse(m['createdAt']?.toString() ?? '');
    if (created != null && !created.toUtc().isBefore(weekAgo)) u7++;
  }

  return AdminInsights(
    generatedAt: t,
    jobsSampled: jobs.length,
    artisansSampled: artisans.length,
    productsSampled: products.length,
    usersSampled: users.length,
    jobProvinces: rankCounts(jobProv, labelOf: (k) => k, top: 10),
    jobCategories: rankCounts(jobCat, labelOf: professionLabel, top: 10),
    jobStatus: rankCounts(jobSt, labelOf: jobStatusLabel, top: 8),
    jobsLast7d: jobs7,
    jobsOpenInSample: jobsOpen,
    artisanProfessions: rankCounts(artProf, labelOf: professionLabel, top: 10),
    artisanProvinces: rankCounts(artProv, labelOf: (k) => k, top: 10),
    artisansVerified: artVer,
    artisansAdminVerified: artAdmin,
    artisansFeatured: artFeat,
    artisansPremium: artPrem,
    artisansCertPending: artCert,
    artisansHidden: artHide,
    productCategories: rankCounts(
      prodCat,
      labelOf: productCategoryLabel,
      top: 10,
    ),
    productStatus: rankCounts(prodSt, labelOf: productStatusLabel, top: 8),
    productsPendingReview: prodPend,
    productsHidden: prodHide,
    productsActive: prodAct,
    usersWithArtisan: uArt,
    usersPhoneVerified: uPhone,
    usersSuspended: uSus,
    usersLast7d: u7,
  );
}

abstract interface class AdminInsightsRepository {
  /// Son kayıtlar üzerinden dağılım toplar. [sampleSize] üst sınır (koleksiyon başına).
  Future<AdminInsights> fetchInsights({int sampleSize = 400});
}

class FirebaseAdminInsightsRepository implements AdminInsightsRepository {
  FirebaseAdminInsightsRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<AdminInsights> fetchInsights({int sampleSize = 400}) async {
    final limit = sampleSize.clamp(50, 800);

    Future<List<Map<String, dynamic>>> sample(String col) async {
      try {
        final snap = await _db
            .collection(col)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        return [for (final d in snap.docs) d.data()];
      } catch (_) {
        // createdAt indeksi/alanı bozuksa documentId ile dene.
        try {
          final snap = await _db.collection(col).limit(limit).get();
          return [for (final d in snap.docs) d.data()];
        } catch (_) {
          return const [];
        }
      }
    }

    final results = await Future.wait([
      sample('jobs'),
      sample('artisanProfiles'),
      sample('products'),
      sample('users'),
    ]);

    return buildInsightsFromSamples(
      jobs: results[0],
      artisans: results[1],
      products: results[2],
      users: results[3],
      professionLabel: (c) => kProfessionNames[c] ?? c,
      productCategoryLabel: ProductCategory.label,
      jobStatusLabel: _jobStatusLabel,
      productStatusLabel: _productStatusLabel,
    );
  }

  static String _jobStatusLabel(String s) => switch (s) {
        'open' => 'Açık',
        'cancelled' => 'İptal',
        'expired' => 'Süresi doldu',
        '' => 'Boş',
        _ => s,
      };

  static String _productStatusLabel(String s) => switch (s) {
        'draft' => 'Taslak',
        'pending_review' => 'İncelemede',
        'active' => 'Yayında',
        'paused' => 'Duraklatıldı',
        'sold' => 'Satıldı',
        'removed' => 'Kaldırıldı',
        'out_of_stock' => 'Stokta yok',
        '' => 'Boş',
        _ => s,
      };
}

/// Test / mock: seed haritalarla anında sonuç.
class MockAdminInsightsRepository implements AdminInsightsRepository {
  MockAdminInsightsRepository({this.seed});

  AdminInsights? seed;
  final List<Map<String, dynamic>> jobs = [];
  final List<Map<String, dynamic>> artisans = [];
  final List<Map<String, dynamic>> products = [];
  final List<Map<String, dynamic>> users = [];

  @override
  Future<AdminInsights> fetchInsights({int sampleSize = 400}) async {
    if (seed != null) return seed!;
    return buildInsightsFromSamples(
      jobs: jobs.take(sampleSize).toList(),
      artisans: artisans.take(sampleSize).toList(),
      products: products.take(sampleSize).toList(),
      users: users.take(sampleSize).toList(),
      professionLabel: (c) => c,
      productCategoryLabel: (c) => c,
      jobStatusLabel: (s) => s,
      productStatusLabel: (s) => s,
    );
  }
}
