import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/responsive_center.dart';
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
          );
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        context.showError('Değerlendirme gönderilemedi. Tekrar deneyin.');
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

    context.showSuccess('Değerlendirmeniz için teşekkürler!');
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    // Değerlendirme yalnızca ilgili usta ile sohbet geçmişi olan müşteriye
    // açıktır (PRD §5, Ekran F).
    final canReview = user != null &&
        ref.read(chatRepositoryProvider).hasChatBetween(
              customerUid: user.uid,
              artisanUid: widget.artisanUid,
            );

    if (!canReview) {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Değerlendir')),
      body: ResponsiveCenter(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
              color: AppColors.success,
              onToggle: _toggle,
            ),
            const SizedBox(height: 20),
            _TagGroup(
              title: 'Olumsuz',
              tags: ReviewTags.negative,
              selected: _tags,
              color: AppColors.danger,
              onToggle: _toggle,
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Değerlendirmeyi Gönder',
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
              color: AppColors.star,
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
