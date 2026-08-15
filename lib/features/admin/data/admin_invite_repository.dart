import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// `adminInvites/{id}` satırı.
class AdminInvite {
  const AdminInvite({
    required this.id,
    required this.email,
    required this.status,
    required this.capabilities,
    required this.createdAt,
    this.expiresAt,
    this.createdBy,
    this.acceptedByUid,
  });

  final String id;
  final String email;
  final String status; // pending|accepted|revoked|expired
  final List<String> capabilities;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? createdBy;
  final String? acceptedByUid;

  bool get isPending => status == 'pending';

  factory AdminInvite.fromMap(String id, Map<String, dynamic> m) => AdminInvite(
    id: id,
    email: (m['email'] ?? m['emailNormalized'] ?? '') as String,
    status: (m['status'] ?? 'pending') as String,
    capabilities: ((m['capabilities'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    createdAt:
        DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
    expiresAt: m['expiresAt'] != null
        ? DateTime.tryParse(m['expiresAt'].toString())
        : null,
    createdBy: m['createdBy'] as String?,
    acceptedByUid: m['acceptedByUid'] as String?,
  );
}

/// Davet oluşturmanın sonucu.
///
/// [passwordSetupLink] davet edilen kişinin ŞİFRESİNİ BELİRLEYECEĞİ tek
/// kullanımlık bağlantıdır. Sunucu bunu yalnız çağrının yanıtında döndürür;
/// Firestore'a YAZILMAZ — yazılsaydı koleksiyonu okuyabilen herkes hesabı
/// ele geçirebilirdi. Bu yüzden ekranda bir kez gösterilir ve süperadmin
/// tarafından iletilir.
class AdminInviteResult {
  const AdminInviteResult({
    required this.inviteId,
    required this.email,
    this.passwordSetupLink,
    this.accountCreated = false,
  });

  final String inviteId;
  final String email;

  /// Şifre belirleme bağlantısı (yalnız bu yanıtta gelir).
  final String? passwordSetupLink;

  /// true: Auth hesabı bu davetle YENİ açıldı. false: e-posta zaten kayıtlıydı
  /// (ör. uygulamayı kullanan biri moderatör yapılıyor).
  final bool accountCreated;
}

abstract interface class AdminInviteRepository {
  Stream<List<AdminInvite>> watchPending();
  Future<AdminInviteResult> create({
    required String email,
    List<String>? capabilities,
    int expiresInDays = 7,
  });
  Future<void> revoke(String inviteId);
  Future<void> accept();
}

class FirebaseAdminInviteRepository implements AdminInviteRepository {
  FirebaseAdminInviteRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<AdminInvite>> watchPending() {
    return _db
        .collection('adminInvites')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AdminInvite.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<AdminInviteResult> create({
    required String email,
    List<String>? capabilities,
    int expiresInDays = 7,
  }) async {
    final payload = <String, dynamic>{
      'email': email.trim(),
      'expiresInDays': expiresInDays,
    };
    if (capabilities != null) payload['capabilities'] = capabilities;
    final res = await _functions
        .httpsCallable('adminCreateInvite')
        .call<Object?>(payload);
    final data = res.data;
    if (data is Map && data['inviteId'] != null) {
      return AdminInviteResult(
        inviteId: data['inviteId'].toString(),
        email: (data['email'] ?? email.trim()).toString(),
        passwordSetupLink: data['passwordSetupLink']?.toString(),
        accountCreated: data['accountCreated'] == true,
      );
    }
    return AdminInviteResult(inviteId: '', email: email.trim());
  }

  @override
  Future<void> revoke(String inviteId) async {
    await _functions.httpsCallable('adminRevokeInvite').call<Object?>({
      'inviteId': inviteId,
    });
  }

  @override
  Future<void> accept() async {
    await _functions.httpsCallable('adminAcceptInvite').call<Object?>({});
  }
}

class MockAdminInviteRepository implements AdminInviteRepository {
  final Map<String, AdminInvite> _items = {};
  final _changes = StreamController<void>.broadcast();
  int _seq = 0;

  @override
  Stream<List<AdminInvite>> watchPending() async* {
    yield _pending();
    await for (final _ in _changes.stream) {
      yield _pending();
    }
  }

  List<AdminInvite> _pending() =>
      _items.values.where((i) => i.isPending).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<AdminInviteResult> create({
    required String email,
    List<String>? capabilities,
    int expiresInDays = 7,
  }) async {
    final id = 'inv_${++_seq}';
    final e = email.trim().toLowerCase();
    for (final x in _items.values.where((i) => i.email == e && i.isPending)) {
      _items[x.id] = AdminInvite(
        id: x.id,
        email: x.email,
        status: 'revoked',
        capabilities: x.capabilities,
        createdAt: x.createdAt,
        expiresAt: x.expiresAt,
        createdBy: x.createdBy,
      );
    }
    final now = DateTime.now();
    _items[id] = AdminInvite(
      id: id,
      email: e,
      status: 'pending',
      capabilities: capabilities ?? const [],
      createdAt: now,
      expiresAt: now.add(Duration(days: expiresInDays)),
      createdBy: 'sa',
    );
    if (!_changes.isClosed) _changes.add(null);
    // Mock paritesi: canlıda sunucu şifre belirleme bağlantısı döndürür.
    // Gerçek bağlantı üretilemez, ama alanın DOLU gelmesi ekranın "bağlantı
    // yok" dalına düşmemesini sağlar — testler gerçek akışı görür.
    return AdminInviteResult(
      inviteId: id,
      email: e,
      passwordSetupLink: 'https://example.invalid/sifre-belirle?mock=$id',
      accountCreated: true,
    );
  }

  @override
  Future<void> revoke(String inviteId) async {
    final x = _items[inviteId];
    if (x == null) return;
    _items[inviteId] = AdminInvite(
      id: x.id,
      email: x.email,
      status: 'revoked',
      capabilities: x.capabilities,
      createdAt: x.createdAt,
      expiresAt: x.expiresAt,
      createdBy: x.createdBy,
    );
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> accept() async {
    // Mock: no-op (auth flow tests ayrı).
  }

  void dispose() => _changes.close();
}
