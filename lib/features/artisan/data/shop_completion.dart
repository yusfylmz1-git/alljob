import '../../../data/models/app_user.dart';
import '../../../data/models/artisan_profile.dart';
import '../application/my_profile_controller.dart';

/// Vitrin / arama için tek bir tamamlama adımı.
class ShopCompletionStep {
  const ShopCompletionStep({
    required this.id,
    required this.label,
    required this.ok,
    required this.hint,
    this.requiredForJobs = false,
  });

  final String id;
  final String label;
  final bool ok;
  final String hint;

  /// Meslek + bölge: yakındaki iş feed’i için zorunlu.
  final bool requiredForJobs;
}

/// Usta vitrin doluluğu (Profil kartı + Hizmetlerim funnel).
class ShopCompletion {
  const ShopCompletion({
    required this.steps,
    required this.photoOk,
  });

  final List<ShopCompletionStep> steps;
  final bool photoOk;

  int get done => steps.where((s) => s.ok).length;
  int get total => steps.length;
  double get progress => total == 0 ? 0 : done / total;
  int get percent => (progress * 100).round();
  bool get isComplete => steps.every((s) => s.ok);

  /// İlan feed’i için minimum: meslek + en az bir bölge.
  bool get canMatchJobs =>
      steps.where((s) => s.requiredForJobs).every((s) => s.ok);

  List<ShopCompletionStep> get missing =>
      steps.where((s) => !s.ok).toList(growable: false);

  ShopCompletionStep? get nextMissing {
    for (final s in steps) {
      if (!s.ok) return s;
    }
    return null;
  }

  factory ShopCompletion.from({
    required AppUser user,
    MyProfileDraft? draft,
  }) {
    final p = draft?.profile;
    final photoOk = (user.profilePhotoUrl ?? '').isNotEmpty ||
        (draft?.profilePhotoUrl ?? '').isNotEmpty;

    return ShopCompletion(
      photoOk: photoOk,
      steps: [
        ShopCompletionStep(
          id: 'photo',
          label: 'Profil fotoğrafı',
          ok: photoOk,
          hint: 'Müşteri sizi yüzünüzden tanısın.',
        ),
        ShopCompletionStep(
          id: 'about',
          label: 'Hakkımda',
          ok: p != null && p.aboutText.trim().isNotEmpty,
          hint: 'Kısa bir tanıtım yazın.',
        ),
        ShopCompletionStep(
          id: 'profession',
          label: 'Meslek',
          ok: p != null && p.professionCodes.isNotEmpty,
          hint: 'En az bir meslek / Hızlı Destek seçin.',
          requiredForJobs: true,
        ),
        ShopCompletionStep(
          id: 'area',
          label: 'Hizmet bölgesi',
          ok: p != null && p.serviceAreas.isNotEmpty,
          hint: 'Hizmet verdiğiniz il ve ilçeyi ekleyin.',
          requiredForJobs: true,
        ),
        ShopCompletionStep(
          id: 'photos',
          label: 'İş fotoğrafları',
          ok: p != null && p.workPhotos.isNotEmpty,
          hint: 'Yaptığınız işlerden örnek ekleyin.',
        ),
        ShopCompletionStep(
          id: 'hours',
          label: 'Çalışma saatleri',
          ok: p != null && _hoursOk(p),
          hint: 'Takvim veya “her zaman müsait” seçin.',
        ),
      ],
    );
  }

  static bool _hoursOk(ArtisanProfile p) =>
      p.alwaysAvailable ||
      p.manualPause ||
      p.weeklySchedule.days.any((d) => d.enabled);
}
