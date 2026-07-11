/// Engellenen kullanıcı kaydı — `users/{uid}/blocked/{otherUid}` dökümanı.
/// Ad/foto, engelleme anındaki SNAPSHOT'tır (yönetim ekranında ekstra okuma
/// yapmamak için); kullanıcı adını değiştirse de burada eski ad kalabilir.
class BlockedUser {
  const BlockedUser({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.blockedAt,
  });

  /// Engellenen kullanıcının uid'i (döküman ID'si ile aynı).
  final String uid;
  final String name;
  final String? photoUrl;
  final DateTime blockedAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'photoURL': photoUrl,
        'blockedAt': blockedAt.toIso8601String(),
      };

  factory BlockedUser.fromMap(String uid, Map<String, dynamic> map) =>
      BlockedUser(
        uid: uid,
        name: (map['name'] as String?) ?? '',
        photoUrl: map['photoURL'] as String?,
        blockedAt: DateTime.tryParse(map['blockedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}
