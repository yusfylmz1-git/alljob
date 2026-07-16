import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/job.dart';
import '../../../data/models/review.dart';
import '../../artisan/data/artisan_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/data/chat_providers.dart';
import '../../chat/data/firebase_chat_repository.dart';
import '../../jobs/data/job_providers.dart';
import '../data/review_repository.dart';

/// Ekran F — İş Sonu Değerlendirme. 1–5 yıldız + hazır etiketler.
/// Serbest metin yorum yoktur (PRD §3).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.artisanUid, this.jobId});
  final String artisanUid;

  /// İlan üzerinden geliniyorsa: değerlendirme sonrası ilan `rated` olur (#4).
  final String? jobId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _rating = 0;
  final Set<String> _tags = {};

  void _toggle(String tag) => setState(() {
        if (!_tags.remove(tag)) _tags.add(tag);
      });

  bool _sending = false;

  /// Müşteri bu ustayı daha önce değerlendirmişse true: form önceki puan ve
  /// etiketlerle ön-dolu gelir, gönderim mevcut kaydı GÜNCELLER.
  bool _isUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final existing = await ref.read(reviewRepositoryProvider).getMyReview(
            customerUid: user.uid,
            artisanUid: widget.artisanUid,
            chatId: FirebaseChatRepository.chatIdFor(
                user.uid, widget.artisanUid),
          );
      if (existing == null || !mounted) return;
      setState(() {
        _isUpdate = true;
        _rating = existing.rating;
        _tags
          ..clear()
          ..addAll(existing.tags);
      });
    } catch (_) {/* ön-dolgu kritik değil; form boş kalır */}
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      context.showError('Lütfen 1–5 arası puan verin.');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(reviewRepositoryProvider).addReview(
            artisanUid: widget.artisanUid,
            customerUid: user.uid,
            customerName: user.displayName,
            chatId: FirebaseChatRepository.chatIdFor(
                user.uid, widget.artisanUid),
            rating: _rating,
            tags: _tags.toList(),
            jobId: widget.jobId,
          );
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        context.showError('Değerlendirme gönderilemedi, tekrar deneyin.');
      }
      return;
    }
    // İlan üzerinden gelindiyse ilanı "değerlendirildi" olarak işaretle (#4).
    if (widget.jobId != null) {
      try {
        await ref.read(jobRepositoryProvider).markRated(widget.jobId!);
      } catch (_) {/* değerlendirme yazıldı; ilan işaretlemesi kritik değil */}
    }
    if (!mounted) return;

    // Profil ekranı ve usta paneli yeni puanı göstersin.
    ref.invalidate(artisanDetailProvider(widget.artisanUid));
    ref.invalidate(artisanReviewsProvider(widget.artisanUid));

    context.showSuccess(_isUpdate
        ? 'Değerlendirmeniz güncellendi.'
        : 'Değerlendirmeniz için teşekkürler!');
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final chatId = user == null
        ? null
        : FirebaseChatRepository.chatIdFor(user.uid, widget.artisanUid);

    // Sohbet var mı? (PRD §5)
    final hasChat = user != null &&
        ref.read(chatRepositoryProvider).hasChatBetween(
              customerUid: user.uid,
              artisanUid: widget.artisanUid,
            );

    // H6: tamamlanmış iş VEYA sohbet yaşı ≥ 24s.
    final jobAsync =
        widget.jobId != null ? ref.watch(jobProvider(widget.jobId!)) : null;
    final job = jobAsync?.valueOrNull;
    final jobUnlocks = job != null &&
        user != null &&
        job.customerId == user.uid &&
        job.selectedArtisanId == widget.artisanUid &&
        (job.status == JobStatus.completed || job.status == JobStatus.rated);

    final thread =
        chatId != null ? ref.read(chatRepositoryProvider).getThread(chatId) : null;
    final chatAgeOk = thread != null &&
        DateTime.now().difference(thread.openedAt) >=
            AppConstants.reviewUnlockDuration;
    // Güncelleme (mevcut review) kilitsiz; yeni create kilitli.
    final unlocked = _isUpdate || jobUnlocks || chatAgeOk;

    if (!hasChat) {
      return Scaffold(
        appBar: AppBar(title: const Text('Değerlendir')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined,
                    size: 56, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('Önce sohbet gerekiyor',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Bir ustayı değerlendirebilmek için önce onunla sohbet '
                  'başlatmış olmanız gerekir.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!unlocked) {
      final hours = AppConstants.reviewUnlockDuration.inHours;
      return Scaffold(
        appBar: AppBar(title: const Text('Değerlendir')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule,
                    size: 56, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('Değerlendirme henüz açılamadı',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Sohbet başladıktan en az $hours saat sonra veya iş '
                  'tamamlandıktan sonra değerlendirme yapabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Değerlendir')),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_isUpdate) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.infoSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        color: context.palette.info, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu ustayı daha önce değerlendirdiniz. Gönderdiğinizde '
                        'önceki değerlendirmeniz güncellenir.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: context.palette.info,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('İşi nasıl buldunuz?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _StarPicker(
              rating: _rating,
              onChanged: (r) => setState(() => _rating = r),
            ),
            const SizedBox(height: 24),
            _TagGroup(
              title: 'Olumlu',
              tags: ReviewTags.positive,
              selected: _tags,
              color: context.palette.success,
              onToggle: _toggle,
            ),
            const SizedBox(height: 20),
            _TagGroup(
              title: 'Olumsuz',
              tags: ReviewTags.negative,
              selected: _tags,
              color: context.palette.danger,
              onToggle: _toggle,
            ),
            const SizedBox(height: 28),
            AppButton(
              label: _isUpdate
                  ? 'Değerlendirmeyi Güncelle'
                  : 'Değerlendirmeyi Gönder',
              icon: Icons.send_rounded,
              isLoading: _sending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.rating, required this.onChanged});
  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            iconSize: 44,
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: context.palette.star,
            ),
          ),
      ],
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.title,
    required this.tags,
    required this.selected,
    required this.color,
    required this.onToggle,
  });

  final String title;
  final List<String> tags;
  final Set<String> selected;
  final Color color;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((t) {
            final isSel = selected.contains(t);
            return FilterChip(
              label: Text(t),
              selected: isSel,
              onSelected: (_) => onToggle(t),
              showCheckmark: false,
              selectedColor: color.withValues(alpha: 0.16),
              side: BorderSide(
                  color: isSel ? color : Theme.of(context).dividerColor),
              labelStyle: TextStyle(
                color: isSel ? color : null,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
