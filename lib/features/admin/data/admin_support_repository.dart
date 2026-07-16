import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Destek talebi (supportTickets).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.uid,
    required this.subject,
    required this.body,
    required this.status,
    required this.createdAt,
    this.email,
    this.category = 'general',
    this.adminNote,
    this.resolvedBy,
    this.resolvedAt,
  });

  final String id;
  final String uid;
  final String? email;
  final String subject;
  final String body;
  final String category;
  final String status; // open | in_progress | resolved | closed
  final String? adminNote;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  bool get isOpen => status == 'open' || status == 'in_progress';

  factory SupportTicket.fromMap(String id, Map<String, dynamic> map) {
    return SupportTicket(
      id: id,
      uid: (map['uid'] as String?) ?? '',
      email: map['email'] as String?,
      subject: (map['subject'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'general',
      status: (map['status'] as String?) ?? 'open',
      adminNote: map['adminNote'] as String?,
      resolvedBy: map['resolvedBy'] as String?,
      resolvedAt: DateTime.tryParse(map['resolvedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AdminSupportRepository {
  AdminSupportRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<List<SupportTicket>> watchTickets({bool openOnly = true}) {
    Query<Map<String, dynamic>> q = _db
        .collection('supportTickets')
        .orderBy('createdAt', descending: true)
        .limit(100);
    // openOnly: istemci süzmesi (çoklu status için OR indeksi yok)
    return q.snapshots().map((snap) {
      var list = snap.docs
          .map((d) => SupportTicket.fromMap(d.id, d.data()))
          .toList();
      if (openOnly) {
        list = list.where((t) => t.isOpen).toList();
      }
      return list;
    });
  }

  Future<void> updateTicket({
    required String ticketId,
    required String status,
    String? adminNote,
  }) async {
    await _functions.httpsCallable('adminUpdateSupportTicket').call({
      'ticketId': ticketId,
      'status': status,
      'adminNote': ?adminNote,
    });
  }
}

/// Kullanıcı tarafı talep oluşturma.
class SupportTicketClient {
  SupportTicketClient({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String> create({
    required String subject,
    required String body,
    String category = 'general',
  }) async {
    final res = await _functions.httpsCallable('createSupportTicket').call({
      'subject': subject,
      'body': body,
      'category': category,
    });
    final data = res.data;
    if (data is Map && data['ticketId'] is String) {
      return data['ticketId'] as String;
    }
    return '';
  }
}
