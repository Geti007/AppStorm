import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A short confetti burst (800 ms) that plays once when shown. Skipped when
/// the system asks for reduced motion.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _ConfettiPainter(_c.value, [s.primary, s.secondary]),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.colors);

  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final rnd = math.Random(7);
    final center = Offset(size.width / 2, size.height * 0.35);
    for (var i = 0; i < 28; i++) {
      final angle = rnd.nextDouble() * math.pi * 2;
      final speed = 60 + rnd.nextDouble() * 120;
      final d = speed * t;
      final p =
          center +
          Offset(math.cos(angle) * d, math.sin(angle) * d + 80 * t * t);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 1 - t);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + t * 6);
      canvas.drawRect(const Rect.fromLTWH(-3, -5, 6, 10), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
