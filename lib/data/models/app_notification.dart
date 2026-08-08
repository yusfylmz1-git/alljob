/// `users/{uid}/notifications` alt-koleksiyonundaki uygulama içi bildirim.
///
/// Kayıtları YALNIZCA Cloud Functions yazar (push ile birlikte, ondan
/// bağımsız); istemci sadece okur ve `read` alanını true yapabilir (kural).
/// Döküman ID'si kaynağa göre deterministiktir (`chat_{chatId}`,
/// `job_{jobId}`) — aynı kaynağın yeni olayı eski kaydın üzerine yazar,
/// böylece liste Instagram tarzı kompakt kalır (sohbet/ilan başına tek satır).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    this.actorUid,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.chatId,
    this.jobId,
  });

  final String id;
  final String type; // 'chat' | 'job' | 'system' | 'follow'
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  final String? chatId; // type == 'chat'
  final String? jobId; // type == 'job'

  /// Takip bildiriminde takip EDENİN uid'i (type == 'follow') — dokununca
  /// onun profili açılır.
  final String? actorUid;

  bool get isChat => type == 'chat';
  bool get isFollow => type == 'follow';

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: (map['type'] as String?) ?? 'system',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      read: (map['read'] as bool?) ?? false,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      chatId: map['chatId'] as String?,
      jobId: map['jobId'] as String?,
      actorUid: map['actorUid'] as String?,
    );
  }

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        read: read ?? this.read,
        createdAt: createdAt,
        chatId: chatId,
        jobId: jobId,
      );
}
