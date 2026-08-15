import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/job.dart';
import '../../../data/models/report.dart';
import '../../artisan/application/availability_gate.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../../chat/data/chat_providers.dart';
import '../../safety/presentation/report_sheet.dart';
import '../data/job_providers.dart';
import 'widgets/job_widgets.dart';
import '../../../core/utils/app_log.dart';

/// İlan detayı — müşteri teklifleri görür/seçer, usta teklif verir.
class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobProvider(jobId));
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'İlan Detayı',
        icon: Icons.description_outlined,
      ),
      body: jobAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          message: 'İlan yüklenemedi. Bağlantınızı kontrol edip '
              'tekrar deneyin.',
          onRetry: () => ref.invalidate(jobProvider(jobId)),
        ),
        data: (job) {
          if (job == null) {
            return const Center(child: Text('İlan bulunamadı.'));
          }
          return _JobDetailBody(job: job);
        },
      ),
    );
  }
}

class _JobDetailBody extends ConsumerWidget {
  const _JobDetailBody({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isOwner = user != null && user.uid == job.customerId;
    // Aktif "usta modu" değil — profili açmış olmak yeterli (İlanlar
    // sekmesiyle aynı kapı). Ürün talebinde mağaza profili gerekir.
    final canRespond = user != null &&
        (job.isProductRequest
            ? user.hasShopProfile
            : user.hasArtisanProfile);

    return ResponsiveCenter(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _JobHeaderCard(job: job),
          const SizedBox(height: 16),
          if (isOwner)
            _OwnerOffersSection(job: job)
          else if (canRespond)
            _ArtisanOfferSection(job: job)
          else if (job.isProductRequest &&
              user != null &&
              !user.hasShopProfile)
            _NoticeCard(
              icon: Icons.storefront_outlined,
              text: 'Ürün taleplerine yazmak için Profil → Mağaza’dan '
                  '“Satış yapmaya başla” ile mağaza açın.',
              actionLabel: 'Profile git',
              onAction: () => context.push(RoutePaths.profile),
            )
          else if (!job.isProductRequest &&
              user != null &&
              !user.hasArtisanProfile)
            _NoticeCard(
              icon: Icons.handyman_outlined,
              text: 'İş ilanlarına yazmak için Profil’den usta profili açın. '
                  'İlan vermek için usta olmanız gerekmez.',
              actionLabel: 'Profile git',
              onAction: () => context.push(RoutePaths.profile),
            )
          else
            // Misafir veya salt müşteri: salt okunur görünüm.
            const _NoticeCard(
              icon: Icons.info_outline,
              text: 'Bu ilan başka bir müşteriye ait. İlanla yalnızca '
                  'bölgesindeki ustalar iletişime geçebilir.',
            ),
          // Başkasının ilanını şikayet etme (UGC politikası).
          if (user != null && !isOwner) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Bu ilanı şikayet et'),
                style: TextButton.styleFrom(
                    foregroundColor: context.palette.inkMuted),
                onPressed: () => showReportSheet(
                  context,
                  ref,
                  target: ReportTarget.job,
                  targetId: job.jobId,
                  reportedUid: job.customerId,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// İlan bilgi kartı
// ---------------------------------------------------------------------------

class _JobHeaderCard extends StatelessWidget {
  const _JobHeaderCard({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final status = job.effectiveStatus;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JobStatusChip(status: status),
          const SizedBox(height: 12),
          Text(job.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _MetaRow(
            icon: Icons.handyman_outlined,
            text: kProfessionNames[job.category] ?? job.categoryLabelTR,
          ),
          _MetaRow(
            icon: Icons.place_outlined,
            text:
                '${job.province} / ${job.district}${job.neighborhood != null ? ' / ${job.neighborhood}' : ''}',
          ),
          const SizedBox(height: 14),
          Text(job.description,
              style: Theme.of(context).textTheme.bodyMedium),
          if (job.photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: job.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openJobPhotoGallery(
                      context,
                      handles: job.photos,
                      initialIndex: i,
                    ),
                    child: Hero(
                      tag: 'job-photo-${job.jobId}-$i',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: AppImage(
                            handle: job.photos[i],
                            memCacheWidth: 192,
                            memCacheHeight: 192,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// İlan fotoğrafını tam ekran açar (yakınlaştırma + kaydırarak diğerleri).
void _openJobPhotoGallery(
  BuildContext context, {
  required List<String> handles,
  required int initialIndex,
}) {
  if (handles.isEmpty) return;
  final index = initialIndex.clamp(0, handles.length - 1);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _JobPhotoGalleryPage(
        handles: handles,
        initialIndex: index,
      ),
    ),
  );
}

/// Siyah arka planlı tam ekran galeri — pinch-zoom ve yatay sayfalar.
class _JobPhotoGalleryPage extends StatefulWidget {
  const _JobPhotoGalleryPage({
    required this.handles,
    required this.initialIndex,
  });

  final List<String> handles;
  final int initialIndex;

  @override
  State<_JobPhotoGalleryPage> createState() => _JobPhotoGalleryPageState();
}

class _JobPhotoGalleryPageState extends State<_JobPhotoGalleryPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.handles.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: total > 1
            ? Text('${_index + 1} / $total',
                style: const TextStyle(fontWeight: FontWeight.w600))
            : null,
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final handle = widget.handles[i];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: AppImage(
                      handle: handle,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            if (total > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(total, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 10 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.palette.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: context.palette.inkMuted)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Müşteri: gelen teklifler + seçim
// ---------------------------------------------------------------------------

/// İlan sahibinin gördüğü bölüm — SADE (2026-08-08).
///
/// Eskiden burada "İlgilenen Ustalar" listesi, "Bu Ustayı Seç" akışı ve
/// tamamlama onayı vardı. İş akışı kaldırıldı: ustalar doğrudan mesaj atar,
/// sahip **Mesajlar**'dan görür ve kendi aralarında anlaşırlar.
class _OwnerOffersSection extends ConsumerWidget {
  const _OwnerOffersSection({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final canEdit = job.status == JobStatus.open;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.infoSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.chat_bubble_outline, size: 20, color: palette.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'İlanınla ilgilenen ustalar sana doğrudan mesaj atar. '
                  'Gelen mesajları Mesajlar sekmesinden görebilirsin.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(RoutePaths.chats),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: const Text('Mesajlara Git'),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          children: [
            // Yayından sonra 1 saatlik düzenleme penceresi (Job.editWindow).
            if (job.canEditNow)
              TextButton.icon(
                onPressed: () => _editJob(context, ref, job),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Düzenle'),
              ),
            if (canEdit)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: palette.danger),
                onPressed: () => _cancelJob(context, ref, job),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('İlanı İptal Et'),
              ),
          ],
        ),
        _DeleteJobButton(job: job),
      ],
    );
  }
}


/// İptal edilmiş / süresi dolmuş ilan için "İlanı Sil" düğmesi.
class _DeleteJobButton extends ConsumerWidget {
  const _DeleteJobButton({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: context.palette.danger),
        onPressed: () => _deleteJob(context, ref, job),
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text('İlanı Sil'),
      ),
    );
  }
}

/// Onay isteyip ilanı kalıcı olarak siler; başarıda detaydan çıkar.
Future<void> _deleteJob(BuildContext context, WidgetRef ref, Job job) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('İlanı sil'),
      content: const Text('İlan kalıcı olarak silinecek. Bu işlem geri '
          'alınamaz. Devam edilsin mi?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil')),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(jobRepositoryProvider).deleteJob(job.jobId);
    if (context.mounted) {
      context.showInfo('İlan silindi.');
      if (context.canPop()) context.pop();
    }
  } catch (_) {
    if (context.mounted) {
      context.showError('İlan silinemedi, tekrar deneyin.');
    }
  }
}

/// Düzenleme formunu açar; kaydında içerik güncellenir (yalnız açık ilan,
/// yayından sonra 1 saat — [Job.canEditNow]).
Future<void> _editJob(BuildContext context, WidgetRef ref, Job job) async {
  final result = await showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditJobSheet(job: job),
  );
  if (result == null) return;
  // Pencere sheet açıkken kapanmış olabilir — son kez kontrol et.
  if (!job.canEditNow) {
    if (context.mounted) {
      context.showError('Düzenleme süresi doldu (ilan yayınlandıktan sonra '
          '1 saat).');
    }
    return;
  }
  try {
    await ref.read(jobRepositoryProvider).updateJobContent(
          jobId: job.jobId,
          title: result.$1,
          description: result.$2,
          budget: job.budget,
        );
    if (context.mounted) context.showSuccess('İlan güncellendi.');
  } catch (_) {
    if (context.mounted) {
      context.showError('İlan güncellenemedi, tekrar deneyin.');
    }
  }
}

/// Başlık + açıklama düzenleme formu (ilan verme ekranıyla aynı sınırlar).
class _EditJobSheet extends StatefulWidget {
  const _EditJobSheet({required this.job});
  final Job job;

  @override
  State<_EditJobSheet> createState() => _EditJobSheetState();
}

class _EditJobSheetState extends State<_EditJobSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.job.title);
  late final _descController =
      TextEditingController(text: widget.job.description);

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Klavye açılınca formun görünür kalması için.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('İlanı Düzenle',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'İlanlar yayınlandıktan sonra 1 saat boyunca düzenlenebilir.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.palette.inkMuted),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  maxLength: AppConstants.maxJobTitleLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'İlan Başlığı',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => Validators.freeText(
                    v,
                    min: 5,
                    max: AppConstants.maxJobTitleLength,
                    field: 'Başlık',
                    required: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  maxLength: AppConstants.maxJobDescriptionLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => Validators.freeText(
                    v,
                    min: 10,
                    max: AppConstants.maxJobDescriptionLength,
                    field: 'Açıklama',
                    required: true,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (!(_formKey.currentState?.validate() ?? false)) {
                        return;
                      }
                      Navigator.pop(
                          context,
                          (
                            Validators.sanitizeFreeText(
                                _titleController.text),
                            Validators.sanitizeFreeText(
                                _descController.text),
                          ));
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İptal nedeni seçtirip ilanı iptal eder (#11).
Future<void> _cancelJob(BuildContext context, WidgetRef ref, Job job) async {
  final reason = await showModalBottomSheet<JobCancelReason>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('İlanı neden iptal ediyorsunuz?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          // B-11: `rateLimited` YALNIZ CF'in yazdığı bir sebeptir (günlük
          // ilan hakkı dolunca sunucu iptal eder). Kullanıcıya seçenek olarak
          // sunmak anlamsızdı — hakkı dolmuşsa zaten ilan açamıyor.
          for (final r in JobCancelReason.values)
            if (r != JobCancelReason.rateLimited)
              ListTile(
                leading: const Icon(Icons.chevron_right),
                title: Text(r.labelTR),
                onTap: () => Navigator.pop(ctx, r),
              ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (reason == null) return;
  try {
    await ref
        .read(jobRepositoryProvider)
        .cancelJob(jobId: job.jobId, reason: reason);
    if (context.mounted) context.showInfo('İlan iptal edildi.');
  } catch (_) {
    if (context.mounted) context.showError('İptal başarısız, tekrar deneyin.');
  }
}

/// Ustanın gördüğü bölüm — SADE (2026-08-08).
///
/// Eskiden "Bildirim Gönder" ile ilgi kaydı (`offers`) oluşturulur, müşteri
/// "Ustayı Seç" derdi. O ara adım kaldırıldı: usta **doğrudan mesaj atar**.
///
/// Kapılar korunuyor: e-posta doğrulama · askı · meslek/bölge eşleşmesi ·
/// müsaitlik. Müsait olmayan usta aramada da görünmüyor; ilan sahibine
/// yazabilmesi tutarsız olurdu.
class _ArtisanOfferSection extends ConsumerWidget {
  const _ArtisanOfferSection({required this.job});
  final Job job;

  Future<void> _messageOwner(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showError('Mesaj göndermek için giriş yapmalısınız.');
      return;
    }
    if (user.suspended) {
      context.showError('Hesabınız askıya alındığı için mesaj gönderilemez.');
      return;
    }

    // Ortak müsaitlik kapısı (users.available + usta vitrin müsaitliği).
    // isArtisan (aktif mod) DEĞİL — profili olan herkes bağlanır.
    if (!artisanAvailabilityAllowsNewChat(context, ref)) return;

    // Ürün talebi → mağaza profili (meslek eşleşmesi yok).
    if (job.isProductRequest) {
      if (!user.hasShopProfile) {
        context.showError(
          'Ürün taleplerine yazmak için Profil → Mağaza’dan '
          '“Satış yapmaya başla” ile mağaza açın.',
        );
        return;
      }
    } else {
      final draft = ref.read(myProfileControllerProvider).valueOrNull;
      if (draft == null) {
        context.showError('Profil bilgileriniz yüklenemedi.');
        return;
      }
      final profile = draft.profile;
      if (profile.professionCodes.isEmpty || profile.serviceAreas.isEmpty) {
        context.showError('Önce profilinizi (meslek + bölge) tamamlayın.');
        return;
      }
      if (!job.matchesArtisan(
        professionCodes: profile.professionCodes,
        serviceAreas: profile.serviceAreas,
      )) {
        context.showError(
          'Bu ilan meslek veya hizmet bölgenizle eşleşmiyor. '
          'Profilinizdeki meslek ve bölgeleri kaydedip kontrol edin.',
        );
        return;
      }
    }

    // Sunucu da zorlar (chats create + isEmailVerified).
    final emailOk = await ensureEmailVerified(
      context,
      ref,
      actionLabel: 'ilan sahibine mesaj göndermek',
    );
    if (!emailOk || !context.mounted) return;

    final draft = ref.read(myProfileControllerProvider).valueOrNull;
    final name = draft?.displayName ??
        (user.displayName.isEmpty ? 'Kullanıcı' : user.displayName);
    final photo = draft?.profilePhotoUrl ?? user.profilePhotoUrl;

    try {
      final chatId = await ref.read(chatRepositoryProvider).startChat(
            customerUid: job.customerId,
            customerName: job.customerName,
            customerPhotoUrl: job.customerPhotoUrl,
            artisanUid: user.uid,
            artisanName: name,
            artisanPhotoUrl: photo,
            jobId: job.jobId,
            jobTitle: job.title,
          );
      if (!context.mounted) return;
      context.push(RoutePaths.chatThread(chatId));
    } catch (e) {
      if (!context.mounted) return;
      final denied = e.toString().contains('permission-denied');
      context.showError(denied
          ? 'Mesaj gönderme izniniz yok. Hesabınız askıya alınmış olabilir.'
          : 'Sohbet açılamadı, tekrar deneyin.');
      AppLog.d('[job] startChat hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    if (!job.status.isActiveForOffers) {
      return const _NoticeCard(
        icon: Icons.info_outline,
        text: 'Bu ilan artık teklife açık değil.',
      );
    }

    // Müsaitlik: tıklamadan ÖNCE görünsün (users.available + vitrin).
    final draft = ref.watch(myProfileControllerProvider).valueOrNull;
    final unavailable = providerIsUnavailableForNewChat(
      user: user,
      profile: draft?.profile,
    );

    if (unavailable) {
      final forShop = job.isProductRequest;
      return _NoticeCard(
        icon: Icons.pause_circle_outline,
        tone: _NoticeTone.warning,
        text: forShop
            ? 'Müsait değilsiniz. Ürün taleplerine mesaj atmak için '
                'Profil’den “Müsait” durumunuzu açın. Vitrininiz de '
                'müsaitken öne çıkar.'
            : 'Müsait değilsiniz. İlan sahiplerine mesaj atmak için '
                'Profil’den “Müsait” durumunuzu açın. Bildirim almaya '
                'devam edersiniz; yalnız yeni mesaj başlatamazsınız.',
        actionLabel: 'Profilde müsaitliği aç',
        onAction: () => context.push(RoutePaths.profile),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.infoSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                job.isProductRequest
                    ? Icons.storefront_outlined
                    : Icons.handyman_outlined,
                size: 20,
                color: palette.info,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.isProductRequest
                      ? 'İlgileniyorsan talep sahibine doğrudan mesaj at. '
                          'Ürün ve fiyatı sohbette konuşabilirsiniz.'
                      : 'İlgileniyorsan ilan sahibine doğrudan mesaj at. '
                          'Detayları kendi aranızda konuşup anlaşabilirsiniz.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _messageOwner(context, ref),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Mesaj Gönder'),
          ),
        ),
      ],
    );
  }
}

enum _NoticeTone { neutral, warning }

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.tone = _NoticeTone.neutral,
  });
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = tone == _NoticeTone.warning
        ? palette.warningSurface
        : palette.surfaceMuted;
    final fg = tone == _NoticeTone.warning
        ? palette.warning
        : palette.inkMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tone == _NoticeTone.warning
                            ? palette.ink
                            : palette.inkMuted,
                        fontWeight: tone == _NoticeTone.warning
                            ? FontWeight.w600
                            : null,
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
