import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/artisan_profile.dart';
import '../../auth/application/auth_controller.dart';
import 'my_profile_controller.dart';

/// Müsait olmayan sağlayıcının (usta / mağaza) **yeni** sohbet başlatmasını
/// engelleyen ortak kapı.
///
/// Neden ortak: sohbeti başlatan girişler — ilan detayı, usta profili, genel
/// kullanıcı profili, ürün detayı. Kapı birinde unutulursa müsait olmayan
/// kişi diğerinden yazabiliyordu.
///
/// ⚠️ Yeni bir sohbet girişi eklersen BU KAPIYI ÇAĞIR.
///
/// Kapsam:
///  - **Usta veya mağaza profili** açmış herkes (aktif "usta modu" şart değil —
///    İlanlar sekmesi `hasArtisanProfile` ile açılır).
///  - Yalnız **YENİ** sohbet. Mesajlar’daki mevcut sohbetler sürer.
///
/// `true` → devam. `false` → bırak (kullanıcıya sebep gösterildi).
bool artisanAvailabilityAllowsNewChat(BuildContext context, WidgetRef ref) {
  final user = ref.read(currentUserProvider);
  if (user == null) return true;

  // Ne usta ne mağaza: müşteri gibi davranır, kapı yok.
  if (!user.hasArtisanProfile && !user.hasShopProfile) return true;

  final draft = ref.read(myProfileControllerProvider).valueOrNull;
  if (providerMayStartNewChat(user: user, profile: draft?.profile)) {
    return true;
  }

  context.showInfo(
    'Şu an "müsait değil" görünüyorsunuz. Yeni mesaj başlatmak için '
    'Profil’den “Müsait” durumunu açın. Mevcut sohbetleriniz etkilenmez.',
  );
  return false;
}

/// Sağlayıcı (usta / satıcı) yeni iş–talep–vitrin sohbeti başlatabilir mi?
///
/// İki kaynak **birlikte** bakılır (desenkron tuzağı):
///  1. `users.available` — profil anahtarının ortak aynası
///  2. `artisanProfiles` müsaitliği — `manualPause` / takvim / premium
///
/// Biri kapalıysa mesaj yok. Profil henüz yüklenmediyse yalnız
/// `users.available` yeter (anahtar her zaman onu da yazar).
bool providerMayStartNewChat({
  required AppUser user,
  ArtisanProfile? profile,
}) {
  if (!user.hasArtisanProfile && !user.hasShopProfile) return true;
  if (!user.available) return false;
  if (user.hasArtisanProfile &&
      profile != null &&
      !profile.isAvailable) {
    return false;
  }
  return true;
}

/// UI: müsait değil uyarısı gösterilsin mi? (buton gizle)
bool providerIsUnavailableForNewChat({
  required AppUser? user,
  ArtisanProfile? profile,
}) {
  if (user == null) return false;
  if (!user.hasArtisanProfile && !user.hasShopProfile) return false;
  return !providerMayStartNewChat(user: user, profile: profile);
}
