import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated liquid wave background with multiple overlapping sine wave layers.
class LiquidBackground extends StatefulWidget {
  final Widget? child;

  const LiquidBackground({super.key, this.child});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(_controller.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _WavePainter extends CustomPainter {
  final double time;

  _WavePainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final bottom = h * 0.72;

    // ── Layer 1: Deep indigo, slow, large amplitude ──────────
    _drawWave(
      canvas: canvas,
      size: size,
      color: const Color(0xFF4F46E5),
      opacity: 0.08,
      offsetY: bottom,
      amplitude: 35,
      frequency: 1.6,
      speed: 0.7,
    );

    // ── Layer 2: Violet, medium speed ────────────────────────
    _drawWave(
      canvas: canvas,
      size: size,
      color: const Color(0xFF7C3AED),
      opacity: 0.12,
      offsetY: bottom + 20,
      amplitude: 45,
      frequency: 2.1,
      speed: 1.1,
    );

    // ── Layer 3: Primary indigo, a bit faster ────────────────
    _drawWave(
      canvas: canvas,
      size: size,
      color: const Color(0xFF6366F1),
      opacity: 0.15,
      offsetY: bottom + 45,
      amplitude: 55,
      frequency: 1.3,
      speed: 1.4,
    );

    // ── Layer 4: Lighter violet, fast, small ─────────────────
    _drawWave(
      canvas: canvas,
      size: size,
      color: const Color(0xFF818CF8),
      opacity: 0.10,
      offsetY: bottom + 70,
      amplitude: 30,
      frequency: 2.8,
      speed: 1.9,
    );

    // ── Layer 5: Top subtle pulse ────────────────────────────
    final pulseY = h * 0.18;
    _drawWave(
      canvas: canvas,
      size: size,
      color: const Color(0xFF6366F1),
      opacity: 0.04,
      offsetY: pulseY,
      amplitude: 25,
      frequency: 0.9,
      speed: 0.4,
      reversed: true,
    );
  }

  void _drawWave({
    required Canvas canvas,
    required Size size,
    required Color color,
    required double opacity,
    required double offsetY,
    required double amplitude,
    required double frequency,
    required double speed,
    bool reversed = false,
  }) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(0, h);

    // Draw wave from right to left (or reversed)
    final steps = 120;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final t = reversed ? (w - x) / w : x / w;
      final phase = 2 * math.pi * frequency * t + time * speed * 2 * math.pi;

      var y = offsetY + amplitude * math.sin(phase);

      // Add second harmonic for more organic look
      y += amplitude * 0.35 * math.sin(phase * 2.3 + 1.5);

      // Add third harmonic
      y += amplitude * 0.15 * math.sin(phase * 3.7 + 0.8);

      path.lineTo(x, y);
    }

    // Complete the shape: go to bottom-right, then bottom-left
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Gradient fill — fade toward bottom
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: opacity),
        color.withValues(alpha: opacity * 0.4),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, offsetY - amplitude * 1.5, w, h - offsetY + amplitude * 1.5))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
