import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abonelik / plan katmanı (MVP — faturalama sonraki sprint).
enum MembershipPackage {
  free,
  beta,
  pro;

  String get id => name;

  String get titleTR => switch (this) {
        MembershipPackage.free => 'Ücretsiz',
        MembershipPackage.beta => 'Beta',
        MembershipPackage.pro => 'Pro',
      };

  String get priceTR => switch (this) {
        MembershipPackage.free => '₺0',
        MembershipPackage.beta => '₺0',
        MembershipPackage.pro => 'Play',
      };

  String get priceSuffixTR => switch (this) {
        MembershipPackage.free => '/ay',
        MembershipPackage.beta => ' · beta',
        MembershipPackage.pro => ' abonelik',
      };

  String get ctaTR => switch (this) {
        MembershipPackage.free => 'Ücretsiz devam et',
        MembershipPackage.beta => 'Beta ile devam et',
        MembershipPackage.pro => 'Pro — Play’de abone ol',
      };

  /// Profil satırı alt yazısı.
  String get summaryTR => switch (this) {
        MembershipPackage.free => 'Temel kullanım · ₺0',
        MembershipPackage.beta => 'Pro özellikler açık · beta · ₺0',
        MembershipPackage.pro => 'Google Play aboneliği',
      };

  List<String> get featuresTR => switch (this) {
        MembershipPackage.free => const [
            'Keşfet ve usta profilleri',
            'İş ilanı ver',
            'Güvenli sohbet',
            'Favoriler ve bildirimler',
          ],
        MembershipPackage.beta => const [
            'Ücretsiz paketteki her şey',
            'Usta Pro özellikleri açık',
            'Müsaitlik ve yakındaki işler',
            'Vitrin ve Hızlı Destek',
            'Beta süresince ücret yok',
          ],
        MembershipPackage.pro => const [
            'Beta’daki tüm Pro özellikler',
            'Öne çıkan usta rozeti (ödemeli)',
            'Sunucu doğrulamalı abonelik',
            'Google Play üzerinden yenilenir',
          ],
      };

  static MembershipPackage? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final p in MembershipPackage.values) {
      if (p.id == raw) return p;
    }
    return null;
  }
}

const _kPackageSeenKey = 'membership_package_seen_v1';
const _kPackageIdKey = 'membership_package_id_v1';

/// Paket seçim ekranı görüldü mü? Varsayılan true (testler / override’sız akış).
final packageSelectionSeenProvider = StateProvider<bool>((_) => true);

/// Seçili paket (null = henüz seçilmedi).
final selectedMembershipPackageProvider =
    StateProvider<MembershipPackage?>((_) => null);

Future<bool> readPackageSelectionSeen() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kPackageSeenKey) ?? false;
  } catch (_) {
    return true;
  }
}

Future<MembershipPackage?> readSelectedMembershipPackage() async {
  try {
    final p = await SharedPreferences.getInstance();
    return MembershipPackage.tryParse(p.getString(_kPackageIdKey));
  } catch (_) {
    return null;
  }
}

Future<void> saveMembershipPackage(MembershipPackage package) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPackageSeenKey, true);
    await p.setString(_kPackageIdKey, package.id);
  } catch (_) {/* ignore */}
}
