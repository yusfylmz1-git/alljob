import 'user_role.dart';

/// `users` koleksiyonundaki kullanıcı dökümanı.
/// Döküman ID'si = Firebase Auth UID.
///
/// Tek hesap, çift rol: [hasArtisanProfile] kullanıcının usta profili açıp
/// açmadığını (kalıcı yetenek), [activeMode] ise arayüzün hangi modda
/// gösterileceğini (istenildiğinde değiştirilebilir tercih) tutar.
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.hasArtisanProfile = false,
    this.activeMode = UserRole.customer,
    this.phoneNumber,
    this.profilePhotoUrl,
  });

  final String uid;
  final String displayName;
  final String email;
  final DateTime createdAt;

  /// "Hizmet Vermeye Başla" tamamlandı mı? Usta moduna geçişin ön şartı.
  final bool hasArtisanProfile;

  /// Aktif arayüz modu. Usta modu yalnızca [hasArtisanProfile] ise geçerlidir.
  final UserRole activeMode;

  /// Yalnızca ustalar için; müşteriye asla gösterilmez (PRD §6).
  final String? phoneNumber;
  final String? profilePhotoUrl;

  /// Arayüz şu an usta modunda mı? (UI kapıları bunu kullanır.)
  bool get isArtisan => activeMode == UserRole.artisan;
  bool get isCustomer => activeMode == UserRole.customer;

  AppUser copyWith({
    String? displayName,
    String? phoneNumber,
    String? profilePhotoUrl,
    bool? hasArtisanProfile,
    UserRole? activeMode,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      createdAt: createdAt,
      hasArtisanProfile: hasArtisanProfile ?? this.hasArtisanProfile,
      activeMode: activeMode ?? this.activeMode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'hasArtisanProfile': hasArtisanProfile,
        'activeMode': activeMode.apiValue,
        // Geriye dönük uyum: eski istemciler `role` okur.
        'role': activeMode.apiValue,
        'createdAt': createdAt.toIso8601String(),
        'phoneNumber': phoneNumber,
        'profilePhotoURL': profilePhotoUrl,
      };

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    // Eski kayıtlar: kalıcı `role` alanı → usta ise profil var + usta modu.
    final legacyRole = UserRole.fromString(map['role'] as String?);
    return AppUser(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      hasArtisanProfile: (map['hasArtisanProfile'] as bool?) ??
          (legacyRole == UserRole.artisan),
      activeMode: UserRole.fromString(map['activeMode'] as String?) ??
          legacyRole ??
          UserRole.customer,
      createdAt: _parseDate(map['createdAt']),
      phoneNumber: map['phoneNumber'] as String?,
      profilePhotoUrl: map['profilePhotoURL'] as String?,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
