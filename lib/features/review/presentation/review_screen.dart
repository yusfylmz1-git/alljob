import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/review.dart';
import '../../artisan/data/artisan_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/review_repository.dart';

/// Değerlendirme ekranı — KİŞİ BAZLI (2026-08-08).
///
/// Herkes herkesi değerlendirebilir: müşteri ustayı, usta müşteriyi. Profil
/// sayfasındaki "Değerlendir" düğmesi doğrudan buraya gelir.
///
/// **Bir kişiye bir değerlendirme.** Doküman kimliği `rev_{yazan}__{hedef}`
/// olduğu için ikinci gönderim yeni kayıt açmaz, mevcut kaydı GÜNCELLER;
/// ekran bunu dilinde de gösterir ("Değerlendirmeyi Güncelle").
///
/// Eskiden ekran ilana bağlıydı ve yalnız iş `completed` olunca açılıyordu.
/// İş akışı kaldırılınca (2026-08-08) o koşul hiç sağlanmaz oldu — yani
/// değerlendirme fiilen kilitliydi. İlan bağımlılığı tamamen kalktı.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.targetUid});

  /// Puanı ALACAK kişi. Usta da olabilir müşteri de — ekran ayrım yapmaz.
  final String targetUid;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _rating = 0;
  final Set<String> _tags = {};
  bool _sending = false;

  /// Bu kişiyi daha önce değerlendirdiysem true: form ön-dolu gelir ve
  /// gönderim mevcut kaydı günceller.
  bool _isUpdate = false;

  /// Ön-dolgu denemesi bitti mi? Bitmeden form çizilirse kullanıcı boş yıldız
  /// görür, sonra değerler altından değişir.
  bool _yuklendi = false;

  @override
  void initState() {
    super.initState();
    _mevcuduYukle();
  }

  Future<void> _mevcuduYukle() async {
    final me = ref.read(currentUserProvider)?.uid;
    if (me == null) {
      if (mounted) setState(() => _yuklendi = true);
      return;
    }
    try {
      final mevcut = await ref.read(reviewRepositoryProvider).getMyReview(
            authorUid: me,
            targetUid: widget.targetUid,
          );
      if (!mounted) return;
      setState(() {
        _yuklendi = true;
        if (mevcut == null) return;
        _isUpdate = true;
        _rating = mevcut.rating;
        _tags
          ..clear()
          ..addAll(mevcut.tags);
      });
    } catch (_) {
      // Ön-dolgu kritik değil; form boş kalır ama ekran yine de açılır.
      if (mounted) setState(() => _yuklendi = true);
    }
  }

  void _toggle(String tag) => setState(() {
        if (!_tags.remove(tag)) _tags.add(tag);
      });

  Future<void> _submit() async {
    if (_rating == 0) {
      context.showError('Lütfen 1–5 arası puan verin.');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null || _sending) return;

    setState(() => _sending = true);
    try {
      // Yön yalnız "kim kimi puanladı" bilgisidir; GÖRÜNÜRLÜĞÜ etkilemez.
      // Hedefin usta profili varsa müşteri→usta, yoksa usta→müşteri sayılır.
      final hedefUsta = await ref
          .read(artisanDetailProvider(widget.targetUid).future)
          .then<bool>((v) => v != null, onError: (_) => false);

      await ref.read(reviewRepositoryProvider).addReview(
            authorUid: user.uid,
            targetUid: widget.targetUid,
            authorName: user.displayName,
            rating: _rating,
            tags: _tags.toList(),
            direction: hedefUsta
                ? ReviewDirection.customerToArtisan
                : ReviewDirection.artisanToCustomer,
          );
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        context.showError('Değerlendirme gönderilemedi, tekrar deneyin.');
      }
      return;
    }
    if (!mounted) return;

    // Hedefin profili ve listeleri yeni puanı göstersin.
    ref.invalidate(artisanDetailProvider(widget.targetUid));
    ref.invalidate(artisanReviewsProvider(widget.targetUid));
    ref.invalidate(reviewsForUserProvider(widget.targetUid));
    ref.invalidate(myReviewForProvider(
        (authorUid: user.uid, targetUid: widget.targetUid)));

    context.showSuccess(_isUpdate
        ? 'Değerlendirmeniz güncellendi.'
        : 'Değerlendirmeniz için teşekkürler!');
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    // Misafir yazamaz (kural: isSignedIn). Çıkışsız ekran bırakma.
    if (user == null) {
      return const _Bilgi(
        icon: Icons.lock_outline_rounded,
        baslik: 'Giriş gerekiyor',
        metin: 'Değerlendirme yapabilmek için giriş yapmalısınız.',
      );
    }

    // Kendini değerlendirme (kural: customerUID != artisanUID).
    if (user.uid == widget.targetUid) {
      return const _Bilgi(
        icon: Icons.person_outline_rounded,
        baslik: 'Kendinizi değerlendiremezsiniz',
        metin: 'Bu sayfa başka bir kullanıcıyı değerlendirmek içindir.',
      );
    }

    if (!_yuklendi) {
      return Scaffold(
        appBar: AppBar(title: const Text('Değerlendir')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isUpdate ? 'Değerlendirmeyi Güncelle' : 'Değerlendir'),
      ),
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
                        'Bu kişiyi daha önce değerlendirdiniz. '
                        'Gönderdiğinizde önceki değerlendirmeniz güncellenir.',
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
            Text('Deneyimini nasıl buldun?',
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

/// Ekranın açılamadığı durumlar için ÇIKIŞI OLAN bilgi sayfası.
class _Bilgi extends StatelessWidget {
  const _Bilgi({
    required this.icon,
    required this.baslik,
    required this.metin,
  });

  final IconData icon;
  final String baslik;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Değerlendir')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(baslik, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                metin,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () {
                  if (context.canPop()) context.pop();
                },
                child: const Text('Geri dön'),
              ),
            ],
          ),
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
