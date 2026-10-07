import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pure-Flutter shimmer — no extra package required.
// Usage:
//   ShimmerBox(width: 200, height: 16)          — plain rectangle
//   ShimmerBox(width: 40, height: 40, radius: 20) — circle
//   ShimmerList(itemCount: 4, item: MySkeletonCard()) — list of clones
// ─────────────────────────────────────────────────────────────────────────────

/// Animating highlight colours
const _kBase      = Color(0xFFE8ECF0);
const _kHighlight = Color(0xFFF6F8FA);

// ─────────────────────────────────────────────────────────────────────────────
// Core animated shimmer wrapper
// ─────────────────────────────────────────────────────────────────────────────
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, child) => ShaderMask(
        blendMode  : BlendMode.srcATop,
        shaderCallback: (bounds) {
          final x = (_anim.value * 2 - 0.5).clamp(-0.5, 1.5);
          return LinearGradient(
            begin : Alignment(x - 0.6, 0),
            end   : Alignment(x + 0.6, 0),
            colors: const [_kBase, _kHighlight, _kHighlight, _kBase],
            stops : const [0.0, 0.35, 0.65, 1.0],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single shimmer rectangle / circle
// ─────────────────────────────────────────────────────────────────────────────
class ShimmerBox extends StatelessWidget {
  final double  width;
  final double  height;
  final double  radius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width : width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color       : _kBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service card skeleton  (used in home + services page)
// ─────────────────────────────────────────────────────────────────────────────
class ServiceCardSkeleton extends StatelessWidget {
  final double width;
  const ServiceCardSkeleton({super.key, this.width = 160});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width : width,
            height: width * 0.88,
            decoration: BoxDecoration(
              color       : _kBase,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 10),
          Container(
              width: width * 0.7, height: 13,
              decoration: BoxDecoration(
                  color: _kBase, borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 6),
          Container(
              width: width * 0.5, height: 11,
              decoration: BoxDecoration(
                  color: _kBase, borderRadius: BorderRadius.circular(6))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal list card skeleton (services list / booking service page)
// ─────────────────────────────────────────────────────────────────────────────
class ListCardSkeleton extends StatelessWidget {
  final double height;
  const ListCardSkeleton({super.key, this.height = 90});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height    : height,
        decoration: BoxDecoration(
          color       : _kBase,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Image placeholder
            Container(
              width : height,
              height: height,
              decoration: BoxDecoration(
                color       : _kHighlight,
                borderRadius: const BorderRadius.only(
                  topLeft   : Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Text lines
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 13, width: double.infinity,
                        decoration: BoxDecoration(
                            color: _kHighlight,
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(
                        height: 11, width: 140,
                        decoration: BoxDecoration(
                            color: _kHighlight,
                            borderRadius: BorderRadius.circular(6))),
                    const Spacer(),
                    Row(children: [
                      Container(
                          height: 22, width: 60,
                          decoration: BoxDecoration(
                              color: _kHighlight,
                              borderRadius: BorderRadius.circular(20))),
                      const SizedBox(width: 8),
                      Container(
                          height: 22, width: 54,
                          decoration: BoxDecoration(
                              color: _kHighlight,
                              borderRadius: BorderRadius.circular(20))),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking card skeleton  (my bookings)
// ─────────────────────────────────────────────────────────────────────────────
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        padding   : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color       : _kBase,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pet row
            Row(children: [
              Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                      color: _kHighlight,
                      borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 120,
                      decoration: BoxDecoration(color: _kHighlight,
                          borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 6),
                  Container(height: 11, width: 80,
                      decoration: BoxDecoration(color: _kHighlight,
                          borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(height: 22, width: 90,
                      decoration: BoxDecoration(color: _kHighlight,
                          borderRadius: BorderRadius.circular(12))),
                ],
              )),
            ]),
            const SizedBox(height: 14),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            const SizedBox(height: 14),
            // Info rows
            for (var i = 0; i < 3; i++) ...[
              Row(children: [
                Container(width: 15, height: 15,
                    decoration: BoxDecoration(color: _kHighlight,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 8),
                Container(height: 12,
                    width: 100 + i * 30.0,
                    decoration: BoxDecoration(color: _kHighlight,
                        borderRadius: BorderRadius.circular(6))),
              ]),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pet card skeleton  (my pets / pet select)
// ─────────────────────────────────────────────────────────────────────────────
class PetCardSkeleton extends StatelessWidget {
  const PetCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        padding   : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color       : _kBase,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Container(
              width: 74, height: 74,
              decoration: BoxDecoration(
                  color: _kHighlight,
                  borderRadius: BorderRadius.circular(16))),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 14, width: 110,
                  decoration: BoxDecoration(color: _kHighlight,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(height: 11, width: 80,
                  decoration: BoxDecoration(color: _kHighlight,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Row(children: [
                Container(height: 11, width: 55,
                    decoration: BoxDecoration(color: _kHighlight,
                        borderRadius: BorderRadius.circular(6))),
                const SizedBox(width: 16),
                Container(height: 11, width: 55,
                    decoration: BoxDecoration(color: _kHighlight,
                        borderRadius: BorderRadius.circular(6))),
              ]),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Package card skeleton  (packages page / home)
// ─────────────────────────────────────────────────────────────────────────────
class PackageCardSkeleton extends StatelessWidget {
  const PackageCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height    : 200,
        decoration: BoxDecoration(
          color       : _kBase,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(height: 16, width: 130,
                    decoration: BoxDecoration(color: _kHighlight,
                        borderRadius: BorderRadius.circular(6))),
                Container(height: 28, width: 60,
                    decoration: BoxDecoration(color: _kHighlight,
                        borderRadius: BorderRadius.circular(20))),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 11, width: 90,
                decoration: BoxDecoration(color: _kHighlight,
                    borderRadius: BorderRadius.circular(6))),
            const Spacer(),
            Container(
              height: 46,
              decoration: BoxDecoration(
                  color: _kHighlight,
                  borderRadius: BorderRadius.circular(30)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile skeleton
// ─────────────────────────────────────────────────────────────────────────────
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Avatar
            Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(
                  color: _kBase, shape: BoxShape.circle),
            ),
            const SizedBox(height: 28),
            // Fields
            for (var i = 0; i < 3; i++) ...[
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 12, width: 80,
                    decoration: BoxDecoration(color: _kBase,
                        borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                      color: _kBase,
                      borderRadius: BorderRadius.circular(60)),
                ),
              ]),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home page skeleton — services grid + packages
// ─────────────────────────────────────────────────────────────────────────────
class HomeServicesSkeleton extends StatelessWidget {
  const HomeServicesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Shimmer(
          child: Container(height: 18, width: 150,
              decoration: BoxDecoration(color: _kBase,
                  borderRadius: BorderRadius.circular(6))),
        ),
        const SizedBox(height: 12),
        // 2×2 grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: const [
              ServiceCardSkeleton(), SizedBox(height: 22), ServiceCardSkeleton(),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(children: const [
              ServiceCardSkeleton(), SizedBox(height: 22), ServiceCardSkeleton(),
            ])),
          ],
        ),
        const SizedBox(height: 38),
        // Packages header
        Shimmer(
          child: Container(height: 18, width: 160,
              decoration: BoxDecoration(color: _kBase,
                  borderRadius: BorderRadius.circular(6))),
        ),
        const SizedBox(height: 12),
        const PackageCardSkeleton(),
        const SizedBox(height: 10),
        const PackageCardSkeleton(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic shimmer list  (n identical skeleton items)
// ─────────────────────────────────────────────────────────────────────────────
class ShimmerList extends StatelessWidget {
  final int     itemCount;
  final Widget  item;
  final double  spacing;

  const ShimmerList({
    super.key,
    required this.itemCount,
    required this.item,
    this.spacing = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics      : const NeverScrollableScrollPhysics(),
      shrinkWrap   : true,
      itemCount    : itemCount,
      separatorBuilder: (ctx, i) => SizedBox(height: spacing),
      itemBuilder  : (ctx, i) => item,
    );
  }
}
