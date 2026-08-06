import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';

/// Compact variant of the login screen's HeroCharacterGlow.
///
/// Same matte-black mascot + teal scarf + blue backlight glow, but
/// scaled to ~35% of screen height (vs ~48% on login) and with the
/// ambient glow at 15–20% opacity rather than the login's full drama.
///
/// Per spec §14: the character is "established" here — the app can
/// let it be partially obscured by surrounding cards without needing
/// to re-introduce it the way the login screen does.
///
/// Animations (same as login widget, intensity reduced):
///   • Float: ±4 px vertical sine, 2 800 ms loop.
///   • Glow pulse: outer halo 0.55 → 0.85 opacity, 3 500 ms loop.
class HeroMascotCompact extends StatelessWidget {
  const HeroMascotCompact({super.key});

  static const double _zoneHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _zoneHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // ── Deep outer dark bloom ────────────────────────────────────
          Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0B1220).withValues(alpha: 0.0),
                  const Color(0xFF0B1220).withValues(alpha: 0.40),
                  const Color(0xFF050709).withValues(alpha: 0.75),
                ],
                stops: const [0.35, 0.70, 1.0],
              ),
            ),
          ),

          // ── Wide cool-blue outer halo (pulsing, reduced intensity) ───
          Container(
            width: 220,
            height: 160,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x3A1A8FE3), // ~23% opacity — quieter than login
                  Color(0x1E0D6DCC),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .custom(
                duration: const Duration(milliseconds: 3500),
                curve: Curves.easeInOutSine,
                begin: 0.55,
                end: 0.85,
                builder: (_, value, child) =>
                    Opacity(opacity: value, child: child),
              ),

          // ── Inner bright core glow ───────────────────────────────────
          Container(
            width: 120,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x6640C4FF),
                  Color(0x301A90E0),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .custom(
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeInOutSine,
                begin: 0.70,
                end: 1.0,
                builder: (_, value, child) =>
                    Opacity(opacity: value, child: child),
              ),

          // ── Ground shadow ellipse ────────────────────────────────────
          Positioned(
            bottom: 4,
            child: Container(
              width: 130,
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Mascot image (floating) ──────────────────────────────────
          _CompactMascotImage()
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -4,
                end: 4,
                duration: const Duration(milliseconds: 2800),
                curve: Curves.easeInOutSine,
              ),

          // ── Reduced sparkle set (2 instead of 4) ────────────────────
          ..._buildSparkles(),
        ],
      ),
    );
  }

  List<Widget> _buildSparkles() {
    const specs = [
      _SparkleSpec(radius: 65, angle: 0.3, size: 2.5, duration: 4000, delay: 0),
      _SparkleSpec(radius: 55, angle: 3.1, size: 2.0, duration: 3400, delay: 900),
    ];
    return specs.map((s) => _Sparkle(spec: s)).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mascot image — same ShaderMask blend as the login variant, smaller crop
// ─────────────────────────────────────────────────────────────────────────────

class _CompactMascotImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const RadialGradient(
          center: Alignment(0, 0.05),
          radius: 0.50,
          colors: [
            Colors.white,
            Color(0xDDFFFFFF),
            Color(0x55FFFFFF),
            Colors.transparent,
          ],
          stops: [0.0, 0.42, 0.68, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Image.asset(
        'assets/images/hero_mascot.png',
        height: 175,
        width: 175,
        fit: BoxFit.contain,
        frameBuilder: (ctx, child, frame, loaded) {
          if (loaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 400),
            child: child,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sparkle spec & widget (same pattern as HeroCharacterGlow)
// ─────────────────────────────────────────────────────────────────────────────

class _SparkleSpec {
  const _SparkleSpec({
    required this.radius,
    required this.angle,
    required this.size,
    required this.duration,
    required this.delay,
  });

  final double radius;
  final double angle;
  final double size;
  final int duration;
  final int delay;
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.spec});
  final _SparkleSpec spec;

  @override
  Widget build(BuildContext context) {
    final dx = spec.radius * math.cos(spec.angle);
    final dy = spec.radius * math.sin(spec.angle) * 0.45;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: spec.size,
        height: spec.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.heroGlow,
          boxShadow: [
            BoxShadow(
              color: AppColors.heroGlow.withValues(alpha: 0.8),
              blurRadius: spec.size * 2.5,
              spreadRadius: spec.size * 0.5,
            ),
          ],
        ),
      )
          .animate(
            onPlay: (c) => c.repeat(reverse: true),
            delay: Duration(milliseconds: spec.delay),
          )
          .fadeIn(
            duration: Duration(milliseconds: spec.duration),
            curve: Curves.easeInOutSine,
          )
          .then()
          .fadeOut(
            duration: Duration(milliseconds: spec.duration),
            curve: Curves.easeInOutSine,
          ),
    );
  }
}
