import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/job.dart';
import '../../../data/models/offer.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/data/chat_providers.dart';
import '../data/job_providers.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('İlan yüklenemedi.\n$e')),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (job.isUrgent) ...[
                const UrgentBadge(),
                const SizedBox(width: 8),
              ],
              JobStatusChip(status: status),
            ],
          ),
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
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                      width: 96, height: 96, child: AppImage(handle: job.photos[i])),
                ),
              ),
            ),
          ],
        ],
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
          Icon(icon, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted)),
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

  Future<void> _selectOffer(
      BuildContext context, WidgetRef ref, Offer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ustayı seç'),
        content: Text(
            '${offer.artisanName} ustasını bu iş için seçmek istiyor musunuz? '
            'Bu işlem ilanı kapatır ve diğer ustalar bilgilendirilir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ustayı Seç')),
        ],
      ),
    );
    if (confirmed != true) return;

    final chatId = _chatIdFor(ref, offer);
    await ref.read(jobRepositoryProvider).selectOffer(
          jobId: job.jobId,
          offerId: offer.offerId,
          artisanId: offer.artisanId,
          chatId: chatId,
        );
    if (!context.mounted) return;
    context.showSuccess('Usta seçildi.');
    context.push(RoutePaths.chatThread(chatId));
  }

  /// Bu ustayla (zaten açılmış) sohbete gider; yoksa oluşturur (idempotent).
  String _chatIdFor(WidgetRef ref, Offer offer) {
    return ref.read(chatRepositoryProvider).startChat(
          customerUid: job.customerId,
          customerName: job.customerName,
          customerPhotoUrl: job.customerPhotoUrl,
          artisanUid: offer.artisanId,
          artisanName: offer.artisanName,
          artisanPhotoUrl: offer.artisanPhotoUrl,
        );
  }

  void _openChat(BuildContext context, WidgetRef ref, Offer offer) {
    final chatId = _chatIdFor(ref, offer);
    context.push(RoutePaths.chatThread(chatId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // İş bir ustaya bağlandıysa: yaşam döngüsü + sohbet + tamamlama/değerlendirme.
    if (job.status.isAssigned) {
      return _AssignedCard(job: job, isOwner: true);
    }
    if (job.effectiveStatus == JobStatus.expired) {
      return const _NoticeCard(
        icon: Icons.timer_off_outlined,
        text: 'Bu ilanın süresi doldu. Yeni bir ilan verebilirsiniz.',
      );
    }
    if (job.status == JobStatus.cancelled) {
      return _NoticeCard(
        icon: Icons.cancel_outlined,
        text:
            'İlan iptal edildi${job.cancelReason != null ? ' (${job.cancelReason!.labelTR})' : ''}.',
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
          loading: () => const Center(child: CircularProgressIndicator()),
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
                    onSelect: () => _selectOffer(context, ref, o),
                    onChat: () => _openChat(context, ref, o),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _cancelJob(context, ref, job),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('İlanı İptal Et'),
          ),
        ),
      ],
    );
  }
}

/// Müşterinin ilgilenen ustaları incelerken gördüğü usta özet kartı (#5).
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.onSelect,
    required this.onChat,
  });
  final Offer offer;
  final VoidCallback onSelect;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                  backgroundColor: AppColors.primaryContainer,
                  child: ClipOval(
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: offer.artisanPhotoUrl != null
                          ? AppImage(handle: offer.artisanPhotoUrl)
                          : const Icon(Icons.person,
                              color: AppColors.onPrimaryContainer),
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
                            const Icon(Icons.verified,
                                size: 16, color: AppColors.verified),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 15, color: AppColors.star),
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
                const Icon(Icons.chevron_right, color: AppColors.inkFaint),
              ],
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Sohbet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Ustayı Seç'),
                ),
              ),
            ],
          ),
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
        color: AppColors.premiumSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Premium',
          style: TextStyle(
              color: AppColors.premium, fontSize: 10, fontWeight: FontWeight.w800)),
    );
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(jobRepositoryProvider);
    final status = job.status;
    final myConfirmed =
        isOwner ? job.customerConfirmedDone : job.artisanConfirmedDone;
    final canConfirm = (status == JobStatus.workerSelected ||
            status == JobStatus.inProgress) &&
        !myConfirmed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LifecycleStepper(job: job),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sohbet
              if (job.chatId != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push(RoutePaths.chatThread(job.chatId!)),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Sohbete Git'),
                  ),
                ),

              // İşe başla (workerSelected → inProgress)
              if (status == JobStatus.workerSelected) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _busyGuard(
                        context, () => repo.markStarted(job.jobId)),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('İşe Başlandı'),
                  ),
                ),
              ],

              // Tamamlama onayları (iki taraflı, #10)
              if (status == JobStatus.workerSelected ||
                  status == JobStatus.inProgress) ...[
                const SizedBox(height: 14),
                _ConfirmRow(
                  customerDone: job.customerConfirmedDone,
                  artisanDone: job.artisanConfirmedDone,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success),
                    onPressed: canConfirm
                        ? () => _busyGuard(
                            context,
                            () => repo.confirmDone(
                                jobId: job.jobId, byCustomer: isOwner))
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(myConfirmed
                        ? 'Onayladınız, karşı taraf bekleniyor'
                        : 'İşi Tamamladım'),
                  ),
                ),
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

              // Müşteri iptal (tamamlanmadan önce, #11)
              if (isOwner &&
                  (status == JobStatus.workerSelected ||
                      status == JobStatus.inProgress)) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => _cancelJob(context, ref, job),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('İlanı İptal Et'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

/// Yaşam döngüsü adımlarını gösteren yatay stepper (#4).
class _LifecycleStepper extends StatelessWidget {
  const _LifecycleStepper({required this.job});
  final Job job;

  static const _steps = [
    ('Açık', JobStatus.open),
    ('Usta Seçildi', JobStatus.workerSelected),
    ('İş Sürüyor', JobStatus.inProgress),
    ('Tamamlandı', JobStatus.completed),
    ('Değerlendirildi', JobStatus.rated),
  ];

  int get _currentIndex {
    return switch (job.status) {
      JobStatus.open => 0,
      JobStatus.workerSelected => 1,
      JobStatus.inProgress => 2,
      JobStatus.completed => 3,
      JobStatus.rated => 4,
      JobStatus.cancelled => -1,
      JobStatus.expired => -1,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex < 0) {
      return const _InlineNotice(
        icon: Icons.info_outline,
        text: 'İlan artık aktif değil.',
      );
    }
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          _StepDot(
            label: _steps[i].$1,
            done: i <= _currentIndex,
            current: i == _currentIndex,
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < _currentIndex
                    ? AppColors.primary
                    : AppColors.border,
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
    final color = done ? AppColors.primary : AppColors.inkFaint;
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? AppColors.primary : AppColors.surface,
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

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.customerDone, required this.artisanDone});
  final bool customerDone;
  final bool artisanDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _ConfirmChip(label: 'Müşteri onayı', done: customerDone)),
        const SizedBox(width: 8),
        Expanded(child: _ConfirmChip(label: 'Usta onayı', done: artisanDone)),
      ],
    );
  }
}

class _ConfirmChip extends StatelessWidget {
  const _ConfirmChip({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: done ? AppColors.successSurface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: done ? AppColors.success : AppColors.inkFaint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.success : AppColors.inkMuted)),
          ),
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
        Icon(icon, size: 18, color: AppColors.success),
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

  Future<void> _contact(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    final draft = ref.read(myProfileControllerProvider).valueOrNull;
    if (user == null || draft == null) {
      context.showError('İletişime geçmek için profil bilgileriniz gerekli.');
      return;
    }
    final profile = draft.profile;
    if (profile.profession.isEmpty || profile.serviceAreas.isEmpty) {
      context.showError('Önce profilinizi (meslek + bölge) tamamlayın.');
      return;
    }

    final now = DateTime.now();
    // İlgi kaydı (fiyat/not yok) — müşteri "İlgilenen Ustalar"da görsün.
    final interest = Offer(
      offerId: Offer.idFor(job.jobId, user.uid),
      jobId: job.jobId,
      jobTitle: job.title,
      artisanId: user.uid,
      customerId: job.customerId,
      artisanName: draft.displayName,
      artisanPhotoUrl: draft.profilePhotoUrl,
      professionNameTR: kProfessionNames[profile.profession] ?? '',
      experienceYears: profile.experienceYears,
      rating: profile.averageRating,
      totalReviews: profile.totalReviews,
      isVerified: profile.isVerified,
      isPremium: profile.hasActivePremium,
      priceType: JobPriceType.inspection,
      price: null,
      note: '',
      status: OfferStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await ref.read(offerRepositoryProvider).submitOffer(interest);
      final chatId = ref.read(chatRepositoryProvider).startChat(
            customerUid: job.customerId,
            customerName: job.customerName,
            customerPhotoUrl: job.customerPhotoUrl,
            artisanUid: user.uid,
            artisanName: draft.displayName,
            artisanPhotoUrl: draft.profilePhotoUrl,
          );
      if (!context.mounted) return;
      context.push(RoutePaths.chatThread(chatId));
    } catch (_) {
      if (context.mounted) {
        context.showError('İletişim başlatılamadı, tekrar deneyin.');
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

    // Zaten iletişime geçildiyse: sohbete git / geri çek.
    final myOffers = ref.watch(myOffersProvider(user?.uid ?? '')).valueOrNull;
    Offer? existing;
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(existing != null ? 'İletişimdesiniz' : 'Bu işle ilgileniyor musunuz?',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            existing != null
                ? 'Müşteriyle sohbet başlattınız. Ayrıntıları sohbet üzerinden '
                    'konuşabilirsiniz.'
                : 'Müşteriyle doğrudan sohbet başlatın; işi ve fiyatı birlikte '
                    'konuşun.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          if (existing != null)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _contact(context, ref),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Sohbete Git'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _withdraw(context, ref),
                  child: const Text('Geri Çek'),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _contact(context, ref),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('İletişime Geç'),
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
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.inkMuted))),
        ],
      ),
    );
  }
}
