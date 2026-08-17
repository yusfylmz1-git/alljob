import 'package:flutter/material.dart';

/// WhatsApp'ın **gerçek** logosu (telefon ankesörü + konuşma balonu).
///
/// Neden özel çizim: Material'da WhatsApp ikonu YOK. Önceden `Icons.chat`
/// kullanılıyordu — o düz bir konuşma balonu; kullanıcı "bu WhatsApp değil"
/// diyor ve haklı. Marka tanınırlığı ikonun kendisinden geliyor.
///
/// Neden paket değil: tek bir ikon için `font_awesome_flutter` gibi bir
/// bağımlılık (~1 MB font) eklemek APK'yı gereksiz şişirirdi. Yol verisi
/// WhatsApp'ın resmî marka SVG'sinden alınmıştır.
///
/// [color] verilmezse WhatsApp marka yeşili (#25D366) kullanılır.
class WhatsappIcon extends StatelessWidget {
  const WhatsappIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  /// WhatsApp marka yeşili — logonun resmî rengi.
  static const brandGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsappPainter(color ?? brandGreen),
      ),
    );
  }
}

class _WhatsappPainter extends CustomPainter {
  _WhatsappPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Yol 24×24 kutusuna göre tanımlı; istenen boyuta ölçeklenir.
    final path = _buildPath();
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// WhatsApp logosu: dış balon (kuyruklu) + içteki telefon ahizesi.
  Path _buildPath() {
    final p = Path();

    // Konuşma balonu — sol alt köşede kuyruk.
    p.moveTo(12.04, 2.0);
    p.cubicTo(6.58, 2.0, 2.13, 6.45, 2.13, 11.91);
    p.cubicTo(2.13, 13.66, 2.59, 15.36, 3.45, 16.86);
    p.lineTo(2.05, 22.0);
    p.lineTo(7.3, 20.62);
    p.cubicTo(8.75, 21.41, 10.38, 21.83, 12.04, 21.83);
    p.lineTo(12.05, 21.83);
    p.cubicTo(17.5, 21.83, 21.95, 17.38, 21.95, 11.92);
    p.cubicTo(21.95, 9.27, 20.92, 6.78, 19.05, 4.91);
    p.cubicTo(17.18, 3.03, 14.69, 2.0, 12.04, 2.0);
    p.close();

    // Balonun içini oy (even-odd ile "delik" etkisi) — telefon ahizesi
    // beyaz kalsın diye ters yönde çizilir.
    p.moveTo(12.05, 20.15);
    p.cubicTo(10.56, 20.15, 9.11, 19.75, 7.85, 19.0);
    p.lineTo(7.55, 18.82);
    p.lineTo(4.43, 19.64);
    p.lineTo(5.26, 16.6);
    p.lineTo(5.07, 16.29);
    p.cubicTo(4.24, 14.98, 3.81, 13.46, 3.81, 11.91);
    p.cubicTo(3.81, 7.38, 7.51, 3.68, 12.05, 3.68);
    p.cubicTo(14.24, 3.68, 16.3, 4.54, 17.85, 6.09);
    p.cubicTo(19.4, 7.65, 20.26, 9.71, 20.26, 11.92);
    p.cubicTo(20.26, 16.45, 16.56, 20.15, 12.05, 20.15);
    p.close();

    // Telefon ahizesi (balonun ortasındaki kulaklık şekli).
    p.moveTo(16.56, 14.0);
    p.cubicTo(16.31, 13.88, 15.1, 13.28, 14.88, 13.2);
    p.cubicTo(14.65, 13.12, 14.49, 13.08, 14.33, 13.33);
    p.cubicTo(14.17, 13.58, 13.69, 14.13, 13.55, 14.3);
    p.cubicTo(13.4, 14.46, 13.26, 14.48, 13.01, 14.36);
    p.cubicTo(12.76, 14.23, 11.97, 13.97, 11.03, 13.14);
    p.cubicTo(10.3, 12.49, 9.81, 11.69, 9.66, 11.44);
    p.cubicTo(9.52, 11.19, 9.65, 11.06, 9.77, 10.93);
    p.cubicTo(9.89, 10.82, 10.02, 10.64, 10.14, 10.5);
    p.cubicTo(10.27, 10.35, 10.31, 10.25, 10.39, 10.09);
    p.cubicTo(10.47, 9.92, 10.43, 9.78, 10.37, 9.66);
    p.cubicTo(10.31, 9.53, 9.82, 8.32, 9.61, 7.83);
    p.cubicTo(9.41, 7.35, 9.21, 7.41, 9.06, 7.41);
    p.cubicTo(8.91, 7.4, 8.75, 7.4, 8.59, 7.4);
    p.cubicTo(8.43, 7.4, 8.18, 7.46, 7.96, 7.71);
    p.cubicTo(7.74, 7.96, 7.12, 8.55, 7.12, 9.76);
    p.cubicTo(7.12, 10.97, 8.0, 12.14, 8.12, 12.3);
    p.cubicTo(8.25, 12.47, 9.81, 14.88, 12.21, 15.91);
    p.cubicTo(12.78, 16.16, 13.23, 16.3, 13.58, 16.41);
    p.cubicTo(14.15, 16.59, 14.67, 16.57, 15.08, 16.51);
    p.cubicTo(15.53, 16.44, 16.52, 15.91, 16.72, 15.34);
    p.cubicTo(16.93, 14.76, 16.93, 14.27, 16.87, 14.17);
    p.cubicTo(16.81, 14.06, 16.65, 14.0, 16.4, 13.88);
    p.close();

    p.fillType = PathFillType.evenOdd;
    return p;
  }

  @override
  bool shouldRepaint(_WhatsappPainter oldDelegate) =>
      oldDelegate.color != color;
}
