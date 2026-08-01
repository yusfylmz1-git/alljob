import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../data/models/job.dart';
import '../../../data/models/review.dart';
import '../../artisan/data/artisan_providers.dart';
import '../../auth/application/auth_controller.dart';
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

  /// Bu ekranı açan kullanıcı USTA mı? Öyleyse değerlendirme yönü tersine
  /// döner: usta müşteriyi puanlar (a2c).
  bool get _iAmArtisan =>
      ref.read(currentUserProvider)?.uid == widget.artisanUid;

  ReviewDirection get _direction => _iAmArtisan
      ? ReviewDirection.artisanToCustomer
      : ReviewDirection.customerToArtisan;

  /// Değerlendirilen sohbetin kimliği. İlan üzerinden gelindiyse İLAN BAZLI
  /// kimlik kullanılır (`..__{jobId}`) — aynı çift her iş için ayrı puan
  /// verebilsin. İlan yoksa eski iki parçalı (genel sohbet) kimliği.
  ///
  /// Kimlik HER İKİ YÖNDE de aynı: `chat_{müşteri}__{usta}[__{iş}]`. Usta
  /// değerlendirirken müşterinin uid'i ilandan gelir.
  String _chatIdFor({required String customerUid}) =>
      FirebaseChatRepository.chatIdFor(
        customerUid,
        widget.artisanUid,
        jobId: widget.jobId,
      );

  /// Sohbetin müşteri tarafı — İLANDAN okunur (tek kaynak).
  ///
  /// Eskiden usta tarafında `ref.read` ile okunuyordu ve stream ilk değerini
  /// yaymadan çağrıldığı için null dönüyordu; ekran "önce sohbet gerekiyor"
  /// deyip kullanıcıyı geri çeviriyordu. Artık `build` içinde `watch` edilen
  /// ilandan geçiliyor, yarış yok.
  String? _customerUidFrom(Job? job) => job?.customerId;

  void _toggle(String tag) => setState(() {
        if (!_tags.remove(tag)) _tags.add(tag);
      });

  bool _sending = false;

  /// Bu taraf daha önce değerlendirdiyse true: form ön-dolu gelir ve gönderim
  /// mevcut kaydı GÜNCELLER.
  bool _isUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  /// Mevcut değerlendirmeyi yükler (ön-dolgu).
  ///
  /// İlanı `future` ile BEKLER — `valueOrNull` ile okumak stream'in ilk
  /// değerinden önce null döndürüyordu ve "daha önce değerlendirmiştim" hâli
  /// kaçıyordu.
  Future<void> _loadExisting() async {
    if (widget.jobId == null) return;
    try {
      final job = await ref.read(jobProvider(widget.jobId!).future);
      final customerUid = _customerUidFrom(job);
      if (customerUid == null || !mounted) return;
      final existing = await ref.read(reviewRepositoryProvider).getMyReview(
            customerUid: customerUid,
            artisanUid: widget.artisanUid,
            chatId: _chatIdFor(customerUid: customerUid),
            direction: _direction,
          );
      if (!mounted) return;
      if (existing == null) return;
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
      // İlanı BEKLE: müşteri uid'i tek kaynak olarak ilandan gelir.
      final job = widget.jobId == null
          ? null
          : await ref.read(jobProvider(widget.jobId!).future);
      final customerUid = _customerUidFrom(job);
      if (customerUid == null) {
        if (!mounted) return;
        setState(() => _sending = false);
        context.showError('Değerlendirme başlatılamadı, tekrar deneyin.');
        return;
      }
      if (!mounted) return;
      await ref.read(reviewRepositoryProvider).addReview(
            artisanUid: widget.artisanUid,
            customerUid: customerUid,
            // a2c'de "customerDisplayName" alanı YAZAN ustanın adını taşır
            // (kayıt sahibi kim ise onun görünen adı).
            customerName: user.displayName,
            chatId: _chatIdFor(customerUid: customerUid),
            rating: _rating,
            tags: _tags.toList(),
            jobId: widget.jobId,
            direction: _direction,
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

    // TEK KOŞUL: iş tamamlandıysa iki taraf da değerlendirir.
    //
    // Önceden üç ayrı async kontrol vardı (sohbet var mı + 24 saat sohbet yaşı
    // + mevcut kayıt) ve her biri kendi yarış durumunu üretiyordu; sonuç
    // kullanıcının çıkışsız "Önce sohbet gerekiyor" ekranında kalmasıydı.
    // İlan zaten canlı izleniyor, ek kaynağa gerek yok.
    final jobAsync =
        widget.jobId != null ? ref.watch(jobProvider(widget.jobId!)) : null;
    final job = jobAsync?.valueOrNull;

    // İlan yüklenene kadar karar verme.
    if (widget.jobId != null && (jobAsync?.isLoading ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Değerlendir')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final iAmParty = job != null &&
        user != null &&
        (job.customerId == user.uid || job.selectedArtisanId == user.uid);
    final jobDone = job != null &&
        (job.status == JobStatus.completed || job.status == JobStatus.rated);
    // Güncelleme (mevcut kayıt) her zaman açık — puanını düzeltebilmeli.
    final unlocked = _isUpdate ||
        (iAmParty && jobDone && job.selectedArtisanId == widget.artisanUid);

    if (!unlocked) {
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
                Text('Değerlendirme henüz açılmadı',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'İş tamamlandıktan sonra siz ve karşı taraf birbirinizi '
                  'değerlendirebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                // Çıkışsız ekran bırakma: kullanıcı buradan dönebilsin.
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
