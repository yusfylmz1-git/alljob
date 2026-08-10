import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/snackbar_helper.dart';
import '../../auth/application/auth_controller.dart';
import 'my_profile_controller.dart';

/// Müsait olmayan USTANIN yeni sohbet başlatmasını engelleyen ortak kapı.
///
/// Neden ortak: sohbeti başlatan **DÖRT** giriş var — ilan detayı, usta
/// profili, genel kullanıcı profili ve **ürün detayı** (Mağaza). Kapı önce
/// yalnız ilan detayındaydı ve diğerleri onu atlıyordu: müsait olmayan usta
/// ilanı görüp mesaj atamıyor, ama ilandaki avatara dokunup profile geçince
/// oradan yazabiliyordu (2026-08-10 bulgusu).
///
/// Ürün detayı SONRADAN eklendi (aynı gün): Mağaza modülü geri getirildiğinde
/// kapısız geldi, çünkü kapı kurulduğu sırada o modül üründe yoktu. Müsait
/// olmayan usta ilandan yazamayıp Mağaza'dan aynı kişiye yazabiliyordu.
///
/// ⚠️ Yeni bir sohbet girişi eklersen BU KAPIYI ÇAĞIR. Regresyon testi
/// `startChat` çağrı sayısını sayar — kapısız bir giriş eklenirse kırılır.
///
/// Kapının doğru yeri gezinme DEĞİL, eylemdir. Profili gizlemek deliği
/// kapatmaz (arama, favoriler, mevcut sohbet hep aynı kişiye götürür) ve
/// meşru bir bilgiyi — ilanı kimin verdiğini — gereksizce saklardı.
///
/// Kapsam bilinçli olarak dar:
///  - Yalnız **usta modundaki** kullanıcıyı bağlar; müşterinin müsaitlik
///    kavramı yoktur.
///  - Yalnız **YENİ** sohbeti engeller. Var olan sohbetler Mesajlar
///    sekmesinden sürer — müsaitlik "yeni iş almıyorum" demektir,
///    "kimseyle konuşmuyorum" değil.
///
/// `true` → devam edilebilir. `false` → çağıran işlemi bırakmalı
/// (kullanıcıya sebep zaten gösterildi).
bool artisanAvailabilityAllowsNewChat(BuildContext context, WidgetRef ref) {
  final user = ref.read(currentUserProvider);
  // Müşteri modu: kapı yok.
  if (user == null || !user.isArtisan) return true;

  final draft = ref.read(myProfileControllerProvider).valueOrNull;
  // Profil henüz yüklenmediyse engelleme: kapı bir kolaylıktır, güvenlik
  // sınırı değildir (asıl sınırlar kurallarda ve CF'lerde).
  if (draft == null) return true;

  if (draft.profile.isAvailable) return true;

  context.showInfo(
    'Şu an "müsait değil" görünüyorsunuz. Mesaj göndermek için '
    'profilinizden müsaitliği açın.',
  );
  return false;
}
