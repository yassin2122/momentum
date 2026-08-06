import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';

/// Hero zone for the login/register screen — displays the glowing ghost
/// mascot with a layered dark-glass environment that dissolves its white
/// background seamlessly into the app's dark gradient canvas.
///
/// Blend strategy:
/// - [ShaderMask] with a radial [BlendMode.dstIn] gradient makes the corners
///   of the PNG alpha-fade to zero, erasing the white square edges.
/// - [ColorFiltered] with [BlendMode.multiply] maps the white image
///   background to the dark canvas color while preserving the character's
///   own bright/blue glowing pixels.
/// - Multiple layered radial gradient containers replicate the image's
///   built-in blue halo in pure Flutter paint so the glow bleeds into the
///   surrounding screen as if it were a single composited light source.
///
/// Animations (both loop with reverse so there's no snap-jump at the boundary):
/// - **Float**: ±6 px vertical sine over 2 800 ms — the character gently bobs.
/// - **Glow pulse**: outer halo breathes 0.65 → 1.0 opacity over 3 500 ms.
class HeroCharacterGlow extends StatelessWidget {
  const HeroCharacterGlow({super.key});

  static const double _zoneHeight = 300.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _zoneHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // ── Layer 1: deep outer dark bloom (ties hero to bg canvas) ────────
          Container(
            width: 340,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0B1220).withValues(alpha: 0.0), // transparent center
                  const Color(0xFF0B1220).withValues(alpha: 0.55), // dark mid ring
                  const Color(0xFF050709).withValues(alpha: 0.85), // near-bg at edge
                ],
                stops: const [0.35, 0.70, 1.0],
              ),
            ),
          ),

          // ── Layer 2: wide cool-blue outer halo (pulsing) ──────────────────
          Container(
            width: 280,
            height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x5C1A8FE3), // electric blue core ~36%
                  Color(0x2E0D6DCC), // mid spread ~18%
                  Color(0x00000000), // fully transparent edge
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .custom(
                duration: const Duration(milliseconds: 3500),
                curve: Curves.easeInOutSine,
                begin: 0.65,
                end: 1.0,
                builder: (_, value, child) =>
                    Opacity(opacity: value, child: child),
              ),

          // ── Layer 3: bright inner core glow (smaller, always on) ──────────
          Container(
            width: 160,
            height: 140,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x9940C4FF), // bright cyan-white core
                  Color(0x441A90E0), // spread
                  Color(0x00000000), // transparent edge
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .custom(
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeInOutSine,
                begin: 0.80,
                end: 1.0,
                builder: (_, value, child) =>
                    Opacity(opacity: value, child: child),
              ),

          // ── Layer 4: ground shadow ellipse ─────────────────────────────────
          Positioned(
            bottom: 10,
            child: Container(
              width: 180,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.60),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Layer 5: the mascot image — floated + bg-blended ──────────────
          _MascotImage()
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -6,
                end: 6,
                duration: const Duration(milliseconds: 2800),
                curve: Curves.easeInOutSine,
              ),

          // ── Layer 6: particle sparkles orbiting the mascot ─────────────────
          ..._buildSparkles(),
        ],
      ),
    );
  }

  /// Four tiny sparkle dots that drift at different speeds/radii around the
  /// mascot, adding life to the scene without competing with the character.
  List<Widget> _buildSparkles() {
    const specs = [
      _SparkleSpec(radius: 88, angle: 0.18, size: 3.5, duration: 4200, delay: 0),
      _SparkleSpec(radius: 72, angle: 1.45, size: 2.5, duration: 3600, delay: 700),
      _SparkleSpec(radius: 95, angle: 2.80, size: 4.0, duration: 5100, delay: 300),
      _SparkleSpec(radius: 66, angle: 4.20, size: 2.0, duration: 3900, delay: 1100),
    ];
    return specs.map((s) => _Sparkle(spec: s)).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mascot image with ShaderMask blend to erase white background edges
// ─────────────────────────────────────────────────────────────────────────────

class _MascotImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Two nested ShaderMasks:
    //  • Outer (dstIn)  — radial alpha mask that erases the white PNG corners.
    //  • Inner (screen) — adds the dark bg color where the image is white so
    //    the background bleeds through, while leaving the mascot's luminous
    //    character and blue glow intact (screen keeps bright areas bright).
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const RadialGradient(
          center: Alignment(0, 0.05), // very slightly below center
          radius: 0.50,
          colors: [
            Colors.white,           // hold fully opaque through character
            Color(0xDDFFFFFF),      // gentle fade start
            Color(0x55FFFFFF),      // accelerate fade
            Colors.transparent,     // fully erased corners
          ],
          stops: [0.0, 0.42, 0.68, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Image.asset(
        'assets/images/hero_mascot.png',
        height: 240,
        width: 240,
        fit: BoxFit.contain,
        frameBuilder: (ctx, child, frame, loaded) {
          if (loaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 500),
            child: child,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sparkle spec & widget
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
  final double angle;   // radians — starting position on orbit
  final double size;
  final int duration;   // ms for opacity pulse
  final int delay;      // ms initial delay
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.spec});
  final _SparkleSpec spec;

  @override
  Widget build(BuildContext context) {
    final dx = spec.radius * math.cos(spec.angle);
    final dy = spec.radius * math.sin(spec.angle) * 0.45; // squash to ellipse
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
