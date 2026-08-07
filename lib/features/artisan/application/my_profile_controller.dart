import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../data/models/artisan_profile.dart';
import '../../../data/models/availability.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/job.dart'
    show isQuickSupportProviderCodes, kOtherProfession, kQuickSupportCategory;
import '../../../data/models/social_links.dart';
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
    // taslak yeni kullanıcıyla sıfırdan kurulmalı. Yalnızca uid seçilir.
    var uid = ref.watch(currentUserProvider.select((u) => u?.uid));
    if (uid == null) {
      try {
        uid = await ref
            .read(authStateProvider.future)
            .timeout(const Duration(seconds: 8))
            .then((u) => u?.uid);
      } catch (_) {
        uid = null;
      }
      if (uid == null) {
        throw StateError('Oturum açmış usta bulunamadı');
      }
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

  void setProfession(String code) => setProfessions([code]);

  /// Çoklu meslek (max 5). Birincil = listenin ilki.
  static const int maxProfessions = 5;

  /// B-03: Hemen Lazım (`kOtherProfession`) depoda `professions` dizisinde
  /// tutulur ama **meslek değildir** — ayrı bir hizmet tercihidir. Limit
  /// sayımında ve kesmede ELENMELİDİR, yoksa 4 meslek + Hemen Lazım = 5
  /// olur ve kullanıcı 5. mesleğini seçemez (sayaç "4/5" derken reddedilir).
  static bool isRealProfession(String code) =>
      code != kOtherProfession && code != kQuickSupportCategory;

  /// [codes] içindeki gerçek meslek sayısı (Hemen Lazım hariç).
  static int realProfessionCount(Iterable<String> codes) =>
      codes.where(isRealProfession).length;

  void setProfessions(List<String> codes) {
    final all = codes
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    // Kesme YALNIZ gerçek mesleklere uygulanır; Hemen Lazım korunur.
    final real = all.where(isRealProfession).take(maxProfessions);
    final extras = all.where((c) => !isRealProfession(c));
    final cleaned = [...real, ...extras];
    _update((d) => d.copyWith(
          profile: d.profile.copyWith(
            professions: cleaned,
            profession: cleaned.isEmpty ? '' : cleaned.first,
          ),
        ));
  }

  void toggleProfession(String code) {
    final cur = state.valueOrNull?.profile.professionCodes.toList() ?? [];
    if (cur.contains(code)) {
      cur.remove(code);
    } else {
      // Hemen Lazım limite dahil DEĞİL (bkz. isRealProfession).
      if (realProfessionCount(cur) >= maxProfessions) return;
      cur.add(code);
    }
    setProfessions(cur);
  }

  /// Hemen Lazım hizmeti açık mı? (Meslek listesinden ayrı anahtar.)
  ///
  /// Depolamada [kOtherProfession] kodu `professions` dizisinde tutulur —
  /// eşleşme (istemci/CF/rules) ve eski profiller aynen çalışsın diye şema
  /// DEĞİŞTİRİLMEZ; yalnız kullanıcıya ayrı bir anahtar olarak sunulur.
  bool get quickSupportEnabled {
    final codes = state.valueOrNull?.profile.professionCodes ?? const [];
    return isQuickSupportProviderCodes(codes);
  }

  /// Hemen Lazım anahtarını açar/kapatır.
  ///
  /// Kapatırken legacy `quick_support` kodu da temizlenir (bazı eski
  /// profillerde meslek olarak o yazılmış); yalnız [kOtherProfession]
  /// silinseydi anahtar kapalı görünüp ilanlar gelmeye devam ederdi.
  ///
  /// [maxProfessions] sınırı Hemen Lazım'ı ENGELLEMEZ: bu bir meslek değil,
  /// ayrı bir hizmet tercihidir; 5 meslek seçmiş usta da açabilmelidir.
  void setQuickSupportEnabled(bool enabled) {
    final cur = state.valueOrNull?.profile.professionCodes.toList() ?? [];
    final cleaned = cur
        .where((c) => c != kOtherProfession && c != kQuickSupportCategory)
        .toList();
    if (enabled) cleaned.add(kOtherProfession);
    // setProfessions max 5 ile keser → Hemen Lazım'ın elenmemesi için
    // doğrudan yazılır (meslek sayısı zaten UI'da sınırlı).
    _update((d) => d.copyWith(
          profile: d.profile.copyWith(
            professions: cleaned,
            profession: cleaned.isEmpty ? '' : cleaned.first,
          ),
        ));
  }

  void setExperience(int years) => _update((d) => d.copyWith(
        profile: d.profile.copyWith(
          experienceYears: Validators.clampExperienceYears(years),
        ),
      ));

  void setAbout(String text) => _update((d) => d.copyWith(
        profile: d.profile.copyWith(aboutText: Validators.sanitizeFreeText(text)),
      ));

  /// Sosyal medya / iş hattı bağlantılarını günceller. Ham girdi normalize
  /// edilir (kullanıcı tam URL yapıştırsa da kullanıcı adına indirgenir);
  /// boş bırakılan alan o bağlantıyı kaldırır.
  void setSocialLinks({
    String? instagram,
    String? youtube,
    String? tiktok,
    String? whatsapp,
    String? website,
  }) =>
      _update((d) => d.copyWith(
            profile: d.profile.copyWith(
              socialLinks: SocialLinks(
                instagram: SocialLinks.normalizeHandle(instagram),
                youtube: SocialLinks.normalizeHandle(youtube),
                tiktok: SocialLinks.normalizeHandle(tiktok),
                whatsapp: SocialLinks.normalizeWhatsapp(whatsapp),
                website: SocialLinks.normalizeWebsite(website),
              ),
            ),
          ));

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
  /// Açmak Premium erişimi gerektirir — çağıran taraf `hasPremiumAccess` ile
  /// kontrol eder (beta süresince herkese açık). Başarılıysa true.
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

  /// Doğrulanmış telefonun profilde herkese açık gösterilmesini açar/kapatır
  /// ve hemen kaydeder. [publicPhone] E.164 numara (yalnız açılırken gerekli).
  /// Telefon doğrulanmamışsa çağıran taraf bu seçeneği hiç göstermemelidir.
  Future<bool> setPhoneVisibility({
    required bool show,
    String? publicPhone,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    // Taslağı iyimser güncelle (UI anında yansısın).
    _update((d) => d.copyWith(
          profile: d.profile.copyWith(
            showPhoneOnProfile: show,
            publicPhone: show ? publicPhone : null,
            clearPublicPhone: !show,
          ),
        ));
    final result = await AsyncValue.guard(() async {
      await ref.read(myProfileRepositoryProvider).setPhoneVisibility(
            uid: current.profile.uid,
            showOnProfile: show,
            publicPhone: publicPhone,
          );
      return state.valueOrNull!;
    });
    if (result.hasError) return false;
    return true;
  }

  // NOT — Premium (PRD §6): `isPremium/premiumExpiresAt` İSTEMCİDEN YAZILAMAZ
  // (firestore.rules + repo'lar alanları yazımdan çıkarır). Beta süresince
  // premium özellikleri `hasPremiumAccess` ile herkese açık; gerçek satın
  // alma (Play Billing + sunucu doğrulaması) geldiğinde alanları CF yazacak.

  /// Son kaydetme hatası (B-04). `save()` false dönerse UI buradan gerçek
  /// sebebi okur — eskiden hata `AsyncValue.guard` içinde yutuluyor ve
  /// kullanıcıya sabit "Kaydetme başarısız" yazılıyordu; neden kaydedilemediği
  /// hiçbir yere düşmüyordu.
  String? _lastSaveError;

  /// Kullanıcıya gösterilecek kaydetme hatası — sebebi ayırt eder.
  String get saveErrorTR {
    final e = _lastSaveError ?? '';
    if (e.contains('permission-denied') || e.contains('PERMISSION_DENIED')) {
      return 'Profil kaydedilemedi: sunucu reddetti. Hizmet bölgeleriniz ve '
          'sosyal medya alanlarınızı kontrol edin.';
    }
    if (e.contains('unavailable') ||
        e.contains('deadline') ||
        e.contains('network') ||
        e.contains('Timeout')) {
      return 'Profil kaydedilemedi: bağlantı sorunu. İnternetinizi kontrol '
          'edip tekrar deneyin.';
    }
    if (e.isEmpty) return 'Profil kaydedilemedi, tekrar deneyin.';
    return 'Profil kaydedilemedi: $e';
  }

  /// Taslağı kalıcı hale getirir. Başarılıysa true döner.
  Future<bool> save() async {
    final current = state.valueOrNull;
    if (current == null) return false;

    // Kayıt öncesi sıkıştır / temizle (UI atlanmış olsa bile).
    final name = Validators.normalizeDisplayName(current.displayName);
    final profile = current.profile.copyWith(
      experienceYears:
          Validators.clampExperienceYears(current.profile.experienceYears),
      aboutText: Validators.sanitizeFreeText(current.profile.aboutText),
    );
    final sanitized = current.copyWith(displayName: name, profile: profile);

    _lastSaveError = null;
    state = const AsyncLoading<MyProfileDraft>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() async {
      await ref.read(myProfileRepositoryProvider).saveMyProfile(
            uid: sanitized.profile.uid,
            displayName: sanitized.displayName,
            profilePhotoUrl: sanitized.profilePhotoUrl,
            profile: sanitized.profile,
          );
      await ref.read(authRepositoryProvider).updateUserProfile(
            displayName: sanitized.displayName,
            profilePhotoUrl: sanitized.profilePhotoUrl,
          );
      return sanitized;
    });

    if (result.hasError) {
      _lastSaveError = result.error.toString();
      debugPrint('[profil] kaydetme hatası: $_lastSaveError');
      // B-05: HATA DURUMUNA GEÇME. `state = result` yazılsaydı provider
      // AsyncError'a düşer, `valueOrNull` null olur ve düzenleme ekranı
      // `SizedBox.shrink()` çizerdi — kullanıcı "ekran donuyor" diye
      // bildirmişti. Taslak korunur, kullanıcı düzeltip tekrar deneyebilir.
      state = AsyncData(sanitized);
      return false;
    }
    state = result;
    return true;
  }
}

final myProfileControllerProvider =
    AsyncNotifierProvider<MyProfileController, MyProfileDraft>(
        MyProfileController.new);
