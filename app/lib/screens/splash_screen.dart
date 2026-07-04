import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'map_screen.dart';

/// Acilis logo animasyonu: petek kumesi sirayla belirir,
/// "urbhex" yazisi gelir, sonra haritaya gecilir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MapScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(140, 140),
                painter: _HexClusterPainter(progress: _controller.value),
              ),
              const SizedBox(height: 20),
              Opacity(
                opacity: Curves.easeIn.transform(((_controller.value - 0.7) / 0.3).clamp(0, 1)),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 40, color: Color(0xFF16302B), fontWeight: FontWeight.w300),
                    children: [
                      TextSpan(text: 'urb'),
                      TextSpan(
                        text: 'hex',
                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B5E20)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Merkez + 6 komsu altigeni sirayla (staggered) cizen painter.
class _HexClusterPainter extends CustomPainter {
  final double progress;
  _HexClusterPainter({required this.progress});

  static const _colors = [
    Color(0xFF1B5E20), // merkez
    Color(0xFF2E7D32),
    Color(0xFF43A047),
    Color(0xFFFFB300), // amber vurgu
    Color(0xFF66BB6A),
    Color(0xFF9CCC65),
    Color(0xFF00897B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const r = 22.0;
    final d = r * math.sqrt(3);

    final offsets = [
      Offset.zero,
      for (var i = 0; i < 6; i++)
        Offset(d * math.cos((90 - 60.0 * i) * math.pi / 180), -d * math.sin((90 - 60.0 * i) * math.pi / 180)),
    ];

    for (var i = 0; i < offsets.length; i++) {
      // Her hex toplam surenin bir diliminde belirir (stagger).
      final start = i * 0.10;
      final t = ((progress - start) / 0.25).clamp(0.0, 1.0);
      if (t == 0) continue;
      final eased = Curves.easeOutBack.transform(t);
      final paint = Paint()..color = _colors[i].withOpacity(0.95 * t.clamp(0, 1));
      canvas.drawPath(_hexPath(center + offsets[i], r * eased), paint);
    }
  }

  Path _hexPath(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (60.0 * i - 90) * math.pi / 180; // sivri tepe
      final p = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _HexClusterPainter old) => old.progress != progress;
}
