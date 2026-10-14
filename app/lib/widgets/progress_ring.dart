import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A ring that fills toward the goal. [fraction] is capped at 1.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    required this.child,
    this.size = 200,
    this.stroke = 16,
  });

  final double fraction;
  final Widget child;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = fraction.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, inner) => CustomPaint(
          painter: _RingPainter(
            value: value,
            color: scheme.primary,
            track: scheme.primary.withValues(alpha: 0.15),
            stroke: stroke,
          ),
          child: inner,
        ),
        child: Padding(
          padding: EdgeInsets.all(stroke + 12),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
