import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LiquidBackground extends StatefulWidget {
  final Widget? child;
  const LiquidBackground({super.key, this.child});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _time = elapsed.inMicroseconds / 16000000.0);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WavePainter(_time),
        child: widget.child,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double time;

  _WavePainter(this.time);

  final _path = Path();
  final _paints = List.generate(5, (_) => Paint()..style = PaintingStyle.fill);

  void _drawWave(
    Canvas canvas,
    Size size,
    int index,
    Color color,
    double baseY,
    double amplitude,
    double frequency,
    double speed,
    bool reversed,
  ) {
    final w = size.width;
    final h = size.height;
    _path.reset();
    _path.moveTo(0, h);

    final phaseOffset = time * speed * 2 * math.pi;

    for (var i = 0; i <= 70; i++) {
      final x = w * i / 70;
      final t = reversed ? (w - x) / w : x / w;
      final phase = 2 * math.pi * frequency * t + phaseOffset;

      var y = baseY + amplitude * math.sin(phase);
      y += amplitude * 0.35 * math.sin(phase * 2.3 + 1.5);
      y += amplitude * 0.15 * math.sin(phase * 3.7 + 0.8);

      _path.lineTo(x, y);
    }

    _path.lineTo(w, h);
    _path.close();

    _paints[index].color = color;
    canvas.drawPath(_path, _paints[index]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height * 0.45;

    _drawWave(canvas, size, 0, const Color(0x154F46E5), bottom,      50, 1.6, 0.7, false);
    _drawWave(canvas, size, 1, const Color(0x1E7C3AED), bottom + 25, 60, 2.1, 1.1, false);
    _drawWave(canvas, size, 2, const Color(0x246366F1), bottom + 55, 70, 1.3, 1.4, false);
    _drawWave(canvas, size, 3, const Color(0x18818CF8), bottom + 85, 40, 2.8, 1.9, false);
    _drawWave(canvas, size, 4, const Color(0x0A6366F1), size.height * 0.12, 35, 0.9, 0.4, true);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.time != time;
}
