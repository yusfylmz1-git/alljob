import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/responsive_center.dart';
import '../membership_package.dart';

/// Plan seçimi (Ücretsiz / Beta / Pro).
/// [changing] true → Profil’den plan değiştirme (geri oku + pop).
class PackageSelectScreen extends ConsumerStatefulWidget {
  const PackageSelectScreen({super.key, this.changing = false});

  final bool changing;

  @override
  ConsumerState<PackageSelectScreen> createState() =>
      _PackageSelectScreenState();
}

class _PackageSelectScreenState extends ConsumerState<PackageSelectScreen> {
  late MembershipPackage _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(selectedMembershipPackageProvider) ??
        MembershipPackage.beta;
  }

  Future<void> _confirm() async {
    if (_selected == MembershipPackage.pro) {
      // Pro = Play abonelik; plan tercihi kaydedilir, ödeme Premium ekranında.
      final go = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pro abonelik'),
          content: const Text(
            'Pro, Google Play aboneliği ile açılır. Beta ile de tüm Pro '
            'özellikleri ücretsiz kullanabilirsiniz. Şimdi ne yapmak istersiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'back'),
              child: const Text('Geri'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'beta'),
              child: const Text('Beta ile devam'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'pro'),
              child: const Text('Pro seç + ödeme'),
            ),
          ],
        ),
      );
      if (go == null || go == 'back' || !mounted) return;
      if (go == 'beta') {
        await _persist(MembershipPackage.beta);
        return;
      }
      await _persist(MembershipPackage.pro);
      if (!mounted) return;
      context.push(RoutePaths.panelPremium);
      return;
    }
    await _persist(_selected);
  }

  Future<void> _persist(MembershipPackage package) async {
    setState(() => _saving = true);
    await saveMembershipPackage(package);
    await AppAnalytics.packageSelected(package: package.name);
    if (!mounted) return;
    ref.read(packageSelectionSeenProvider.notifier).state = true;
    ref.read(selectedMembershipPackageProvider.notifier).state = package;
    setState(() => _saving = false);
    context.showSuccess(
      package == MembershipPackage.beta
          ? 'Beta planı seçildi — Pro özellikler açık.'
          : package == MembershipPackage.pro
              ? 'Pro seçildi — Play ile abone olabilirsiniz.'
              : 'Ücretsiz planla devam ediyorsunuz.',
    );
    if (widget.changing && context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 28),
                child: Column(
                  children: [
                    if (widget.changing)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: BackButton(
                          color: Colors.white,
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(RoutePaths.profile),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    const BrandMark(size: 56),
                    const SizedBox(height: 14),
                    Text(
                      widget.changing ? 'Planını değiştir' : 'Planını seç',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Müşteri için her şey ücretsiz. Usta Pro özellikleri '
                      'Beta’da açık; ücretli Pro Google Play aboneliği ile.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ResponsiveCenter(
              maxWidth: 960,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 720;
                      final cards = [
                        for (final p in MembershipPackage.values)
                          _PackageCard(
                            package: p,
                            selected: _selected == p,
                            recommended: p == MembershipPackage.beta,
                            onTap: () => setState(() => _selected = p),
                          ),
                      ];
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            cards[i],
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: palette.primary,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _selected.ctaTR,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.changing
                        ? 'Pro aboneliği Play Billing ile yakında açılacak.'
                        : 'Seçiminizi daha sonra Profil → Planım’dan '
                            'değiştirebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });

  final MembershipPackage package;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final borderColor =
        selected ? palette.primary : palette.border;

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: selected ? 2.2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      package.titleTR,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (recommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Önerilen',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, color: palette.primary, size: 22),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    package.priceTR,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: palette.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (package.priceSuffixTR.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        package.priceSuffixTR,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: palette.inkMuted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              for (final f in package.featuresTR)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 18, color: palette.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
