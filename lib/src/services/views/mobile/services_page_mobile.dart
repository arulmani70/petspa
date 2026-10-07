import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours — Project Theme (Black & Neutral White/Grey)
// ─────────────────────────────────────────────────────────────────────────────
const _kBlack     = Color(0xFF111827);
const _kSubText   = Color(0xFF6B7280);
const _kBorder    = Color(0xFFE5E7EB);
const _kPageBg    = Color(0xFFFAFAFA);
const _kCardBg    = Color(0xFFFFFFFF);
const _kLightGrey = Color(0xFFF3F4F6);
const _kBaseUrl   = 'https://shear-heaven-api.genzcodershub.com';

// ─────────────────────────────────────────────────────────────────────────────
class ServicesPageMobile extends StatelessWidget {
  const ServicesPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ServiceBloc(repository: ServicesLocator.serviceRepository)
        ..add(const InitializeServices()),
      child: const _ServicesView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ServicesView extends StatelessWidget {
  const _ServicesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => context.canPop() ? context.pop() : context.goNamed(RouteNames.home),
        ),
        title: Text(
          'All Services',
          style: AppFonts.parkinsans(
            size: 20,
            weight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: BlocBuilder<ServiceBloc, ServiceState>(
        builder: (context, state) {
          if (state.status == ServiceStatus.loading ||
              state.status == ServiceStatus.initial) {
            // ── Skeleton loading ─────────────────────────────────────────
            return ListView(
              padding: const EdgeInsets.fromLTRB(17, 22, 17, 130),
              children: const [
                ListCardSkeleton(), SizedBox(height: 14),
                ListCardSkeleton(), SizedBox(height: 14),
                ListCardSkeleton(), SizedBox(height: 14),
                ListCardSkeleton(), SizedBox(height: 14),
                ListCardSkeleton(),
              ],
            );
          }

          if (state.status == ServiceStatus.failure) {
            return _ErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<ServiceBloc>().add(const InitializeServices()),
            );
          }

          final bs = state.bookingServices;
          if (bs == null || bs.isEmpty) {
            return _EmptyView(
              onRetry: () =>
                  context.read<ServiceBloc>().add(const InitializeServices()),
            );
          }

          return RefreshIndicator(
            color: _kBlack,
            onRefresh: () async =>
                context.read<ServiceBloc>().add(const RefreshServices()),
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Walk-In Services ─────────────────────────────────────
                if (bs.walkIn.isNotEmpty) ...[
                  _SectionHeader(label: 'Walk-In Services', icon: Icons.directions_walk),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(17, 8, 17, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ServiceListCard(
                            item: bs.walkIn[i],
                            onTap: () => ctx.pushNamed(
                              RouteNames.serviceDetail,
                              pathParameters: {
                                'serviceId': bs.walkIn[i].id.toString(),
                              },
                            ),
                          ),
                        ),
                        childCount: bs.walkIn.length,
                      ),
                    ),
                  ),
                ],

                // ── Add-Ons ──────────────────────────────────────────────
                if (bs.addOns.isNotEmpty) ...[
                  _SectionHeader(label: 'Add-On Services', icon: Icons.add_circle_outline),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(17, 8, 17, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ServiceListCard(
                            item: bs.addOns[i],
                            onTap: () => ctx.pushNamed(
                              RouteNames.serviceDetail,
                              pathParameters: {
                                'serviceId': bs.addOns[i].id.toString(),
                              },
                            ),
                          ),
                        ),
                        childCount: bs.addOns.length,
                      ),
                    ),
                  ),
                ],

                // ── Breed Services ───────────────────────────────────────
                if (bs.breeds.isNotEmpty) ...[
                  _SectionHeader(label: 'Breed Services', icon: Icons.pets),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(17, 8, 17, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ServiceListCard(
                            item: bs.breeds[i],
                            onTap: () => ctx.pushNamed(
                              RouteNames.serviceDetail,
                              pathParameters: {
                                'serviceId': bs.breeds[i].id.toString(),
                              },
                            ),
                          ),
                        ),
                        childCount: bs.breeds.length,
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 130)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sliver section header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 20, 17, 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _kBlack),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.parkinsans(
                size: 16,
                weight: FontWeight.w700,
                color: _kBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service list card (horizontal: image left, content right)
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceListCard extends StatelessWidget {
  final ServiceItem item;
  final VoidCallback onTap;
  const _ServiceListCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: SizedBox(
                width: 90,
                height: 90,
                child: _ApiOrLocalImage(item: item),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppFonts.poppins(
                        size: 14,
                        weight: FontWeight.w600,
                        color: _kBlack,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        style: AppFonts.poppins(
                          size: 11.5,
                          weight: FontWeight.w400,
                          color: _kSubText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.priceDisplay.isNotEmpty)
                          _Chip(
                            icon: Icons.attach_money,
                            label: item.priceDisplay,
                            color: _kBlack,
                            bg: _kLightGrey,
                          ),
                        if (item.durationMinutes > 0)
                          _Chip(
                            icon: Icons.schedule_outlined,
                            label: _fmtDur(item.durationMinutes),
                            color: _kSubText,
                            bg: _kLightGrey,
                          ),
                        if (item.isAddOn)
                          _Chip(
                            icon: Icons.add,
                            label: 'Add-On',
                            color: _kBlack,
                            bg: _kLightGrey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 12),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _kSubText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDur(int m) {
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// API image with local-asset + icon fallback
// ─────────────────────────────────────────────────────────────────────────────
class _ApiOrLocalImage extends StatelessWidget {
  final ServiceItem item;
  const _ApiOrLocalImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;

    Widget fallback() {
      final localAsset = serviceAssetFor(item.name.split(' — ').last.trim()) ??
          serviceAssetFor(item.name);
      if (localAsset != null) {
        return FigmaImage(
          asset: localAsset,
          fit: BoxFit.cover,
          fallback: _icon(),
        );
      }
      return _icon();
    }

    if (url != null && url.isNotEmpty) {
      final fullUrl = url.startsWith('http') ? url : '$_kBaseUrl$url';
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => fallback(),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF3F4F6),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: _kBlack,
            ),
          );
        },
      );
    }
    return fallback();
  }

  Widget _icon() {
    IconData icon;
    if (item.isPackage) {
      icon = Icons.auto_awesome;
    } else if (item.isAddOn) {
      icon = Icons.add_circle_outline;
    } else if (item.name.toLowerCase().contains('bath')) {
      icon = Icons.shower_outlined;
    } else {
      icon = Icons.content_cut;
    }
    return Container(
      color: _kLightGrey,
      alignment: Alignment.center,
      child: Icon(icon, size: 28, color: _kSubText),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge chip
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppFonts.poppins(
              size: 11,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error / empty state
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: Color(0xFF991B1B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load services',
              style: AppFonts.parkinsans(
                size: 16,
                weight: FontWeight.w700,
                color: _kBlack,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message.contains('missing_identifiers')
                  ? 'Store information unavailable.'
                  : 'Please check your connection.',
              style: AppFonts.poppins(size: 13, color: _kSubText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlack,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: AppFonts.parkinsans(size: 14, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 52, color: _kSubText),
          const SizedBox(height: 14),
          Text(
            'No services available',
            style: AppFonts.parkinsans(
              size: 16,
              weight: FontWeight.w700,
              color: _kBlack,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: _kBlack,
              textStyle: AppFonts.parkinsans(size: 14, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
