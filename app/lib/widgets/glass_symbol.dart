import 'package:flutter/material.dart';

/// The Glassful glass, drawn in code (same shape as the app icon).
class GlassSymbol extends StatelessWidget {
  const GlassSymbol({super.key, this.size = 96, this.color, this.water});

  final double size;
  final Color? color;
  final Color? water;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _GlassPainter(
          color ?? scheme.primary,
          water ?? scheme.secondary,
        ),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter(this.glass, this.water);

  final Color glass;
  final Color water;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.scale(s);
    final body = Path()
      ..moveTo(300, 230)
      ..lineTo(724, 230)
      ..lineTo(668, 800)
      ..quadraticBezierTo(664, 832, 632, 832)
      ..lineTo(392, 832)
      ..quadraticBezierTo(360, 832, 356, 800)
      ..close();
    canvas.drawPath(body, Paint()..color = glass);
    final inner = Path()
      ..moveTo(340, 270)
      ..lineTo(684, 270)
      ..lineTo(632, 776)
      ..quadraticBezierTo(628, 794, 610, 794)
      ..lineTo(414, 794)
      ..quadraticBezierTo(396, 794, 392, 776)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.white);
    final wave = Path()
      ..moveTo(352, 470)
      ..quadraticBezierTo(432, 430, 512, 470)
      ..quadraticBezierTo(592, 510, 672, 470)
      ..lineTo(626, 776)
      ..quadraticBezierTo(622, 794, 604, 794)
      ..lineTo(420, 794)
      ..quadraticBezierTo(402, 794, 398, 776)
      ..close();
    canvas.drawPath(wave, Paint()..color = water);
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.glass != glass || old.water != water;
}
