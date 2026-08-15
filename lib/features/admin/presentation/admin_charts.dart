import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Yönetici paneli grafik bileşenleri.
///
/// ## Neden paket yok
///
/// `fl_chart` gibi bir bağımlılık paket boyutu, R8 keep kuralı ve sürüm
/// bakımı getirir. İhtiyaç duyulan iki grafik türü (zaman serisi + karşılaştırma)
/// `CustomPaint` ile birkaç yüz satırda çizilir ve tam denetim bizde kalır.
///
/// Erişilebilirlik: her grafik `Semantics` ile özetlenir — grafik göremeyen
/// kullanıcı da toplamı ve eğilimi duyar.

/// Zaman serisi çizgi grafiği (günlük sayaçlar).
///
/// Değerler eski → yeni sıradadır. Nokta sayısı gün sayısıdır; etiketler
/// kalabalık olmasın diye yalnız ilk/orta/son gün yazılır.
class AdminLineChart extends StatelessWidget {
  const AdminLineChart({
    super.key,
    required this.values,
    required this.days,
    required this.color,
    this.height = 160,
    this.semanticLabel,
  });

  final List<int> values;
  final List<String> days;
  final Color color;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Veri yok',
            style: TextStyle(color: palette.inkFaint, fontSize: 12),
          ),
        ),
      );
    }
    final toplam = values.fold(0, (a, b) => a + b);
    return Semantics(
      label: semanticLabel ??
          '${days.length} günlük seri, toplam $toplam',
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _LinePainter(
            values: values,
            line: color,
            grid: palette.hairline,
            fill: color.withValues(alpha: 0.14),
            dot: color,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.line,
    required this.grid,
    required this.fill,
    required this.dot,
  });

  final List<int> values;
  final Color line;
  final Color grid;
  final Color fill;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const padLeft = 4.0;
    const padRight = 4.0;
    const padTop = 8.0;
    const padBottom = 8.0;
    final w = size.width - padLeft - padRight;
    final h = size.height - padTop - padBottom;
    if (w <= 0 || h <= 0) return;

    // Üst sınır: en yüksek değer. Hepsi 0 ise 1 kabul edilir (düz taban
    // çizgisi çizilsin, sıfıra bölme olmasın).
    final maxV = values.reduce(math.max);
    final ust = maxV <= 0 ? 1 : maxV;

    // Yatay kılavuz (3 çizgi) — okuma kolaylığı, sayı yok (kalabalık yapar).
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = padTop + h * (i / 2);
      canvas.drawLine(Offset(padLeft, y), Offset(size.width - padRight, y),
          gridPaint);
    }

    // Tek nokta varsa çizgi çizilemez; ortada bir işaret yeterli.
    final n = values.length;
    double xOf(int i) => n == 1 ? padLeft + w / 2 : padLeft + w * (i / (n - 1));
    double yOf(int i) => padTop + h - (values[i] / ust) * h;

    final path = Path();
    final area = Path();
    for (var i = 0; i < n; i++) {
      final p = Offset(xOf(i), yOf(i));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        area.moveTo(p.dx, padTop + h);
        area.lineTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
        area.lineTo(p.dx, p.dy);
      }
    }
    area.lineTo(xOf(n - 1), padTop + h);
    area.close();

    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Son nokta vurgulanır: "bugün nerede?" en sık sorulan sorudur.
    canvas.drawCircle(
      Offset(xOf(n - 1), yOf(n - 1)),
      3.5,
      Paint()..color = dot,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.line != line;
}

/// İki seriyi yan yana karşılaştıran yatay çubuk (arz–talep gibi).
///
/// Aynı ölçekte çizilir; iki liste farklı toplamlara sahip olsa da çubuk
/// uzunlukları KARŞILAŞTIRILABİLİR olur — ayrı ölçek yanıltıcı olurdu.
class AdminCompareBars extends StatelessWidget {
  const AdminCompareBars({
    super.key,
    required this.rows,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftColor,
    required this.rightColor,
    this.emptyText = 'Veri yok',
  });

  /// (etiket, sol değer, sağ değer)
  final List<(String, int, int)> rows;
  final String leftLabel;
  final String rightLabel;
  final Color leftColor;
  final Color rightColor;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (rows.isEmpty) {
      return Text(
        emptyText,
        style: TextStyle(color: palette.inkFaint, fontSize: 12),
      );
    }
    var maxV = 1;
    for (final r in rows) {
      maxV = math.max(maxV, math.max(r.$2, r.$3));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Legend(color: leftColor, label: leftLabel),
            const SizedBox(width: 14),
            _Legend(color: rightColor, label: rightLabel),
          ],
        ),
        const SizedBox(height: 10),
        for (final r in rows) ...[
          Semantics(
            label: '${r.$1}: $leftLabel ${r.$2}, $rightLabel ${r.$3}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${r.$2} / ${r.$3}',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _Bar(value: r.$2, max: maxV, color: leftColor),
                const SizedBox(height: 3),
                _Bar(value: r.$3, max: maxV, color: rightColor),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, required this.color});

  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final oran = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: oran,
        minHeight: 6,
        backgroundColor: context.palette.surfaceMuted,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.palette.inkMuted),
        ),
      ],
    );
  }
}
