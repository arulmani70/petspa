import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class ServiceDetailPageMobile extends StatelessWidget {
  final String serviceId;
  final Map<String, dynamic>? initialService;

  const ServiceDetailPageMobile({
    super.key,
    required this.serviceId,
    this.initialService,
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
            context.goNamed(RouteNames.services);
          } catch (_) {}
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: BlocBuilder<ServiceBloc, ServiceState>(
            builder: (context, state) {
              Map<String, dynamic>? service = state.selectedService;
              if (service != null && initialService != null) {
                final initName = initialService!['name'] ?? initialService!['service_name'];
                final stateName = service['name'] ?? service['service_name'];
                if (initName != null &&
                    stateName != null &&
                    initName.toString().trim().toLowerCase() !=
                        stateName.toString().trim().toLowerCase()) {
                  service = initialService;
                }
              }
              service ??= initialService;
              if (service != null) {
                return _buildDetail(context, service);
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
                    ShimmerBox(width: 80, height: 12, radius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(width: 220, height: 20, radius: 8),
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
                    SizedBox(height: 28),
                    ShimmerBox(width: 110, height: 16, radius: 6),
                    SizedBox(height: 14),
                    ShimmerBox(width: double.infinity, height: 39, radius: 10),
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
                const Icon(Icons.info_outline, size: 48, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 12),
                Text(
                  message.isNotEmpty ? message : "Service not found",
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
                      .add(GetServiceDetail(serviceId)),
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
            context.goNamed(RouteNames.services);
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

  Widget _buildDetail(BuildContext context, Map<String, dynamic> service) {
    final name =
        service[Constants.database.COLUMN_SERVICE_NAME]?.toString() ??
        service['service_name']?.toString() ??
        service['name']?.toString() ??
        'Service Details';
    final description =
        service[Constants.database.COLUMN_DESCRIPTION]?.toString() ??
        service['description']?.toString() ??
        '';
    final rating =
        (service[Constants.database.COLUMN_RATING] as num?)?.toDouble() ?? 4.9;
    final duration =
        (service[Constants.database.COLUMN_DURATION_MIN] as num?)?.toInt() ??
        (service['durationMinutes'] as num?)?.toInt() ??
        60;
    final isMostBooked =
        (service[Constants.database.COLUMN_TAG]?.toString() ?? '') ==
        'MOST_BOOKED';

    final priceRaw = service[Constants.database.COLUMN_PRICE] ?? service['price'];
    final priceDisplay = service['priceDisplay']?.toString() ??
        service['price_display']?.toString() ??
        (priceRaw != null ? '\$$priceRaw' : '');

    final imageUrl = service['imageUrl']?.toString() ??
        service['image_url']?.toString() ??
        service['image']?.toString() ??
        service['photo_url']?.toString();
    final resolvedUrl = ServiceRepository.resolveImageUrl(imageUrl);

    // Included items list
    List<String> includes = [];
    if (service['includes'] is List) {
      includes = (service['includes'] as List)
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (includes.isEmpty) {
      includes = [
        "Bath with premium pet-safe shampoo",
        "Coat trim and brush-out",
        "Nail trimming and ear cleaning",
        "Finishing blow dry and fluff",
      ];
    }

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
                // Top Hero Image
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: 286,
                      width: double.infinity,
                      child: _buildServiceImage(name, resolvedUrl),
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
                      // Tag + Price row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Service Details",
                            style: AppFonts.poppins(
                              size: 13,
                              weight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          if (priceDisplay.isNotEmpty)
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
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: AppFonts.parkinsans(
                          size: 24,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            rating.toStringAsFixed(1),
                            style: AppFonts.poppins(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "-",
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ),
                          Text(
                            isMostBooked ? "Most Booked Service" : "Professional Care",
                            style: AppFonts.poppins(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          if (duration > 0) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                "-",
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ),
                            const Icon(
                              Icons.schedule,
                              size: 15,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$duration min",
                              style: AppFonts.poppins(
                                size: 13.5,
                                weight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description.isNotEmpty
                            ? description
                            : "Our professional grooming session provides refreshing bathing, coat brushing, trimming, nail clipping, ear cleaning, and finishing touches tailored to your pet's needs.",
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
                        "Suitable For",
                        style: AppFonts.parkinsans(
                          size: 17,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _SuitableChip("All Breeds"),
                          _SuitableChip("Long & Short"),
                          _SuitableChip("3 Months +"),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Time Taken Around",
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
                                  ? "Takes approximately $duration minutes"
                                  : "Takes approximately 45-60 minutes",
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
              extra: {'service': service, 'from_popular': true},
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

  Widget _buildServiceImage(String name, String? resolvedUrl) {
    Widget fallback() {
      final localAsset = serviceAssetFor(name.split(' — ').last.trim()) ??
          serviceAssetFor(name);
      if (localAsset != null) {
        return FigmaImage(
          asset: localAsset,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          fallback: _iconPlaceholder(),
        );
      }
      return FigmaImage(
        asset: 'assets/images/services/service_detail_img.png',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        fallback: _iconPlaceholder(),
      );
    }

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      if (resolvedUrl.startsWith('assets/')) {
        return FigmaImage(
          asset: resolvedUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          fallback: fallback(),
        );
      }
      return Image.network(
        resolvedUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (ctx, err, st) => fallback(),
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
    return fallback();
  }

  Widget _iconPlaceholder() => Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFECECEC),
        alignment: Alignment.center,
        child: Icon(
          Icons.pets,
          size: 88,
          color: Colors.black.withValues(alpha: 0.12),
        ),
      );

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
              Icons.arrow_circle_right_outlined,
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

class _SuitableChip extends StatelessWidget {
  final String label;

  const _SuitableChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(60),
        border: Border.all(
          color: const Color(0xFF374151),
          width: 1.15,
        ),
      ),
      child: Text(
        label,
        style: AppFonts.poppins(
          size: 13,
          weight: FontWeight.w600,
          color: const Color(0xFF111827),
        ),
      ),
    );
  }
}
