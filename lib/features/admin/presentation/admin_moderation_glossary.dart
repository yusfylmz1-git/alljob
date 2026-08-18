import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Admin moderasyon terimleri — operatör "bu düğme ne yapıyor?" sorusunu
/// panel içinde yanıtlar. Kod/CF adları değil, iş etkisi.
abstract final class AdminModerationGlossary {
  static const entries = <_GlossaryEntry>[
    _GlossaryEntry(
      title: 'Platform onayı',
      shortLabel: 'Platform onayla',
      icon: Icons.verified,
      summary:
          'Ustaya “platform onaylı” mavi tik benzeri güven sinyali verir. '
          'SMS doğrulaması kaldırıldığından (2026-08-18) rozetin TEK '
          'kaynağı budur.',
      details:
          '• Ne işe yarar?\n'
          '  Keşfet / profilde “Platform onaylı usta” rozeti çıkar. '
          'Ekibin güvendiği (tanınmış usta, yüz yüze doğrulama, belge '
          'incelemesi sonrası) profilleri öne çıkarmak için.\n\n'
          '• Neden gerekli?\n'
          '  Uygulamada otomatik doğrulama YOK; rozet yalnız sizin manuel '
          'güvencenizdir. Sahte / düşük kaliteli vitrini ayırır.\n\n'
          '• Ne YAPMAZ?\n'
          '  Hesabı askıya almaz, ilan yazmayı engellemez, Premium vermez. '
          'Yalnız vitrin güven rozetidir.\n\n'
          '• Kaldırınca?\n'
          '  Rozet düşer; usta hesabı ve vitrin (gizli değilse) kalır.',
    ),
    _GlossaryEntry(
      title: 'Vitrini gizle',
      shortLabel: 'Gizle',
      icon: Icons.visibility_off_outlined,
      summary:
          'Usta vitrinini Keşfet / aramadan düşürür. Hesap silinmez; '
          'usta paneline girebilir ama müşteriye görünmez.',
      details:
          '• Ne işe yarar?\n'
          '  Şikayet, spam vitrin, yanlış meslek, inceleme bitene kadar '
          'geçici görünmezlik.\n\n'
          '• Askıdan farkı?\n'
          '  Gizle = yalnız vitrin (Keşfet). Askı = hesabın içerik '
          'üretmesi de engellenir (ilan, teklif, mesaj kuralları).\n\n'
          '• Ürün/ilan “gizle”si ayrıdır\n'
          '  Ürün veya ilan kartındaki gizleme o kaydı vitrinden düşürür; '
          'tüm hesabı etkilemez.',
    ),
    _GlossaryEntry(
      title: 'Hesap askıda',
      shortLabel: 'Askıya al',
      icon: Icons.gpp_bad_outlined,
      summary:
          'Kullanıcının (müşteri veya usta) içerik üretmesini sunucu '
          'tarafında engeller. En sert moderasyon adımıdır.',
      details:
          '• Ne işe yarar?\n'
          '  Spam, taciz, dolandırıcılık, KVKK ihlali gibi durumlarda '
          'hesabı dondurmak.\n\n'
          '• Teknik olarak?\n'
          '  Custom claim `suspended:true` + `users.suspended`. '
          'Firestore kuralları yazmayı reddeder.\n\n'
          '• Ne kalır?\n'
          '  Giriş yapabilir (genelde “askıdasınız” görür) ama ilan, '
          'mesaj, ürün vb. oluşturamaz. Eski verisi silinmez.\n\n'
          '• Geri açınca?\n'
          '  Askı kalkar; önceki vitrin gizliyse o ayrı düğmeyle açılır.',
    ),
    _GlossaryEntry(
      title: 'Öne çıkar',
      shortLabel: 'Öne çıkar',
      icon: Icons.star_outline,
      summary: 'Ustayı Keşfet sıralamasında / vitrinde vurgular (featured).',
      details:
          'Kampanya veya el ile seçilmiş “öne çıkan ustalar” için. '
          'Platform onayından farklıdır; güven rozeti değil, vitrin '
          'sırası / etiket sinyalidir.',
    ),
    _GlossaryEntry(
      title: 'Premium (manuel)',
      shortLabel: 'Premium',
      icon: Icons.workspace_premium_outlined,
      summary:
          'Play aboneliği olmadan süre tanımlı premium verir veya iptal eder.',
      details:
          'Destek / telafi / kampanya. Gerekçe zorunludur (denetim). '
          'Gerçek Play satın almasını bozmaz; manuel müdahale ayrı tutulur.',
    ),
    _GlossaryEntry(
      title: 'Belge incelemesi',
      shortLabel: 'Belgeler',
      icon: Icons.badge_outlined,
      summary: 'Yüklenen yeterlilik belgelerini onaylar veya reddeder.',
      details:
          'Onay = “Belgeli usta” rozeti. Mavi tik / platform onayı DEĞİLDİR. '
          'Redde gerekçe zorunlu — usta neyi düzelteceğini görür.',
    ),
  ];

  static Future<void> show(BuildContext context, {String? highlightTitle}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        return SizedBox(
          height: h * 0.85,
          child: _GlossarySheet(highlightTitle: highlightTitle),
        );
      },
    );
  }
}

class _GlossaryEntry {
  const _GlossaryEntry({
    required this.title,
    required this.shortLabel,
    required this.icon,
    required this.summary,
    required this.details,
  });
  final String title;
  final String shortLabel;
  final IconData icon;
  final String summary;
  final String details;
}

class _GlossarySheet extends StatelessWidget {
  const _GlossarySheet({this.highlightTitle});
  final String? highlightTitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final entries = [...AdminModerationGlossary.entries];
    if (highlightTitle != null) {
      entries.sort((a, b) {
        final ah = a.title == highlightTitle || a.shortLabel == highlightTitle;
        final bh = b.title == highlightTitle || b.shortLabel == highlightTitle;
        if (ah == bh) return 0;
        return ah ? -1 : 1;
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text(
          'Moderasyon sözlüğü',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Düğmelerin kullanıcıya ve sisteme gerçek etkisi. '
          'Rol atamak (admin yapmak) buraya girmez → Kadro sekmesi.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.inkMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        for (final e in entries) ...[
          _EntryCard(entry: e, highlight: highlightTitle != null &&
              (e.title == highlightTitle || e.shortLabel == highlightTitle)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, this.highlight = false});
  final _GlossaryEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? palette.primary.withValues(alpha: 0.06) : palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? palette.primary.withValues(alpha: 0.4) : palette.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(entry.icon, size: 20, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkMuted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            entry.details,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// AppBar / filtre satırına konan “Ne demek?” düğmesi.
class AdminHelpButton extends StatelessWidget {
  const AdminHelpButton({super.key, this.highlightTitle});
  final String? highlightTitle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Moderasyon sözlüğü',
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: () => AdminModerationGlossary.show(
        context,
        highlightTitle: highlightTitle,
      ),
    );
  }
}

/// Liste üstü kısa ipucu şeridi.
class AdminHintBanner extends StatelessWidget {
  const AdminHintBanner({
    super.key,
    required this.text,
    this.onHelp,
  });

  final String text;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Material(
      color: palette.infoSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: palette.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.inkMuted,
                  height: 1.3,
                ),
              ),
            ),
            if (onHelp != null)
              TextButton(
                onPressed: onHelp,
                child: const Text('Sözlük'),
              ),
          ],
        ),
      ),
    );
  }
}
