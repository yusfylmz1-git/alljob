import 'package:flutter/widgets.dart';

/// Dokununca hafifçe içeri yaylanan sarmalayıcı (mikro-etkileşim).
///
/// [Listener] kullanır: dokunuşu TÜKETMEZ, alttaki butonun kendi
/// onPressed/InkWell davranışına karışmaz — yalnızca görsel tepki ekler.
/// Uygulama genelinde "canlı" his için birincil CTA'lara sarılır (AppButton).
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.965,
  });

  final Widget child;

  /// false iken (ör. buton devre dışı/yükleniyor) yaylanma kapalıdır.
  final bool enabled;

  /// Basılıyken hedef ölçek.
  final double scale;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: widget.enabled && _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
