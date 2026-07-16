import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/job.dart';

/// İş tamamlama metinleri ve durum özeti (ilan detay + sohbet şeridi).
class JobCompletionCopy {
  JobCompletionCopy._({
    required this.headline,
    required this.detail,
    required this.confirmLabel,
    required this.confirmedLabel,
    required this.canConfirm,
    required this.showCountdown,
    this.remaining,
  });

  final String headline;
  final String detail;
  final String confirmLabel;
  final String confirmedLabel;
  final bool canConfirm;
  final bool showCountdown;
  final Duration? remaining;

  /// [isOwner] = müşteri (ilan sahibi).
  factory JobCompletionCopy.of(Job job, {required bool isOwner}) {
    final status = job.status;
    final myDone =
        isOwner ? job.customerConfirmedDone : job.artisanConfirmedDone;
    final otherDone =
        isOwner ? job.artisanConfirmedDone : job.customerConfirmedDone;
    final canConfirm = (status == JobStatus.workerSelected ||
            status == JobStatus.inProgress) &&
        !myDone;

    final confirmLabel = isOwner
        ? 'İş bitti, onaylıyorum'
        : 'İşi teslim ettim';
    const confirmedLabel = 'Onayladınız · karşı taraf bekleniyor';

    if (status == JobStatus.disputed) {
      return JobCompletionCopy._(
        headline: 'Sorun bildirildi — iş beklemede',
        detail:
            'Anlaşmazlık çözülene dek tamamlanma onayı alınamaz. Gerekirse '
            'şikayeti geri çekin veya sohbetten konuşun.',
        confirmLabel: confirmLabel,
        confirmedLabel: confirmedLabel,
        canConfirm: false,
        showCountdown: false,
      );
    }

    if (status == JobStatus.completed) {
      return JobCompletionCopy._(
        headline: 'İş tamamlandı',
        detail: isOwner
            ? 'Her iki taraf onayladı. İsterseniz ustayı değerlendirin.'
            : 'İş bitti. Değerlendirme müşteriden bekleniyor.',
        confirmLabel: confirmLabel,
        confirmedLabel: confirmedLabel,
        canConfirm: false,
        showCountdown: false,
      );
    }

    if (status == JobStatus.rated) {
      return JobCompletionCopy._(
        headline: 'İş tamamlandı ve değerlendirildi',
        detail: 'Teşekkürler — bu iş kapanmış durumda.',
        confirmLabel: confirmLabel,
        confirmedLabel: confirmedLabel,
        canConfirm: false,
        showCountdown: false,
      );
    }

    if (status != JobStatus.workerSelected && status != JobStatus.inProgress) {
      return JobCompletionCopy._(
        headline: status.labelTR,
        detail: 'Bu aşamada tamamlama onayı yok.',
        confirmLabel: confirmLabel,
        confirmedLabel: confirmedLabel,
        canConfirm: false,
        showCountdown: false,
      );
    }

    // Aktif iş: onay durumu.
    final remaining = job.autoCompleteAt?.difference(DateTime.now());
    final showCountdown = myDone != otherDone &&
        job.autoCompleteAt != null &&
        (remaining == null || !remaining.isNegative);

    if (!myDone && !otherDone) {
      return JobCompletionCopy._(
        headline: status == JobStatus.workerSelected
            ? 'Usta seçildi · iş sürüyor'
            : 'İş sürüyor',
        detail: isOwner
            ? 'İş bittiğinde “İş bitti, onaylıyorum” deyin. Usta da onaylayınca '
                'iş kapanır.'
            : 'İşi bitirince “İşi teslim ettim” deyin. Müşteri de onaylayınca '
                'iş kapanır.',
        confirmLabel: confirmLabel,
        confirmedLabel: confirmedLabel,
        canConfirm: canConfirm,
        showCountdown: false,
      );
    }

    if (myDone && !otherDone) {
      final wait = remaining != null && !remaining.isNegative
          ? ' Kalan süre: ${formatRemaining(remaining)}.'
          : '';
      return JobCompletionCopy._(
        headline: 'Siz onayladınız · karşı taraf bekleniyor',
        detail:
            '${isOwner ? "Usta" : "Müşteri"} onaylamazsa süre dolunca iş '
            'otomatik tamamlanır.$wait',
        confirmLabel: confirmLabel,
        confirmedLabel: confirmedLabel,
        canConfirm: false,
        showCountdown: showCountdown,
        remaining: remaining,
      );
    }

    // otherDone && !myDone
    final wait = remaining != null && !remaining.isNegative
        ? ' Otomatik tamamlanmaya: ${formatRemaining(remaining)}.'
        : '';
    return JobCompletionCopy._(
      headline: isOwner
          ? 'Usta işi teslim etti · sizin onayınız bekleniyor'
          : 'Müşteri onayladı · sizin onayınız bekleniyor',
      detail:
          'Onaylarsanız iş hemen tamamlanır.$wait '
          'Yanıt vermezseniz süre sonunda sistem kapatır.',
      confirmLabel: confirmLabel,
      confirmedLabel: confirmedLabel,
      canConfirm: canConfirm,
      showCountdown: showCountdown,
      remaining: remaining,
    );
  }

  static String formatRemaining(Duration d) {
    if (d.isNegative) return 'süre doldu';
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final mins = d.inMinutes.remainder(60);
    if (days > 0) {
      return hours > 0 ? '${days}g ${hours}s' : '$days gün';
    }
    if (hours > 0) {
      return mins > 0 ? '${hours}s ${mins}dk' : '$hours saat';
    }
    if (mins > 0) return '$mins dakika';
    return 'az kaldı';
  }
}

/// Tek satırlık durum bandı (ilan detay / sohbet üstü).
class JobCompletionStatusBanner extends StatelessWidget {
  const JobCompletionStatusBanner({
    super.key,
    required this.job,
    required this.isOwner,
    this.compact = false,
    this.onOpenJob,
  });

  final Job job;
  final bool isOwner;
  final bool compact;
  final VoidCallback? onOpenJob;

  @override
  Widget build(BuildContext context) {
    final copy = JobCompletionCopy.of(job, isOwner: isOwner);
    final palette = context.palette;
    final waitingOther = (job.status == JobStatus.workerSelected ||
            job.status == JobStatus.inProgress) &&
        (isOwner ? job.customerConfirmedDone : job.artisanConfirmedDone) &&
        !(isOwner ? job.artisanConfirmedDone : job.customerConfirmedDone);
    final waitingMe = (job.status == JobStatus.workerSelected ||
            job.status == JobStatus.inProgress) &&
        !(isOwner ? job.customerConfirmedDone : job.artisanConfirmedDone) &&
        (isOwner ? job.artisanConfirmedDone : job.customerConfirmedDone);

    final Color bg;
    final Color fg;
    final IconData icon;
    if (job.status == JobStatus.disputed) {
      bg = palette.warningSurface;
      fg = palette.warning;
      icon = Icons.report_gmailerrorred_outlined;
    } else if (job.status == JobStatus.completed ||
        job.status == JobStatus.rated) {
      bg = palette.successSurface;
      fg = palette.success;
      icon = Icons.check_circle_outline;
    } else if (waitingMe) {
      bg = palette.infoSurface;
      fg = palette.info;
      icon = Icons.priority_high_rounded;
    } else if (waitingOther) {
      bg = palette.surfaceMuted;
      fg = palette.inkMuted;
      icon = Icons.hourglass_top_rounded;
    } else {
      bg = palette.primaryContainer;
      fg = palette.primary;
      icon = Icons.handyman_outlined;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      child: InkWell(
        onTap: onOpenJob,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 10 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: compact ? 20 : 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.headline,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 13 : 14,
                        color: fg,
                        height: 1.2,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        copy.detail,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: palette.inkMuted,
                        ),
                      ),
                    ] else if (copy.showCountdown &&
                        copy.remaining != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Kalan: ${JobCompletionCopy.formatRemaining(copy.remaining!)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onOpenJob != null)
                Icon(Icons.chevron_right, color: palette.inkFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Müşteri / usta onay chip'leri.
class JobConfirmRow extends StatelessWidget {
  const JobConfirmRow({
    super.key,
    required this.customerDone,
    required this.artisanDone,
  });

  final bool customerDone;
  final bool artisanDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Chip(label: 'Müşteri onayı', done: customerDone),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Chip(label: 'Usta onayı', done: artisanDone),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: done ? palette.successSurface : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: done ? palette.success : palette.inkFaint,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: done ? palette.success : palette.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
