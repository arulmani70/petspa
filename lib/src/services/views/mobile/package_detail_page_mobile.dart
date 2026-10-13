import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class PackageDetailPageMobile extends StatelessWidget {
  final String packageId;
  final Map<String, dynamic>? initialPackage;

  const PackageDetailPageMobile({
    super.key,
    required this.packageId,
    this.initialPackage,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          try {
            if (context.canPop()) {
              context.pop();
              return;
            }
          } catch (_) {}
          try {
            context.goNamed(RouteNames.packages);
          } catch (_) {}
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: BlocBuilder<ServiceBloc, ServiceState>(
            builder: (context, state) {
              final package = state.selectedPackage ?? initialPackage;
              if (package != null) {
                return _buildDetail(context, package);
              }

              if (state.detailStatus == ServiceStatus.loading ||
                  state.detailStatus == ServiceStatus.initial) {
                return _buildSkeleton(context);
              }

              if (state.detailStatus == ServiceStatus.failure) {
                return _buildErrorView(context, state.detailMessage);
              }

              return _buildSkeleton(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              const ShimmerBox(
                width: double.infinity,
                height: 286,
                radius: 0,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 90, height: 12, radius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(width: 240, height: 22, radius: 8),
                    SizedBox(height: 20),
                    ShimmerBox(width: double.infinity, height: 13, radius: 6),
                    SizedBox(height: 6),
                    ShimmerBox(width: double.infinity, height: 13, radius: 6),
                    SizedBox(height: 6),
                    ShimmerBox(width: 200, height: 13, radius: 6),
                    SizedBox(height: 28),
                    ShimmerBox(width: 140, height: 16, radius: 6),
                    SizedBox(height: 14),
                    ShimmerBox(width: double.infinity, height: 13, radius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(width: double.infinity, height: 13, radius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(width: double.infinity, height: 13, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 17,
          child: _buildBackButton(context),
        ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 12),
                Text(
                  message.isNotEmpty ? message : "Package not found",
                  textAlign: TextAlign.center,
                  style: AppFonts.poppins(
                    size: 15,
                    weight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context
                      .read<ServiceBloc>()
                      .add(GetPackageDetail(packageId)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 17,
          child: _buildBackButton(context),
        ),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          try {
            if (context.canPop()) {
              context.pop();
              return;
            }
          } catch (_) {}
          try {
            context.goNamed(RouteNames.packages);
          } catch (_) {}
        }
      },
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 22,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Map<String, dynamic> package) {
    final name = package[Constants.database.COLUMN_PACKAGE_NAME]?.toString() ??
        package['package_name']?.toString() ??
        package['service_name']?.toString() ??
        package['name']?.toString() ??
        'Package Details';
    final description =
        package[Constants.database.COLUMN_DESCRIPTION]?.toString() ??
        package['description']?.toString() ??
        '';

    final priceRaw = package[Constants.database.COLUMN_PRICE] ?? package['price'];
    final priceDisplay = package['priceDisplay']?.toString() ??
        package['price_display']?.toString() ??
        (priceRaw != null ? '\$$priceRaw' : '\$24.00');

    final duration =
        (package[Constants.database.COLUMN_DURATION_MIN] as num?)?.toInt() ??
        (package['durationMinutes'] as num?)?.toInt() ??
        60;

    final imageUrl = package['imageUrl']?.toString() ?? package['image_url']?.toString();
    final resolvedUrl = ServiceRepository.resolveImageUrl(imageUrl);

    // Included services list from API
    List<String> includes = [];
    if (package['includes'] is List) {
      includes = (package['includes'] as List)
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (includes.isEmpty) {
      includes = [
        "Full Grooming & Bathing",
        "Gentle Coat Shampoo & Condition",
        "Nail Trimming & Buffing",
        "Ear Cleaning & Sanitary Care",
      ];
    }

    final id = package['id'] ?? package['packageId'] ?? 1;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Package Banner / Image
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: 286,
                      width: double.infinity,
                      child: _buildPackageImage(id, resolvedUrl),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 17,
                      child: _buildBackButton(context),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 24, 17, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag & Price row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "Special Package",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              priceDisplay,
                              style: AppFonts.poppins(
                                size: 15,
                                weight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        style: AppFonts.parkinsans(
                          size: 24,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        description.isNotEmpty
                            ? description
                            : "Comprehensive grooming package designed to give your pet complete pampering with bath, styling, nail trim, and hygienic ear care.",
                        style: AppFonts.poppins(
                          size: 14.5,
                          weight: FontWeight.w400,
                          color: const Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "What's Included",
                        style: AppFonts.parkinsans(
                          size: 17,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...includes.map((item) => _includedItem(item)),
                      const SizedBox(height: 24),
                      Text(
                        "Estimated Duration",
                        style: AppFonts.parkinsans(
                          size: 17,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/images/services/fi_992700_1_2382.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF111827),
                                BlendMode.srcIn,
                              ),
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 18,
                                    color: Color(0xFF111827),
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              duration > 0
                                  ? "Approximately $duration minutes"
                                  : "Approximately 60 minutes",
                              style: AppFonts.poppins(
                                size: 13.5,
                                weight: FontWeight.w500,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom Action Bar
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            17,
            12,
            17,
            MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 10
                : 20,
          ),
          child: GestureDetector(
            onTap: () => context.pushNamed(
              RouteNames.bookingService,
              extra: {'service': package, 'from_popular': true},
            ),
            child: Container(
              width: double.infinity,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                "Book Appointment",
                style: AppFonts.parkinsans(
                  size: 17,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPackageImage(dynamic id, String? resolvedUrl) {
    String fallbackAsset;
    final intId = id is int ? id : int.tryParse(id.toString()) ?? 1;
    if (intId == 2) {
      fallbackAsset = 'assets/images/home/package_banner_1.png';
    } else if (intId == 3) {
      fallbackAsset = 'assets/images/home/package_banner_2.png';
    } else {
      fallbackAsset = 'assets/images/packages/package_banner.png';
    }

    Widget fallbackWidget() => Image.asset(
          fallbackAsset,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (ctx, err, st) => Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF1C1B1F),
            alignment: Alignment.center,
            child: const Icon(Icons.auto_awesome, size: 64, color: Colors.white54),
          ),
        );

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      if (resolvedUrl.startsWith('assets/')) {
        return FigmaImage(
          asset: resolvedUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          fallback: fallbackWidget(),
        );
      }
      return Image.network(
        resolvedUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (ctx, err, st) => fallbackWidget(),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFFF3F4F6),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF111827),
            ),
          );
        },
      );
    }
    return fallbackWidget();
  }

  Widget _includedItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/images/services/fi_2767192_1_2354.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Color(0xFF111827),
              BlendMode.srcIn,
            ),
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppFonts.poppins(
                size: 14.5,
                weight: FontWeight.w400,
                color: const Color(0xFF111827),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
