import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Tutarlı bildirim gösterimi için yardımcı eklenti.
///
/// SnackBar yerine ÜSTTEN süzülen kısa bir bildirim (toast) kullanır:
/// yukarıdan iner, birkaç saniye durur, dokunarak veya yukarı çekerek de
/// kapatılabilir. Alttaki yüzen gezinme çubuğunu ve giriş alanlarını örtmez.
/// Başarı/hata anları hafif titreşimle desteklenir (web'de sessizce yok sayılır).
extension SnackbarHelper on BuildContext {
  void showSuccess(String message) {
    HapticFeedback.lightImpact();
    TopToast.show(this,
        message: message,
        color: AppColors.success,
        icon: Icons.check_circle_outline);
  }

  void showError(String message) {
    HapticFeedback.mediumImpact();
    TopToast.show(this,
        message: message, color: AppColors.danger, icon: Icons.error_outline);
  }

  void showInfo(String message) => TopToast.show(this,
      message: message, color: AppColors.secondary, icon: Icons.info_outline);

  /// Geri alınabilir bir işlem sonrası bildirim: sağda "Geri Al" düğmesi.
  /// (Ör. bir kayıt çöpe atıldığında.) Aksiyon dokununca [onAction] çalışır.
  void showUndo(String message,
      {String actionLabel = 'Geri Al', required VoidCallback onAction}) {
    HapticFeedback.lightImpact();
    TopToast.show(this,
        message: message,
        icon: Icons.delete_outline,
        actionLabel: actionLabel,
        onAction: onAction);
  }
}

/// Üstten inen bildirim. Aynı anda tek bildirim görünür (yenisi eskisini alır).
///
/// İki görünüm:
///  - [color] verilirse renkli şerit (başarı/hata/bilgi — `showSuccess` vb.).
///  - [title] verilirse beyaz "sistem bildirimi" kartı (ön plan push'u gibi);
///    [onTap] ile dokununca ilgili ekrana gidilebilir.
class TopToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    Color? color,
    IconData icon = Icons.notifications_active_outlined,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // Root overlay: diyalog/bottom sheet açıkken de en üstte görünsün.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final old = _current;
    if (old != null && old.mounted) old.remove();
    _current = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopToastView(
        message: message,
        title: title,
        color: color,
        icon: icon,
        onTap: onTap,
        actionLabel: actionLabel,
        onAction: onAction,
        onDone: () {
          if (identical(_current, entry)) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _TopToastView extends StatefulWidget {
  const _TopToastView({
    required this.message,
    required this.onDone,
    required this.icon,
    this.title,
    this.color,
    this.onTap,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final Color? color;
  final IconData icon;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDone;

  @override
  State<_TopToastView> createState() => _TopToastViewState();
}

class _TopToastViewState extends State<_TopToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // Uzun metne biraz daha okuma süresi tanı; aksiyon (Geri Al) varsa
    // dokunmaya fırsat kalsın diye daha uzun tut.
    final base = widget.actionLabel != null ? 4200 : 2200;
    final holdMs = base + (widget.message.length * 12).clamp(0, 1800);
    _timer = Timer(Duration(milliseconds: holdMs), _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onDone();
  }

  void _tapped() {
    widget.onTap?.call();
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final colored = widget.color != null;
    final palette = context.palette;
    final fg = colored ? Colors.white : palette.ink;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: SlideTransition(
          position: _slide,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GestureDetector(
                onTap: _tapped,
                // Yukarı kaydırınca kapanır (bildirim alışkanlığı).
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < 0) _dismiss();
                },
                child: Material(
                  color: colored ? widget.color : palette.card,
                  elevation: 6,
                  shadowColor: Colors.black38,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: colored
                        ? null
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.border),
                            boxShadow: AppTheme.softShadow,
                          ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (colored)
                          Icon(widget.icon, color: fg, size: 22)
                        else
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: palette.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(widget.icon,
                                color: palette.onPrimaryContainer,
                                size: 18),
                          ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.title != null)
                                Text(
                                  widget.title!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: fg,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              if (widget.message.isNotEmpty)
                                Text(
                                  widget.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.title == null
                                        ? fg
                                        : (colored
                                            ? Colors.white
                                            : palette.inkMuted),
                                    fontWeight: widget.title == null
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontSize: 13.5,
                                    height: 1.3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.actionLabel != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              widget.onAction?.call();
                              _dismiss();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  colored ? Colors.white : palette.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            child: Text(widget.actionLabel!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
