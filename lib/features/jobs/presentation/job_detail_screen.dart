import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/app_analytics.dart';
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
import '../../../data/models/offer.dart';
import '../../../data/models/report.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../../chat/data/chat_providers.dart';
import '../../chat/data/firebase_chat_repository.dart'
    show FirebaseChatRepository;
import '../../safety/presentation/report_sheet.dart';
import '../data/job_providers.dart';
import 'job_completion.dart';
import 'widgets/job_widgets.dart';

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
    final isArtisan = user != null && user.isArtisan;

    return ResponsiveCenter(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _JobHeaderCard(job: job),
          const SizedBox(height: 16),
          if (isOwner)
            _OwnerOffersSection(job: job)
          else if (isArtisan)
            _ArtisanOfferSection(job: job)
          else
            // Keşfetten gelen başka bir müşteri: salt okunur görünüm.
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
            text: kProfessionNames[job.category] ?? job.category,
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

class _OwnerOffersSection extends ConsumerWidget {
  const _OwnerOffersSection({required this.job});
  final Job job;

  /// Bu ustayla BU İLANA ait sohbeti hazırlar (döküman yazılana kadar bekler).
  Future<String> _chatIdFor(WidgetRef ref, Offer offer) {
    return ref.read(chatRepositoryProvider).startChat(
          customerUid: job.customerId,
          customerName: job.customerName,
          customerPhotoUrl: job.customerPhotoUrl,
          artisanUid: offer.artisanId,
          artisanName: offer.artisanName,
          artisanPhotoUrl: offer.artisanPhotoUrl,
          jobId: job.jobId,
          jobTitle: job.title,
        );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref, Offer offer) async {
    try {
      final chatId = await _chatIdFor(ref, offer);
      if (!context.mounted) return;
      context.push(RoutePaths.chatThread(chatId));
    } catch (_) {
      if (context.mounted) {
        context.showError(
            'Sohbet açılamadı. E-posta doğrulamanızı kontrol edip tekrar deneyin.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // İş bir ustaya bağlandıysa: yaşam döngüsü + sohbet + tamamlama/değerlendirme.
    if (job.status.isAssigned) {
      return _AssignedCard(job: job, isOwner: true);
    }
    if (job.effectiveStatus == JobStatus.expired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _NoticeCard(
            icon: Icons.timer_off_outlined,
            text: 'Bu ilanın süresi doldu. Yeni bir ilan verebilirsiniz.',
          ),
          const SizedBox(height: 8),
          _DeleteJobButton(job: job),
        ],
      );
    }
    if (job.status == JobStatus.cancelled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeCard(
            icon: Icons.cancel_outlined,
            text:
                'İlan iptal edildi${job.cancelReason != null ? ' (${job.cancelReason!.labelTR})' : ''}.',
          ),
          const SizedBox(height: 8),
          _DeleteJobButton(job: job),
        ],
      );
    }

    final offersAsync = ref.watch(offersForJobProvider(job.jobId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('İlgilenen Ustalar',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        offersAsync.when(
          loading: () => const LoadingView(compact: true),
          error: (_, _) => const _NoticeCard(
            icon: Icons.error_outline,
            text: 'İlgilenen ustalar yüklenemedi. Lütfen tekrar deneyin.',
          ),
          data: (offers) {
            if (offers.isEmpty) {
              return const _NoticeCard(
                icon: Icons.hourglass_empty,
                text:
                    'Henüz kimse iletişime geçmedi. Bölgenizdeki ustalar ilanınızı '
                    'gördükçe sizinle iletişime geçecek.',
              );
            }
            return Column(
              children: [
                for (final o in offers) ...[
                  _OfferCard(
                    offer: o,
                    jobId: job.jobId,
                    onChat: () => _openChat(context, ref, o),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
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
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.palette.danger),
              onPressed: () => _cancelJob(context, ref, job),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('İlanı İptal Et'),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.palette.danger),
              onPressed: () => _deleteJob(context, ref, job),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('İlanı Sil'),
            ),
          ],
        ),
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

/// Müşterinin ilgilenen ustaları incelerken gördüğü usta özet kartı (#5).
class _OfferCard extends ConsumerWidget {
  const _OfferCard({
    required this.offer,
    required this.onChat,
    required this.jobId,
  });
  final Offer offer;
  final VoidCallback onChat;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          // Tıklayınca ustanın profiline git.
          InkWell(
            onTap: () =>
                context.push(RoutePaths.artisanProfile(offer.artisanId)),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: context.palette.primaryContainer,
                  child: ClipOval(
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: offer.artisanPhotoUrl != null
                          ? AppImage(handle: offer.artisanPhotoUrl)
                          : Icon(Icons.person,
                              color: context.palette.onPrimaryContainer),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(offer.artisanName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (offer.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 16, color: context.palette.verified),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 15, color: context.palette.star),
                          const SizedBox(width: 2),
                          Text(
                            '${offer.rating.toStringAsFixed(1)} (${offer.totalReviews})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Text('${offer.experienceYears} yıl',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (offer.isPremium) ...[
                            const SizedBox(width: 8),
                            const _PremiumTag(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.palette.inkFaint),
              ],
            ),
          ),
          const Divider(height: 20),
          // Bu ustayla BU İLANDAKİ sohbetin özeti: son mesaj + okunmamış
          // sayısı. Müşteri ilan detayından çıkmadan kimin ne yazdığını görür.
          _OfferChatPreview(offer: offer, jobId: jobId),
          Row(
            children: [
              // "Ustayı Seç" BURADA DEĞİL: seçim, ustayla konuşulan sohbetin
              // üstünden yapılır (§3). Müşteri önce yazışsın, sonra karar
              // versin — liste üzerinden körlemesine seçim kalktı.
              Expanded(
                child: FilledButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Mesaj Gönder'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// İlgilenen usta kartındaki sohbet özeti.
///
/// Sohbet ilan bazlı olduğundan (`chat_{müşteri}__{usta}__{jobId}`) bu ilana
/// ait oda doğrudan bulunabilir. Sohbet hiç başlamamışsa "İletişimi siz
/// başlatın" der — kurgu gereği ilk mesajı müşteri yazar.
class _OfferChatPreview extends ConsumerWidget {
  const _OfferChatPreview({required this.offer, required this.jobId});

  final Offer offer;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.uid;
    if (me == null) return const SizedBox.shrink();

    final chatId = FirebaseChatRepository.chatIdFor(
      me,
      offer.artisanId,
      jobId: jobId,
    );
    // Liste akışını izle: yeni mesaj gelince kart kendiliğinden tazelensin.
    final threads = ref.watch(myThreadsProvider).valueOrNull;
    final thread = threads?.where((t) => t.id == chatId).firstOrNull;
    final palette = context.palette;
    final theme = Theme.of(context);

    if (thread == null || (thread.lastMessage ?? '').trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(Icons.forum_outlined, size: 15, color: palette.inkFaint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Henüz mesajlaşmadınız — iletişimi siz başlatın.',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: palette.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    final unread =
        ref.read(chatRepositoryProvider).unreadCount(chatId: chatId, uid: me);
    final mine = thread.lastMessageSenderUid == me;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            mine ? Icons.reply_rounded : Icons.forum_rounded,
            size: 15,
            color: unread > 0 ? palette.primary : palette.inkFaint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              mine ? 'Siz: ${thread.lastMessage}' : thread.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: unread > 0 ? palette.ink : palette.inkMuted,
                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumTag extends StatelessWidget {
  const _PremiumTag();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.palette.premiumSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Premium',
          style: TextStyle(
              color: context.palette.premium,
              fontSize: 10,
              fontWeight: FontWeight.w800)),
    );
  }
}

/// İlan üzerindeki sohbeti açar: kayıtlı [Job.chatId] veya seçili ustadan
/// deterministik id. Sohbet dökümanı yoksa oluşturmayı dener (idempotent).
Future<void> _openJobChat(BuildContext context, WidgetRef ref, Job job) async {
  final artisanId = job.selectedArtisanId;
  final stored = job.chatId;
  if ((stored == null || stored.isEmpty) && artisanId == null) {
    context.showError('Sohbet bulunamadı.');
    return;
  }
  final repo = ref.read(chatRepositoryProvider);
  try {
    final String chatId;
    if (artisanId != null) {
      chatId = await repo.startChat(
        customerUid: job.customerId,
        customerName: job.customerName,
        customerPhotoUrl: job.customerPhotoUrl,
        artisanUid: artisanId,
        artisanName: 'Usta',
        artisanPhotoUrl: null,
        jobId: job.jobId,
        jobTitle: job.title,
      );
    } else {
      chatId = stored!;
      await repo.ensureChatReady(chatId);
    }
    if (!context.mounted) return;
    context.push(RoutePaths.chatThread(chatId));
  } catch (_) {
    if (context.mounted) {
      context.showError(
          'Sohbet açılamadı. E-posta doğrulamanızı kontrol edip tekrar deneyin.');
    }
  }
}

/// İş bir ustaya bağlandığında müşteri/usta için: yaşam döngüsü + sohbet +
/// tamamlama onayları + (müşteri) değerlendirme (#4, #10).
class _AssignedCard extends ConsumerWidget {
  const _AssignedCard({required this.job, required this.isOwner});
  final Job job;
  final bool isOwner;

  Future<void> _busyGuard(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) context.showError('İşlem başarısız, tekrar deneyin.');
    }
  }

  /// Usta seçimini geri alır (onaylı). İlan yeniden açılır; seçilmeyen
  /// ustaların kilitli sohbetleri CF tarafından tekrar açılır.
  Future<void> _cancelSelection(
      BuildContext context, WidgetRef ref, Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seçimi iptal et'),
        content: const Text(
            'Usta seçiminiz iptal edilecek ve ilan yeniden teklif toplamaya '
            'açılacak. İlgilenen ustalar sizinle tekrar yazışabilir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Seçimi İptal Et')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(jobRepositoryProvider).cancelSelection(
            jobId: job.jobId,
            customerId: job.customerId,
          );
      if (context.mounted) {
        context.showSuccess('Seçim iptal edildi; ilan yeniden açıldı.');
      }
    } catch (_) {
      if (context.mounted) {
        context.showError(
            'Seçim iptal edilemedi. İş başladıysa "Sorun Bildir" ile ilerleyin.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(jobRepositoryProvider);
    final status = job.status;
    final copy = JobCompletionCopy.of(job, isOwner: isOwner);

    // Şikayet açık: yaşam döngüsü donar; stepper yerine sorun paneli.
    if (status == JobStatus.disputed) {
      return _DisputePanel(job: job, isOwner: isOwner);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LifecycleStepper(job: job),
        const SizedBox(height: 12),
        JobCompletionStatusBanner(job: job, isOwner: isOwner),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sohbet — chatId yoksa seçili ustadan deterministik id üretilir.
              if (job.chatId != null || job.selectedArtisanId != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openJobChat(context, ref, job),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Sohbete Git'),
                  ),
                ),

              // Tamamlama onayları (iki taraflı, #10)
              if (status == JobStatus.workerSelected ||
                  status == JobStatus.inProgress) ...[
                const SizedBox(height: 14),
                JobConfirmRow(
                  customerDone: job.customerConfirmedDone,
                  artisanDone: job.artisanConfirmedDone,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: context.palette.success),
                    onPressed: copy.canConfirm
                        ? () => _busyGuard(
                            context,
                            () => repo.confirmDone(
                                jobId: job.jobId, byCustomer: isOwner))
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      copy.canConfirm
                          ? copy.confirmLabel
                          : copy.confirmedLabel,
                    ),
                  ),
                ),
                if (copy.showCountdown && job.autoCompleteAt != null) ...[
                  const SizedBox(height: 8),
                  _InlineNotice(
                    icon: Icons.schedule,
                    text: copy.remaining != null
                        ? 'Otomatik tamamlanmaya kalan: '
                            '${JobCompletionCopy.formatRemaining(copy.remaining!)} '
                            '(${_formatDate(job.autoCompleteAt!)})'
                        : 'Süre doldu; iş yakında otomatik tamamlanır.',
                  ),
                ],
                // "İşe başladım" KALDIRILDI: usta işi bitirince doğrudan
                // tamamlama onayı veriyor, arada ayrı bir adım yok. Durum
                // alanı (`inProgress`) modelde duruyor — eski kayıtlar ve
                // yönetici ekranları kırılmasın.
                //
                // Yerine müşteriye SEÇİM İPTALİ: usta işi yarıda bırakırsa ya
                // da anlaşma bozulursa ilan yeniden açılır, diğer ustaların
                // sohbetleri tekrar aktifleşir (kilitleri CF kaldırır).
                if (status == JobStatus.workerSelected && isOwner) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _cancelSelection(context, ref, job),
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Usta seçimini iptal et'),
                    ),
                  ),
                ],
              ],

              // Tamamlandı → müşteri değerlendirir
              if (status == JobStatus.completed) ...[
                const SizedBox(height: 6),
                if (isOwner)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push(RoutePaths.review(
                          job.selectedArtisanId!,
                          jobId: job.jobId)),
                      icon: const Icon(Icons.star_outline_rounded),
                      label: const Text('Ustayı Değerlendir'),
                    ),
                  )
                else
                  const _InlineNotice(
                    icon: Icons.check_circle,
                    text: 'İş tamamlandı. Değerlendirme müşteriden bekleniyor.',
                  ),
              ],

              if (status == JobStatus.rated)
                const _InlineNotice(
                  icon: Icons.verified,
                  text: 'İş tamamlandı ve değerlendirildi. Teşekkürler!',
                ),

              // Müşteri iptal (tamamlanmadan önce, #11) + sorun bildirme
              // (iki taraf da; tamamlandıktan sonra puanlamaya dek açık).
              if (isOwner &&
                      (status == JobStatus.workerSelected ||
                          status == JobStatus.inProgress) ||
                  status.canDispute) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    if (isOwner &&
                        (status == JobStatus.workerSelected ||
                            status == JobStatus.inProgress))
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            foregroundColor: context.palette.danger),
                        onPressed: () => _cancelJob(context, ref, job),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('İlanı İptal Et'),
                      ),
                    if (status.canDispute)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            foregroundColor: context.palette.warning),
                        onPressed: () => _reportDispute(context, ref, job,
                            byCustomer: isOwner),
                        icon: const Icon(Icons.report_gmailerrorred_outlined,
                            size: 18),
                        label: const Text('Sorun Bildir'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Anlaşmazlık (şikayet) akışı
// ---------------------------------------------------------------------------

/// İş `disputed` durumundayken gösterilen panel: kim, neden, ne zaman bildirdi;
/// şikayeti açan taraf geri çekebilir; sohbet açık kalır (çözüm için).
class _DisputePanel extends ConsumerWidget {
  const _DisputePanel({required this.job, required this.isOwner});
  final Job job;
  final bool isOwner;

  bool get _raisedByMe =>
      (job.disputedBy == JobDisputeParty.customer && isOwner) ||
      (job.disputedBy == JobDisputeParty.artisan && !isOwner);

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şikayeti geri çek'),
        content: const Text(
            'Şikayetinizi geri çekmek istiyor musunuz? İş kaldığı yerden '
            'devam eder ve karşı taraf bilgilendirilir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Geri Çek')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(jobRepositoryProvider).withdrawDispute(job.jobId);
      if (context.mounted) context.showInfo('Şikayet geri çekildi.');
    } catch (_) {
      if (context.mounted) {
        context.showError('İşlem başarısız, tekrar deneyin.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raiserLabel = job.disputedBy == JobDisputeParty.customer
        ? 'Müşteri'
        : 'Usta';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.danger.withValues(alpha: 0.4)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.palette.dangerSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.report_gmailerrorred,
                    color: context.palette.danger),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Sorun Bildirildi',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _raisedByMe
                ? 'Bu iş için sorun bildirdiniz. Sorun çözülene kadar iş '
                    'beklemede; anlaşırsanız şikayeti geri çekebilirsiniz.'
                : '$raiserLabel bu iş için sorun bildirdi. Sorun çözülene '
                    'kadar iş beklemede. Sohbet üzerinden anlaşmayı '
                    'deneyebilirsiniz.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          if (job.disputeReason != null)
            _MetaRow(
                icon: Icons.label_outline,
                text: 'Neden: ${job.disputeReason!.labelTR}'),
          if (job.disputeNote != null && job.disputeNote!.isNotEmpty)
            _MetaRow(icon: Icons.notes, text: job.disputeNote!),
          if (job.disputedAt != null)
            _MetaRow(
                icon: Icons.schedule,
                text: 'Bildirim tarihi: ${_formatDate(job.disputedAt!)}'),
          const SizedBox(height: 12),
          if (job.chatId != null || job.selectedArtisanId != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openJobChat(context, ref, job),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Sohbete Git'),
              ),
            ),
          if (_raisedByMe) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _withdraw(context, ref),
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Şikayeti Geri Çek'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Neden + not alıp şikayet açar.
Future<void> _reportDispute(BuildContext context, WidgetRef ref, Job job,
    {required bool byCustomer}) async {
  final result = await showModalBottomSheet<(JobDisputeReason, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DisputeSheet(),
  );
  if (result == null) return;
  try {
    await ref.read(jobRepositoryProvider).reportDispute(
          jobId: job.jobId,
          byCustomer: byCustomer,
          reason: result.$1,
          note: result.$2,
        );
    if (context.mounted) {
      context.showInfo('Sorun bildirildi. Karşı taraf bilgilendirildi.');
    }
  } catch (_) {
    if (context.mounted) {
      context.showError('Sorun bildirilemedi, lütfen tekrar deneyin.');
    }
  }
}

/// Şikayet formu: neden seçimi (zorunlu) + kısa açıklama (opsiyonel).
class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet();

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  JobDisputeReason? _reason;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sorun Bildir',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'İş, sorun çözülene kadar beklemeye alınır ve karşı taraf '
                'bilgilendirilir.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.palette.inkMuted),
              ),
              const SizedBox(height: 8),
              RadioGroup<JobDisputeReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final r in JobDisputeReason.values)
                      RadioListTile<JobDisputeReason>(
                        value: r,
                        title: Text(r.labelTR,
                            style: const TextStyle(fontSize: 14)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Kısa açıklama (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style:
                      FilledButton.styleFrom(backgroundColor: context.palette.danger),
                  onPressed: _reason == null
                      ? null
                      : () => Navigator.pop(
                          context, (_reason!, _noteController.text)),
                  icon: const Icon(Icons.report_gmailerrorred_outlined),
                  label: const Text('Sorunu Bildir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

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
          for (final r in JobCancelReason.values)
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

/// Yaşam döngüsü — kullanıcıya 3 evre (backend 8 durum aynı kalır).
class _LifecycleStepper extends StatelessWidget {
  const _LifecycleStepper({required this.job});
  final Job job;

  static const _steps = [
    'Teklif',
    'İş yürüyor',
    'Kapandı',
  ];

  @override
  Widget build(BuildContext context) {
    final current = job.status.simpleStepIndex;
    if (current == null) {
      // disputed / cancelled / expired — _AssignedCard veya üst chip açıklar.
      return _InlineNotice(
        icon: Icons.info_outline,
        text: job.status.simpleLabelTR,
      );
    }
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          _StepDot(
            label: _steps[i],
            done: i <= current,
            current: i == current,
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < current
                    ? context.palette.primary
                    : context.palette.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot(
      {required this.label, required this.done, required this.current});
  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done ? context.palette.primary : context.palette.inkFaint;
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? context.palette.primary : context.palette.card,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: current ? 2.5 : 1.5),
            ),
            child: done
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.1,
                color: color,
                fontWeight: current ? FontWeight.w800 : FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.palette.success),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Usta: teklif ver / güncelle / geri çek (#7, #8)
// ---------------------------------------------------------------------------

/// Usta: iş ilanını görünce müşteriyle doğrudan iletişime geçer (teklif yok).
/// "İletişime Geç" hem bir ilgi kaydı (customer'ın "İlgilenen Ustalar"
/// listesine düşer) oluşturur hem de anında sohbet açar.
class _ArtisanOfferSection extends ConsumerWidget {
  const _ArtisanOfferSection({required this.job});
  final Job job;

  /// Zaten iletişime geçilmişse yalnız sohbeti açar.
  ///
  /// ÖNEMLİ: Tekrar `submitOffer` çağrılmaz — döküman zaten varken `set()`
  /// Firestore'da update sayılır; kural yalnız note/price/status'a izin verir
  /// → permission-denied → "İletişim başlatılamadı" ve sohbet hiç açılmazdı.
  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showError('Sohbete gitmek için giriş yapmalısınız.');
      return;
    }
    final draft = ref.read(myProfileControllerProvider).valueOrNull;
    try {
      final chatId = await ref.read(chatRepositoryProvider).startChat(
            customerUid: job.customerId,
            customerName: job.customerName,
            customerPhotoUrl: job.customerPhotoUrl,
            artisanUid: user.uid,
            artisanName: draft?.displayName ?? user.displayName,
            artisanPhotoUrl: draft?.profilePhotoUrl ?? user.profilePhotoUrl,
            jobId: job.jobId,
            jobTitle: job.title,
          );
      if (!context.mounted) return;
      context.push(RoutePaths.chatThread(chatId));
    } catch (_) {
      if (context.mounted) {
        context.showError(
            'Sohbet açılamadı. E-posta doğrulamanızı kontrol edip tekrar deneyin.');
      }
    }
  }

  /// Usta: ilanla ilgilendiğini müşteriye BİLDİRİR (idempotent).
  ///
  /// Sohbet AÇILMAZ ve usta sohbete atılmaz — kurgu böyle: usta yalnız haber
  /// verir, sohbeti müşteri "Ustayı Seç" ile başlatır. İlgi kaydı yazılınca
  /// `onOfferWritten` CF müşteriye bildirim + push yollar.
  Future<void> _notifyInterest(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    final draft = ref.read(myProfileControllerProvider).valueOrNull;
    if (user == null || draft == null) {
      context.showError('İletişime geçmek için profil bilgileriniz gerekli.');
      return;
    }
    final profile = draft.profile;
    if (profile.professionCodes.isEmpty || profile.serviceAreas.isEmpty) {
      context.showError('Önce profilinizi (meslek + bölge) tamamlayın.');
      return;
    }

    // H3: meslek + il/ilçe eşleşmesi (sunucu rules da aynı mantığı zorlar).
    if (!job.matchesArtisan(
      professionCodes: profile.professionCodes,
      serviceAreas: profile.serviceAreas,
    )) {
      context.showError(
          'Bu ilan meslek veya hizmet bölgenizle eşleşmiyor. '
          'Profilinizdeki meslek ve bölgeleri kaydedip kontrol edin.');
      return;
    }

    // Sunucu da zorlar (offers create + isEmailVerified + eşleşme).
    final emailOk = await ensureEmailVerified(
      context,
      ref,
      actionLabel: 'ilan sahibine bildirim göndermek',
    );
    if (!emailOk || !context.mounted) return;

    final offerRepo = ref.read(offerRepositoryProvider);
    // Liste stream yüklenmeden / geri çek sonrası: sunucudan net durum.
    final existing = await offerRepo.myOfferFor(
      jobId: job.jobId,
      artisanUid: user.uid,
    );
    if (!context.mounted) return;

    final now = DateTime.now();
    final interest = Offer(
      offerId: Offer.idFor(job.jobId, user.uid),
      jobId: job.jobId,
      jobTitle: job.title,
      artisanId: user.uid,
      customerId: job.customerId,
      artisanName: draft.displayName,
      artisanPhotoUrl: draft.profilePhotoUrl,
      professionNameTR: profile.professionLabelsTR(kProfessionNames),
      experienceYears: profile.experienceYears,
      rating: profile.averageRating,
      totalReviews: profile.totalReviews,
      isVerified: profile.isVerified,
      isPremium: profile.hasActivePremium,
      priceType: JobPriceType.inspection,
      price: null,
      note: '',
      status: OfferStatus.pending,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      // Idempotent: yoksa create, withdrawn→pending, zaten aktifse no-op.
      await offerRepo.submitOffer(interest);
      if (existing == null) await AppAnalytics.sendOffer();
      if (!context.mounted) return;
      // ÖNEMLİ: aktif ilgide `submitOffer` HİÇBİR ŞEY yazmaz → CF tetiklenmez
      // → bildirim de gitmez. "Gönderildi" demek yanıltıcı olurdu; mevcut
      // kayıtta ayrı mesaj verilir. (`myOfferFor` withdrawn'ı null döndürür,
      // yani geri çekilip yeniden bildirmek gerçek bir gönderimdir.)
      if (existing == null) {
        context.showSuccess('Bildirim gönderildi. Müşteri ilanında sizi görecek.');
      } else {
        context.showInfo('Zaten bu ilanla ilgilendiğinizi bildirdiniz.');
      }
    } catch (e) {
      if (!context.mounted) return;
      final s = e.toString();
      if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
        context.showError(
            'Bildirim gönderilemedi: e-posta doğrulaması, profil eşleşmesi '
            '(meslek/bölge kayıtlı mı?) veya oturum yetkisi. '
            'Profili kaydedip tekrar deneyin.');
      } else {
        context.showError('Bildirim gönderilemedi, tekrar deneyin.');
      }
    }
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(offerRepositoryProvider)
          .withdrawOffer(jobId: job.jobId, artisanUid: user.uid);
      if (context.mounted) context.showInfo('İlgi geri çekildi.');
    } catch (_) {
      if (context.mounted) context.showError('İşlem başarısız, tekrar deneyin.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final status = job.effectiveStatus;
    final draft = ref.watch(myProfileControllerProvider).valueOrNull;
    final profile = draft?.profile;

    // İş bu ustaya verildiyse: yaşam döngüsü + sohbet + tamamlama onayı.
    if (job.selectedArtisanId != null && job.selectedArtisanId == user?.uid) {
      return _AssignedCard(job: job, isOwner: false);
    }
    // İş kapandı/başkası seçildi/süre doldu.
    if (status != JobStatus.open) {
      return _NoticeCard(
        icon: Icons.info_outline,
        text: status == JobStatus.expired
            ? 'Bu ilanın süresi doldu.'
            : 'Bu ilan artık aktif değil.',
      );
    }

    // H3: eşleşmeyen ustaya "Bildirim Gönder" gösterme.
    final matches = profile != null &&
        profile.professionCodes.isNotEmpty &&
        profile.serviceAreas.isNotEmpty &&
        job.matchesArtisan(
          professionCodes: profile.professionCodes,
          serviceAreas: profile.serviceAreas,
        );
    if (!matches) {
      final incomplete = profile == null ||
          profile.professionCodes.isEmpty ||
          profile.serviceAreas.isEmpty;
      return _NoticeCard(
        icon: Icons.location_off_outlined,
        text: incomplete
            ? 'Bildirim göndermek için profilinizde en az bir meslek ve '
                'hizmet bölgesi tanımlayın.'
            : 'Bu ilan meslek veya hizmet bölgenizle eşleşmiyor. '
                'Yalnızca uyumlu ilanlara teklif verebilirsiniz.',
      );
    }

    // Zaten bildirildiyse: sohbete git / geri çek.
    // Stream yüklenirken "Bildirim Gönder" göstermek mevcut teklife full set
    // yarışına yol açıyordu → loading ayrımı.
    final myOffersAsync = ref.watch(myOffersProvider(user?.uid ?? ''));
    if (myOffersAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingView(compact: true, label: 'İlgi durumu…'),
      );
    }
    Offer? existing;
    final myOffers = myOffersAsync.valueOrNull;
    if (myOffers != null) {
      for (final o in myOffers) {
        if (o.jobId == job.jobId && o.status != OfferStatus.withdrawn) {
          existing = o;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              existing != null
                  ? 'Bildiriminiz gönderildi'
                  : 'Bu işle ilgileniyor musunuz?',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            existing != null
                ? 'Müşteriye bildirim gönderildi. İlanında "İlgilenen Ustalar" '
                    'listesinde görünüyorsunuz; sizi seçerse sohbet açılacak.'
                : 'İlgilendiğinizi müşteriye bildirin; sizi seçerse işi '
                    'konuşmaya başlarsınız.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.palette.inkMuted),
          ),
          const SizedBox(height: 12),
          // Bildirim gönderildikten sonra birincil eylem YOK: sıra müşteride.
          // "Sohbete Git" yine de durur — müşteri sohbeti başlattıysa ustanın
          // ilan sayfasından dönüş yolu kapanmasın.
          if (existing != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    // Tekrar teklif yazma — yalnız sohbeti aç.
                    onPressed: () => _openChat(context, ref),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Sohbete Git'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => _withdraw(context, ref),
                  child: const Text('Geri Çek'),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _notifyInterest(context, ref),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Bildirim Gönder'),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.palette.inkMuted),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: context.palette.inkMuted))),
        ],
      ),
    );
  }
}
