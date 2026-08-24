import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../data/local/mock_database.dart' show kProfessionNames;
import '../../../data/models/app_user.dart';
import '../../../data/models/artisan_profile.dart';
import '../data/admin_providers.dart';
import 'admin_certificate_sheet.dart';
import 'admin_moderation_glossary.dart';
import 'admin_premium_sheet.dart';
import 'admin_user_overview.dart';

/// Tek kişi hub'ı — operatörün asıl çalışma yüzeyi.
///
/// Eski panelde "Ustalar" meslek kodu listesiydi, "Kullanıcılar" ince askı
/// sheet'iydi, araçlar dağınık menülerdeydi. Burada:
/// • kimlik (ad / e-posta / durum)
/// • aktivite sayaçları + dahili notlar
/// • usta ise vitrin araçları (onay, öne çıkar, gizle, premium, belge)
/// • hesap askısı
/// hep aynı kaydırılabilir panelde.
///
/// Rol atama YOK — o yalnız Kadro sekmesinde.
/// Panel şu an açılıyor mu? (2026-08-23 yönetici bulgusu)
///
/// Kullanıcı verisi ağdan geliyor; yavaş bağlantıda `findByUid` beklerken
/// yönetici "açılmadı" sanıp ikinci kez basıyordu ve **iki panel üst üste**
/// açılıyordu. Birini kapatmak diğerini bırakıyor, hangi kullanıcıya
/// baktığı belirsizleşiyordu.
///
/// Kilit MODÜL seviyesinde: fonksiyon beş ayrı ekrandan çağrılıyor ve her
/// birine ayrı koruma yazmak kaçınılmaz olarak birinde unutulurdu.
bool _acilisSuruyor = false;

Future<void> showAdminUserActions(
  BuildContext context,
  WidgetRef ref,
  String uid, {
  VoidCallback? onChanged,
  String? contextHint,
}) async {
  // Yükleme sürerken gelen ikinci dokunuş SESSİZCE yutulur: hata göstermek
  // yöneticiyi yanlış yönlendirir, zaten istediği şey birazdan açılacak.
  if (_acilisSuruyor) return;
  _acilisSuruyor = true;

  AppUser? user;
  try {
    user = await ref.read(adminUserRepositoryProvider).findByUid(uid);
  } catch (_) {
    _acilisSuruyor = false;
    if (context.mounted) context.showError('Kullanıcı yüklenemedi.');
    return;
  }
  // Kilit BURADA açılır, panel kapanınca değil: panel açıkken zaten
  // ekranın üstünü kapatıyor, ikinci dokunuş fiziksel olarak imkânsız.
  // Kapanışa kadar tutmak, panel içindeki bir eylemin yeni panel açmasını
  // engellerdi.
  _acilisSuruyor = false;

  if (!context.mounted) return;
  if (user == null) {
    context.showError('Kullanıcı bulunamadı.');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      return SizedBox(
        height: h * 0.92,
        child: AdminPersonHub(
          user: user!,
          onChanged: onChanged,
          contextHint: contextHint,
        ),
      );
    },
  );
}

/// Kişi kartı detayı — full-height sheet içeriği.
class AdminPersonHub extends ConsumerStatefulWidget {
  const AdminPersonHub({
    super.key,
    required this.user,
    this.onChanged,
    this.contextHint,
  });

  final AppUser user;
  final VoidCallback? onChanged;
  final String? contextHint;

  @override
  ConsumerState<AdminPersonHub> createState() => _AdminPersonHubState();
}

class _AdminPersonHubState extends ConsumerState<AdminPersonHub> {
  final _reason = TextEditingController();
  bool _busy = false;
  bool _loadingArtisan = true;
  ArtisanProfile? _artisan;

  @override
  void initState() {
    super.initState();
    _loadArtisan();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadArtisan() async {
    if (!widget.user.hasArtisanProfile) {
      setState(() => _loadingArtisan = false);
      return;
    }
    try {
      final p = await ref
          .read(adminArtisanRepositoryProvider)
          .fetchByUid(widget.user.uid);
      if (!mounted) return;
      setState(() {
        _artisan = p;
        _loadingArtisan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingArtisan = false);
    }
  }

  Future<void> _applySuspend(bool suspend) async {
    setState(() => _busy = true);
    try {
      await ref.read(adminUserRepositoryProvider).setSuspended(
            widget.user.uid,
            suspended: suspend,
            reason: _reason.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged?.call();
      context.showSuccess(
        suspend
            ? 'Kullanıcı askıya alındı.'
            : 'Kullanıcının askısı kaldırıldı.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showError('İşlem başarısız oldu. Tekrar deneyin.');
    }
  }

  Future<void> _setFlag({
    bool? adminVerified,
    bool? featured,
    bool? moderationHidden,
  }) async {
    final uid = widget.user.uid;
    try {
      await ref.read(adminArtisanRepositoryProvider).setFlags(
            uid,
            adminVerified: adminVerified,
            featured: featured,
            moderationHidden: moderationHidden,
          );
      await _loadArtisan();
      widget.onChanged?.call();
      if (mounted) context.showSuccess('Vitrin güncellendi.');
    } catch (_) {
      if (mounted) context.showError('Güncellenemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final u = widget.user;
    final name = u.displayName.trim().isEmpty ? 'İsimsiz' : u.displayName.trim();
    final canFinance =
        ref.watch(adminCapabilitiesProvider).allows('finance.manage');
    final hint = widget.contextHint;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          if (hint != null && hint.isNotEmpty) ...[
            _HintBanner(text: hint),
            const SizedBox(height: 12),
          ],

          // ── Kimlik ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PersonAvatar(name: name, photoUrl: u.profilePhotoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      u.email.isEmpty ? 'E-posta yok' : u.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.inkMuted,
                      ),
                    ),
                    if (u.phoneNumber != null &&
                        u.phoneNumber!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        u.phoneNumber!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Pill(
                label: u.suspended ? 'Askıda' : 'Aktif',
                bg: u.suspended ? palette.dangerSurface : palette.successSurface,
                fg: u.suspended ? palette.danger : palette.success,
              ),
              if (u.hasArtisanProfile)
                _Pill(
                  label: 'Usta',
                  bg: palette.infoSurface,
                  fg: palette.info,
                )
              else
                _Pill(
                  label: 'Müşteri',
                  bg: palette.surfaceMuted,
                  fg: palette.inkMuted,
                ),
              if (u.phoneVerified)
                _Pill(
                  label: 'Tel. doğrulanmış',
                  bg: palette.surfaceMuted,
                  fg: palette.inkMuted,
                ),
              if (u.emailVerified)
                _Pill(
                  label: 'E-posta doğrulanmış',
                  bg: palette.surfaceMuted,
                  fg: palette.inkMuted,
                ),
            ],
          ),
          const SizedBox(height: 10),
          _UidRow(uid: u.uid),
          const SizedBox(height: 6),
          Text(
            'Kayıt: ${_fmtDate(u.createdAt)}'
            '${u.completedJobsAsCustomer > 0 ? ' · Müşteri olarak ${u.completedJobsAsCustomer} iş' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.inkFaint,
            ),
          ),

          // ── Aktivite + notlar (mevcut 360°) ─────────────────────
          AdminUserOverview(uid: u.uid),

          // ── Usta vitrin araçları ────────────────────────────────
          if (u.hasArtisanProfile) ...[
            const SizedBox(height: 20),
            Divider(color: palette.hairline, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.handyman_outlined, size: 16, color: palette.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Usta vitrini',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => AdminModerationGlossary.show(
                    context,
                    highlightTitle: 'Platform onayı',
                  ),
                  child: const Text('Ne demek?'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Platform onayı = güven rozeti · Gizle = Keşfet’ten düşür · '
              'Askı (aşağıda) = hesabı dondur. Bunlar birbirinin yerine geçmez.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.inkFaint,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            if (_loadingArtisan)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_artisan == null)
              Text(
                'Usta profili okunamadı.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.danger,
                ),
              )
            else
              _ArtisanToolsPanel(
                profile: _artisan!,
                canFinance: canFinance,
                onFlag: _setFlag,
                onPremium: () async {
                  await showPremiumOverrideSheet(
                    context,
                    ref,
                    profile: _artisan!,
                  );
                  await _loadArtisan();
                  widget.onChanged?.call();
                },
                onCerts: () async {
                  await showCertificateReviewSheet(
                    context,
                    ref,
                    profile: _artisan!,
                  );
                  await _loadArtisan();
                  widget.onChanged?.call();
                },
              ),
          ],

          // ── Hesap moderasyonu ───────────────────────────────────
          const SizedBox(height: 20),
          Divider(color: palette.hairline, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.gpp_bad_outlined, size: 16, color: palette.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hesap moderasyonu',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => AdminModerationGlossary.show(
                  context,
                  highlightTitle: 'Hesap askıda',
                ),
                child: const Text('Askı nedir?'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Askı hesabın içerik üretmesini engeller (vitrin gizlemeden daha '
            'sert). Yönetici rolü vermek için Kadro sekmesini kullanın.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (u.suspended) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.dangerSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Bu hesap şu an askıda. Geri açılınca yeniden içerik '
                'oluşturabilir.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!_busy)
              FilledButton.icon(
                onPressed: () => _applySuspend(false),
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Askıyı kaldır'),
              ),
          ] else ...[
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 3,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Askı nedeni (isteğe bağlı)',
                hintText: 'Örn. spam, taciz, dolandırıcılık…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (!_busy)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.danger,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => _applySuspend(true),
                icon: const Icon(Icons.gpp_bad_outlined, size: 18),
                label: const Text('Hesabı askıya al'),
              ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year}';
  }
}

// ── Usta araç paneli ────────────────────────────────────────────────────────

class _ArtisanToolsPanel extends StatelessWidget {
  const _ArtisanToolsPanel({
    required this.profile,
    required this.canFinance,
    required this.onFlag,
    required this.onPremium,
    required this.onCerts,
  });

  final ArtisanProfile profile;
  final bool canFinance;
  final Future<void> Function({
    bool? adminVerified,
    bool? featured,
    bool? moderationHidden,
  }) onFlag;
  final VoidCallback onPremium;
  final VoidCallback onCerts;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final p = profile;
    final professions = p.professionLabelsTR(kProfessionNames);
    final premiumActive = _premiumActive(p);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.moderationHidden ? palette.danger : palette.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            professions.isEmpty ? 'Meslek seçilmemiş' : professions,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (p.aboutText.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.aboutText.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniChip(
                '★ ${p.averageRating.toStringAsFixed(1)} · ${p.totalReviews}',
              ),
              _MiniChip('${p.completedJobs} tamamlanan'),
              if (p.adminVerified)
                _MiniChip('Platform onaylı', color: palette.success),
              if (p.featured) _MiniChip('Öne çıkan', color: palette.warning),
              if (p.moderationHidden)
                _MiniChip('Vitrin gizli', color: palette.danger),
              _MiniChip(
                premiumActive
                    ? 'Premium · ${_fmt(p.premiumExpiresAt!)}'
                    : (p.premiumExpiresAt != null
                        ? 'Premium bitti'
                        : 'Premium yok'),
                color: premiumActive ? palette.success : null,
              ),
              if (p.certificatesPending)
                _MiniChip('Belge bekliyor', color: palette.warning),
              if (p.hasApprovedCertificates)
                _MiniChip('Belgeli usta', color: palette.info),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onFlag(adminVerified: !p.adminVerified),
                child: Text(
                  p.adminVerified ? 'Onayı kaldır' : 'Platform onayla',
                ),
              ),
              OutlinedButton(
                onPressed: () => onFlag(featured: !p.featured),
                child: Text(p.featured ? 'Öne çıkarmayı kaldır' : 'Öne çıkar'),
              ),
              OutlinedButton(
                onPressed: () => onFlag(moderationHidden: !p.moderationHidden),
                child: Text(
                  p.moderationHidden ? 'Vitrini göster' : 'Vitrini gizle',
                ),
              ),
              if (canFinance)
                FilledButton.tonal(
                  onPressed: onPremium,
                  child: const Text('Premium'),
                ),
              if (p.certificates.isNotEmpty)
                FilledButton.tonal(
                  onPressed: onCerts,
                  child: Text(
                    p.certificatesPending ? 'Belgeleri incele' : 'Belgeler',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _premiumActive(ArtisanProfile p) {
    final until = p.premiumExpiresAt;
    return p.isPremium && until != null && until.isAfter(DateTime.now());
  }

  static String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day}.${l.month}.${l.year}';
  }
}

// ── Küçük UI parçaları ──────────────────────────────────────────────────────

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final letter = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final url = photoUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 64,
        height: 64,
        child: url != null && url.startsWith('http')
            ? AppImage(handle: url, width: 64, height: 64, fit: BoxFit.cover)
            : ColoredBox(
                color: palette.primaryContainer,
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      color: palette.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, {this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = color ?? palette.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _UidRow extends StatelessWidget {
  const _UidRow({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            'UID: $uid',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.inkFaint,
              fontFamily: 'monospace',
            ),
          ),
        ),
        IconButton(
          tooltip: 'UID kopyala',
          icon: Icon(Icons.copy_rounded, size: 16, color: palette.inkFaint),
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: uid));
            if (context.mounted) context.showSuccess('UID kopyalandı.');
          },
        ),
      ],
    );
  }
}

class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.warningSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: palette.warning,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
