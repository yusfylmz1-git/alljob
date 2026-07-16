import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// ScheduledCampaign + AdminBroadcastRepository aşağıda.

/// `adminConfig/runtime` — bayraklar + platform içeriği (marka, duyuru, destek).
class AdminRuntimeConfig {
  const AdminRuntimeConfig({
    this.premiumFreeDuringBeta = true,
    this.maintenanceMode = false,
    this.minAppVersion,
    this.appDisplayName,
    this.tagline,
    this.supportEmail,
    this.supportPhone,
    this.playStoreUrl,
    this.appStoreUrl,
    this.websiteUrl,
    this.logoUrl,
    this.aboutShort,
    this.announcementEnabled = false,
    this.announcementTitle,
    this.announcementBody,
    this.announcementCtaLabel,
    this.announcementCtaUrl,
    this.updatedAt,
    this.updatedBy,
  });

  final bool premiumFreeDuringBeta;
  final bool maintenanceMode;
  final String? minAppVersion;

  final String? appDisplayName;
  final String? tagline;
  final String? supportEmail;
  final String? supportPhone;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? websiteUrl;
  final String? logoUrl;
  final String? aboutShort;

  final bool announcementEnabled;
  final String? announcementTitle;
  final String? announcementBody;
  final String? announcementCtaLabel;
  final String? announcementCtaUrl;

  final DateTime? updatedAt;
  final String? updatedBy;

  factory AdminRuntimeConfig.fromMap(Map<String, dynamic> map) {
    String? s(String k) {
      final v = map[k];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    return AdminRuntimeConfig(
      premiumFreeDuringBeta: map['premiumFreeDuringBeta'] != false,
      maintenanceMode: map['maintenanceMode'] == true,
      minAppVersion: s('minAppVersion'),
      appDisplayName: s('appDisplayName'),
      tagline: s('tagline'),
      supportEmail: s('supportEmail'),
      supportPhone: s('supportPhone'),
      playStoreUrl: s('playStoreUrl'),
      appStoreUrl: s('appStoreUrl'),
      websiteUrl: s('websiteUrl'),
      logoUrl: s('logoUrl'),
      aboutShort: s('aboutShort'),
      announcementEnabled: map['announcementEnabled'] == true,
      announcementTitle: s('announcementTitle'),
      announcementBody: s('announcementBody'),
      announcementCtaLabel: s('announcementCtaLabel'),
      announcementCtaUrl: s('announcementCtaUrl'),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
      updatedBy: map['updatedBy'] as String?,
    );
  }
}

abstract interface class AdminRuntimeConfigRepository {
  Stream<AdminRuntimeConfig> watchRuntime();
  Future<void> update(Map<String, dynamic> patch);
}

class FirebaseAdminRuntimeConfigRepository
    implements AdminRuntimeConfigRepository {
  FirebaseAdminRuntimeConfigRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('adminConfig').doc('runtime');

  @override
  Stream<AdminRuntimeConfig> watchRuntime() {
    return _ref.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return const AdminRuntimeConfig();
      }
      return AdminRuntimeConfig.fromMap(snap.data()!);
    });
  }

  @override
  Future<void> update(Map<String, dynamic> patch) async {
    if (patch.isEmpty) return;
    await _functions.httpsCallable('adminUpdateConfig').call<Object?>(patch);
  }
}

/// Bellek-içi (test / mock backend).
class MockAdminRuntimeConfigRepository
    implements AdminRuntimeConfigRepository {
  MockAdminRuntimeConfigRepository([AdminRuntimeConfig? seed])
      : _config = seed ?? const AdminRuntimeConfig();

  AdminRuntimeConfig _config;
  final _changes = StreamController<AdminRuntimeConfig>.broadcast();

  @override
  Stream<AdminRuntimeConfig> watchRuntime() async* {
    yield _config;
    yield* _changes.stream;
  }

  @override
  Future<void> update(Map<String, dynamic> patch) async {
    final m = <String, dynamic>{
      'premiumFreeDuringBeta': _config.premiumFreeDuringBeta,
      'maintenanceMode': _config.maintenanceMode,
      'minAppVersion': _config.minAppVersion,
      'appDisplayName': _config.appDisplayName,
      'tagline': _config.tagline,
      'supportEmail': _config.supportEmail,
      'supportPhone': _config.supportPhone,
      'playStoreUrl': _config.playStoreUrl,
      'appStoreUrl': _config.appStoreUrl,
      'websiteUrl': _config.websiteUrl,
      'logoUrl': _config.logoUrl,
      'aboutShort': _config.aboutShort,
      'announcementEnabled': _config.announcementEnabled,
      'announcementTitle': _config.announcementTitle,
      'announcementBody': _config.announcementBody,
      'announcementCtaLabel': _config.announcementCtaLabel,
      'announcementCtaUrl': _config.announcementCtaUrl,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': 'mock',
    };
    for (final e in patch.entries) {
      m[e.key] = e.value;
    }
    _config = AdminRuntimeConfig.fromMap(m);
    if (!_changes.isClosed) _changes.add(_config);
  }

  void dispose() => _changes.close();
}

/// Toplu bildirim + zamanlanmış kampanya.
class AdminBroadcastRepository {
  AdminBroadcastRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1'),
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  Map<String, dynamic> _payload({
    required String title,
    required String body,
    required String audience,
    bool sendPush = true,
    String? profession,
    String? province,
  }) =>
      {
        'title': title,
        'body': body,
        'audience': audience,
        'sendPush': sendPush,
        if (profession != null && profession.isNotEmpty) 'profession': profession,
        if (province != null && province.isNotEmpty) 'province': province,
      };

  /// Anında gönder.
  Future<Map<String, dynamic>> send({
    required String title,
    required String body,
    required String audience,
    bool sendPush = true,
    String? profession,
    String? province,
  }) async {
    final res = await _functions
        .httpsCallable('adminBroadcastNotification')
        .call<Object?>(_payload(
          title: title,
          body: body,
          audience: audience,
          sendPush: sendPush,
          profession: profession,
          province: province,
        ));
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'ok': true};
  }

  /// Zamanla (ISO UTC).
  Future<Map<String, dynamic>> schedule({
    required String title,
    required String body,
    required String audience,
    required DateTime scheduledAt,
    bool sendPush = true,
    String? profession,
    String? province,
  }) async {
    final res = await _functions
        .httpsCallable('adminScheduleCampaign')
        .call<Object?>({
      ..._payload(
        title: title,
        body: body,
        audience: audience,
        sendPush: sendPush,
        profession: profession,
        province: province,
      ),
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'ok': true};
  }

  Future<void> cancel(String campaignId) async {
    await _functions.httpsCallable('adminCancelCampaign').call({
      'campaignId': campaignId,
    });
  }

  Stream<List<ScheduledCampaign>> watchCampaigns({int limit = 40}) {
    return _db
        .collection('scheduledCampaigns')
        .orderBy('scheduledAtMs', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ScheduledCampaign.fromMap(d.id, d.data()))
            .toList());
  }
}

class ScheduledCampaign {
  const ScheduledCampaign({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.status,
    required this.scheduledAt,
    this.sendPush = false,
    this.profession,
    this.province,
    this.recipients,
    this.error,
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final String status; // pending | processing | sent | failed | cancelled
  final DateTime scheduledAt;
  final bool sendPush;
  final String? profession;
  final String? province;
  final int? recipients;
  final String? error;

  bool get isPending => status == 'pending';

  factory ScheduledCampaign.fromMap(String id, Map<String, dynamic> map) {
    final result = map['result'];
    int? rec;
    if (result is Map && result['recipients'] is num) {
      rec = (result['recipients'] as num).toInt();
    }
    return ScheduledCampaign(
      id: id,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      audience: (map['audience'] as String?) ?? 'all',
      status: (map['status'] as String?) ?? 'pending',
      scheduledAt: DateTime.tryParse(map['scheduledAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(
              (map['scheduledAtMs'] as num?)?.toInt() ?? 0),
      sendPush: map['sendPush'] == true,
      profession: map['profession'] as String?,
      province: map['province'] as String?,
      recipients: rec,
      error: map['error'] as String?,
    );
  }
}
