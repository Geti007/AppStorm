import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Simple illustrations drawn in code with the brand colours.
enum ArtKind { suitcase, receipt, crew, coins, settled, chart }

class Art extends StatelessWidget {
  const Art(this.kind, {super.key, this.size = 140});

  final ArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ArtPainter(
          kind,
          primary: s.primary,
          accent: s.secondary,
          soft: s.primary.withValues(alpha: 0.12),
          paper: s.surface,
          ink: s.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(
    this.kind, {
    required this.primary,
    required this.accent,
    required this.soft,
    required this.paper,
    required this.ink,
  });

  final ArtKind kind;
  final Color primary;
  final Color accent;
  final Color soft;
  final Color paper;
  final Color ink;

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 140, size.height / 140);
    canvas.drawCircle(const Offset(70, 70), 64, _fill(soft));
    switch (kind) {
      case ArtKind.suitcase:
        _suitcase(canvas);
      case ArtKind.receipt:
        _receipt(canvas, const Offset(46, 30));
      case ArtKind.crew:
        _receipt(canvas, const Offset(58, 40), scale: 0.8);
        for (final (i, c) in [primary, accent, ink].indexed) {
          final o = Offset(38.0 + i * 20, 100);
          canvas.drawCircle(o, 16, _fill(paper));
          canvas.drawCircle(o, 13, _fill(c));
        }
      case ArtKind.coins:
        _coin(canvas, const Offset(52, 78), primary, '€');
        _coin(canvas, const Offset(90, 58), accent, '¥');
        final arc = Path()
          ..moveTo(40, 44)
          ..quadraticBezierTo(60, 20, 84, 30);
        canvas.drawPath(arc, _stroke(ink, 3));
        canvas.drawPath(
          Path()
            ..moveTo(76, 24)
            ..lineTo(85, 30)
            ..lineTo(76, 37),
          _stroke(ink, 3),
        );
      case ArtKind.settled:
        canvas.drawCircle(const Offset(70, 70), 36, _fill(primary));
        canvas.drawPath(
          Path()
            ..moveTo(54, 71)
            ..lineTo(66, 83)
            ..lineTo(88, 59),
          _stroke(paper, 7),
        );
        final rnd = math.Random(4);
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          final r = 48.0 + rnd.nextInt(10);
          canvas.drawCircle(
            Offset(70 + r * math.cos(a), 70 + r * math.sin(a)),
            3,
            _fill(i.isEven ? accent : primary),
          );
        }
      case ArtKind.chart:
        final bars = [30.0, 52.0, 40.0, 66.0];
        for (final (i, h) in bars.indexed) {
          final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(34.0 + i * 20, 100 - h, 14, h),
            const Radius.circular(4),
          );
          canvas.drawRRect(r, _fill(i == 3 ? accent : primary));
        }
        canvas.drawLine(
          const Offset(28, 102),
          const Offset(112, 102),
          _stroke(ink, 3),
        );
    }
  }

  void _suitcase(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 52, 80, 58),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(54, 38, 32, 20),
        const Radius.circular(8),
      ),
      _stroke(primary, 6),
    );
    canvas.drawRRect(body, _fill(primary));
    canvas.drawLine(
      const Offset(52, 56),
      const Offset(52, 106),
      _stroke(paper, 4),
    );
    canvas.drawLine(
      const Offset(88, 56),
      const Offset(88, 106),
      _stroke(paper, 4),
    );
    // Map pin.
    final pin = Path()
      ..moveTo(104, 64)
      ..cubicTo(90, 50, 90, 26, 104, 26)
      ..cubicTo(118, 26, 118, 50, 104, 64)
      ..close();
    canvas.drawPath(pin, _fill(accent));
    canvas.drawCircle(const Offset(104, 38), 5, _fill(paper));
  }

  void _receipt(Canvas canvas, Offset o, {double scale = 1}) {
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.scale(scale);
    final p = Path()..moveTo(0, 0);
    p.lineTo(48, 0);
    p.lineTo(48, 72);
    for (var i = 0; i < 4; i++) {
      p.lineTo(42 - i * 12.0, 66);
      p.lineTo(36 - i * 12.0, 72);
    }
    p.close();
    canvas.drawPath(p, _fill(paper));
    canvas.drawPath(p, _stroke(primary, 3));
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(10, 16.0 + i * 14),
        Offset(i == 2 ? 26 : 38, 16.0 + i * 14),
        _stroke(i == 2 ? accent : ink, 4),
      );
    }
    canvas.restore();
  }

  void _coin(Canvas canvas, Offset c, Color color, String symbol) {
    canvas.drawCircle(c, 24, _fill(color));
    canvas.drawCircle(c, 18, _stroke(paper, 2));
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: paper,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.kind != kind || old.primary != primary || old.accent != accent;
}
