import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/artisan_profile.dart';
import '../../../data/models/availability.dart';
import '../../../data/models/geo_models.dart';
import '../../auth/application/auth_controller.dart';
import '../data/my_profile_repository.dart';

/// Ustanın düzenlemekte olduğu profil taslağı (kaydedilmemiş hali).
class MyProfileDraft {
  const MyProfileDraft({
    required this.displayName,
    required this.profile,
    this.profilePhotoUrl,
  });

  final String displayName;
  final String? profilePhotoUrl;
  final ArtisanProfile profile;

  MyProfileDraft copyWith({
    String? displayName,
    String? profilePhotoUrl,
    ArtisanProfile? profile,
  }) {
    return MyProfileDraft(
      displayName: displayName ?? this.displayName,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      profile: profile ?? this.profile,
    );
  }
}

/// Usta profil düzenleme controller'ı: taslağı yükler, alanları günceller
/// ve kaydeder. Puanlama alanları (rating/totalReviews) hiç değiştirilmez.
class MyProfileController extends AsyncNotifier<MyProfileDraft> {
  @override
  Future<MyProfileDraft> build() async {
    // HESAP DEĞİŞİMİNİ İZLE (watch): çıkış yapıp farklı hesapla girilince
    // taslak yeni kullanıcıyla sıfırdan kurulmalı (eski `ref.read` bunu
    // yapmıyordu → önceki oturumun verisi ekranda kalıyordu). Yalnızca uid'i
    // seçiyoruz ki users dökümanındaki diğer alan güncellemeleri (ör. mod
    // geçişi, phoneVerified) kaydedilmemiş taslağı ezmesin.
    var uid = ref.watch(currentUserProvider.select((u) => u?.uid));
    if (uid == null) {
      // Açılışta (web'de sayfa yenilemede) oturum henüz geri yüklenmemiş
      // olabilir — hemen hata verme, ilk auth emisyonunu bekle.
      uid = (await ref.read(authStateProvider.future))?.uid;
      if (uid == null) throw StateError('Oturum açmış usta bulunamadı');
    }
    final user = ref.read(currentUserProvider);
    final profile =
        await ref.read(myProfileRepositoryProvider).getMyProfile(uid);
    return MyProfileDraft(
      displayName: user?.displayName ?? '',
      profilePhotoUrl: user?.profilePhotoUrl,
      profile: profile,
    );
  }

  // --- Senkron taslak güncellemeleri ---

  void _update(MyProfileDraft Function(MyProfileDraft) transform) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(transform(current));
  }

  void setDisplayName(String value) =>
      _update((d) => d.copyWith(displayName: value));

  void setProfilePhoto(String handle) =>
      _update((d) => d.copyWith(profilePhotoUrl: handle));

  void setProfession(String code) =>
      _update((d) => d.copyWith(profile: d.profile.copyWith(profession: code)));

  void setExperience(int years) => _update(
      (d) => d.copyWith(profile: d.profile.copyWith(experienceYears: years)));

  void setAbout(String text) =>
      _update((d) => d.copyWith(profile: d.profile.copyWith(aboutText: text)));

  /// Hizmet bölgesi ekler (aynısı varsa eklemez).
  bool addServiceArea(ServiceArea area) {
    final current = state.valueOrNull;
    if (current == null) return false;
    if (current.profile.serviceAreas.contains(area)) return false;
    _update((d) => d.copyWith(
          profile: d.profile.copyWith(
            serviceAreas: [...d.profile.serviceAreas, area],
          ),
        ));
    return true;
  }

  void removeServiceArea(ServiceArea area) {
    _update((d) => d.copyWith(
          profile: d.profile.copyWith(
            serviceAreas:
                d.profile.serviceAreas.where((a) => a != area).toList(),
          ),
        ));
  }

  void addWorkPhoto(String handle) => _update((d) => d.copyWith(
        profile: d.profile.copyWith(
          workPhotos: [...d.profile.workPhotos, handle],
        ),
      ));

  void removeWorkPhoto(String handle) => _update((d) => d.copyWith(
        profile: d.profile.copyWith(
          workPhotos: d.profile.workPhotos.where((p) => p != handle).toList(),
        ),
      ));

  void addCertificate(String handle) => _update((d) => d.copyWith(
        profile: d.profile.copyWith(
          certificates: [...d.profile.certificates, handle],
        ),
      ));

  void removeCertificate(String handle) => _update((d) => d.copyWith(
        profile: d.profile.copyWith(
          certificates:
              d.profile.certificates.where((c) => c != handle).toList(),
        ),
      ));

  // --- Müsaitlik / çalışma takvimi (PRD §3) ---

  /// Üç müsaitlik kipini (her zaman / haftalık / geçici kapalı) uygular.
  void setAvailabilityMode(AvailabilityMode mode) => _update((d) {
        switch (mode) {
          case AvailabilityMode.always:
            return d.copyWith(
                profile: d.profile
                    .copyWith(alwaysAvailable: true, manualPause: false));
          case AvailabilityMode.weekly:
            return d.copyWith(
                profile: d.profile
                    .copyWith(alwaysAvailable: false, manualPause: false));
          case AvailabilityMode.paused:
            return d.copyWith(
                profile: d.profile.copyWith(manualPause: true));
        }
      });

  void toggleScheduleDay(int weekday, bool enabled) => _update((d) => d.copyWith(
        profile: d.profile.copyWith(
          weeklySchedule: d.profile.weeklySchedule
              .withDay(weekday, (day) => day.copyWith(enabled: enabled)),
        ),
      ));

  void setScheduleDayHours(int weekday, {int? startMinute, int? endMinute}) =>
      _update((d) => d.copyWith(
            profile: d.profile.copyWith(
              weeklySchedule: d.profile.weeklySchedule.withDay(
                weekday,
                (day) =>
                    day.copyWith(startMinute: startMinute, endMinute: endMinute),
              ),
            ),
          ));

  /// Ana "Müsait" switch'i: müsaitliği açıp/kapatır ve hemen kaydeder.
  /// Açmak Premium gerektirir (çağıran taraf kontrol eder). Başarılıysa true.
  Future<bool> setAvailable(bool active) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    _update((d) => d.copyWith(
          profile: d.profile.copyWith(
            alwaysAvailable: active,
            manualPause: !active,
          ),
        ));
    return save();
  }

  // --- Premium üyelik (PRD §6) ---

  /// Premium'u etkinleştirir/kapatır ve hemen kaydeder. İlk 1 yıl modeli:
  /// etkinleştirme ücretsizdir ve 1 yıllık geçerlilik verir. Başarılıysa true.
  Future<bool> setPremium(bool active) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    _update((d) => d.copyWith(
          profile: d.profile.copyWith(
            isPremium: active,
            premiumExpiresAt:
                active ? DateTime.now().add(const Duration(days: 365)) : null,
          ),
        ));
    return save();
  }

  /// Taslağı kalıcı hale getirir. Başarılıysa true döner.
  Future<bool> save() async {
    final current = state.valueOrNull;
    if (current == null) return false;

    state = const AsyncLoading<MyProfileDraft>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() async {
      await ref.read(myProfileRepositoryProvider).saveMyProfile(
            uid: current.profile.uid,
            displayName: current.displayName,
            profilePhotoUrl: current.profilePhotoUrl,
            profile: current.profile,
          );
      await ref.read(authRepositoryProvider).updateUserProfile(
            displayName: current.displayName,
            profilePhotoUrl: current.profilePhotoUrl,
          );
      return current;
    });
    state = result;
    return !result.hasError;
  }
}

final myProfileControllerProvider =
    AsyncNotifierProvider<MyProfileController, MyProfileDraft>(
        MyProfileController.new);
