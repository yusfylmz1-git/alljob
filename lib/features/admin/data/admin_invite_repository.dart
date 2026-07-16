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
        createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        expiresAt: m['expiresAt'] != null
            ? DateTime.tryParse(m['expiresAt'].toString())
            : null,
        createdBy: m['createdBy'] as String?,
        acceptedByUid: m['acceptedByUid'] as String?,
      );
}

abstract interface class AdminInviteRepository {
  Stream<List<AdminInvite>> watchPending();
  Future<String> create({
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
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

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
        .map((snap) => snap.docs
            .map((d) => AdminInvite.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Future<String> create({
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
      return data['inviteId'].toString();
    }
    return '';
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

  List<AdminInvite> _pending() => _items.values
      .where((i) => i.isPending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<String> create({
    required String email,
    List<String>? capabilities,
    int expiresInDays = 7,
  }) async {
    final id = 'inv_${++_seq}';
    final e = email.trim().toLowerCase();
    for (final x in _items.values.where(
        (i) => i.email == e && i.isPending)) {
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
    return id;
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
