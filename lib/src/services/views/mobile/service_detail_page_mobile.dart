import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';

class ServiceDetailPageMobile extends StatefulWidget {
  final String serviceId;

  const ServiceDetailPageMobile({super.key, required this.serviceId});

  @override
  State<ServiceDetailPageMobile> createState() =>
      _ServiceDetailPageMobileState();
}

class _ServiceDetailPageMobileState extends State<ServiceDetailPageMobile> {
  Map<String, dynamic>? _service;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    final id = int.tryParse(widget.serviceId);
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final service = await ServicesLocator.serviceRepository.getServiceById(id);
    if (mounted) {
      setState(() {
        _service = service;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: _loading
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(children: [
                  // Hero image skeleton
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
                ]),
              )
            : _service == null
            ? const Center(
                child: Text(
                  "Service not found",
                  style: TextStyle(color: Color(0xFF7B8794)),
                ),
              )
            : _buildDetail(context),
      ),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final service = _service!;
    final name =
        service[Constants.database.COLUMN_SERVICE_NAME]?.toString() ?? '';
    final description =
        service[Constants.database.COLUMN_DESCRIPTION]?.toString() ?? '';
    final rating =
        (service[Constants.database.COLUMN_RATING] as num?)?.toDouble() ?? 0;
    final duration =
        (service[Constants.database.COLUMN_DURATION_MIN] as num?)?.toInt() ?? 0;
    final isMostBooked =
        (service[Constants.database.COLUMN_TAG]?.toString() ?? '') ==
        'MOST_BOOKED';

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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: 286,
                      width: double.infinity,
                      child: FigmaImage(
                        asset: 'assets/images/services/service_detail_img.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        fallback: Container(
                          color: const Color(0xFFECECEC),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.pets,
                            size: 88,
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 17,
                      child: GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.goNamed(RouteNames.services);
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
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 24, 17, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Service Details",
                        style: AppFonts.poppins(
                          size: 13,
                          weight: FontWeight.w500,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name.isNotEmpty ? name : "Full Grooming",
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
                            rating > 0 ? rating.toStringAsFixed(1) : "4.9",
                            style: AppFonts.poppins(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "-",
                              style: AppFonts.poppins(
                                size: 13.5,
                                weight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          Text(
                            isMostBooked || rating > 0
                                ? "Most Booked Service"
                                : "Most Booked Service",
                            style: AppFonts.poppins(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description.isNotEmpty
                            ? description
                            : "Our Full Service Pet Grooming includes a refreshing bath, blow drying, brushing, haircut, styling, Nail Clipping, ear cleaning, and finishing touches. Every grooming session is tailored to your dog's breed coat condition, and individual needs.",
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
                      _includedItem("Bath with premium pet-safe shampoo"),
                      _includedItem("Coat trim and brush-out"),
                      _includedItem("Nail trimming and ear cleaning"),
                      _includedItem("Finishing blow dry and fluff"),
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
                                  : "Takes approximately 60-90 minutes",
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
            onTap: () => context.goNamed(
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
