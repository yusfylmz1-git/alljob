/// Server `assertCap` ile aynı üç durum (PR7c).
///
/// - superadmin → hepsi
/// - capabilities alanı yok → [defaultModerator] (enforce)
/// - explicit liste (boş dizi = kilitli)
class AdminCapabilities {
  const AdminCapabilities({
    required this.isSuperAdmin,
    required this.capsFieldMissing,
    required this.caps,
    this.enforceMode = true,
  });

  final bool isSuperAdmin;
  final bool capsFieldMissing;
  final Set<String> caps;

  /// false = log-only geçiş (menü full); true = PR7c+
  final bool enforceMode;

  /// CF `DEFAULT_MODERATOR_CAPABILITIES` paritesi.
  static const Set<String> defaultModerator = {
    'reports.manage',
    'disputes.manage',
    'users.read',
    'users.suspend',
    'jobs.read',
    'jobs.moderate',
    'artisans.read',
    'artisans.moderate',
    'reviews.moderate',
    'stats.read',
  };

  /// Tüm bilinen yetki kodları (UI checkbox).
  static const List<String> allCodes = [
    'reports.manage',
    'disputes.manage',
    'users.read',
    'users.suspend',
    'jobs.read',
    'jobs.moderate',
    'artisans.read',
    'artisans.moderate',
    'reviews.moderate',
    'stats.read',
    'chats.read',
    'audit.read',
    'staff.manage',
    'config.manage',
    'export.run',
  ];

  static String labelTR(String code) => switch (code) {
        'reports.manage' => 'Şikayet yönetimi',
        'disputes.manage' => 'Anlaşmazlık hakemliği',
        'users.read' => 'Kullanıcı okuma',
        'users.suspend' => 'Kullanıcı askıya alma',
        'jobs.read' => 'İlan okuma',
        'jobs.moderate' => 'İlan moderasyonu',
        'artisans.read' => 'Usta okuma',
        'artisans.moderate' => 'Usta moderasyonu',
        'reviews.moderate' => 'Değerlendirme gizleme',
        'stats.read' => 'İstatistik',
        'chats.read' => 'Sohbet kanıtı (opt-in)',
        'audit.read' => 'Denetim kaydı',
        'staff.manage' => 'Kadro / davet',
        'config.manage' => 'Ayarlar',
        'export.run' => 'Dışa aktarım',
        _ => code,
      };

  bool allows(String c) {
    if (isSuperAdmin) return true;
    if (capsFieldMissing) {
      return enforceMode ? defaultModerator.contains(c) : true;
    }
    return caps.contains(c);
  }

  factory AdminCapabilities.superAdmin() => const AdminCapabilities(
        isSuperAdmin: true,
        capsFieldMissing: false,
        caps: {},
      );

  factory AdminCapabilities.fromRoster({
    required bool isSuperAdmin,
    List<String>? capabilities,
    bool enforceMode = true,
  }) {
    if (isSuperAdmin) return AdminCapabilities.superAdmin();
    if (capabilities == null) {
      return AdminCapabilities(
        isSuperAdmin: false,
        capsFieldMissing: true,
        caps: const {},
        enforceMode: enforceMode,
      );
    }
    return AdminCapabilities(
      isSuperAdmin: false,
      capsFieldMissing: false,
      caps: capabilities.toSet(),
      enforceMode: enforceMode,
    );
  }
}
