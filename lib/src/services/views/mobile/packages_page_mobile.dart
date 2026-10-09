import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';

class PackagesPageMobile extends StatelessWidget {
  const PackagesPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ServiceBloc(repository: ServicesLocator.serviceRepository)
            ..add(const GetAllPackages()),
      child: PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.goNamed(RouteNames.home);
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.home);
                }
              },
            ),
            title: const Text(
              "All Packages",
              style: TextStyle(
                fontFamily: 'Parkinsans',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          body: BlocBuilder<ServiceBloc, ServiceState>(
            builder: (context, state) {
              if (state.status == ServiceStatus.loading &&
                  state.packages.isEmpty) {
                // ── Skeleton loading ────────────────────────────────────────
                return ListView(
                  padding: const EdgeInsets.fromLTRB(17, 22, 17, 24),
                  children: const [
                    PackageCardSkeleton(), SizedBox(height: 20),
                    PackageCardSkeleton(), SizedBox(height: 20),
                    PackageCardSkeleton(),
                  ],
                );
              }

              final packages = state.packages;
              
              if (state.status == ServiceStatus.success && packages.isEmpty) {
                return const Center(child: Text("No packages available"));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(17, 22, 17, 24),
                itemCount: packages.length,
                itemBuilder: (context, index) {
                  final package = packages[index];
                  return _PackageCard(package: package);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;

  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    final name =
        package[Constants.database.COLUMN_PACKAGE_NAME]?.toString() ?? '';
    final description =
        package[Constants.database.COLUMN_DESCRIPTION]?.toString() ?? '';
    final priceRaw = package[Constants.database.COLUMN_PRICE];
    final price = priceRaw is num ? priceRaw.toDouble() : (priceRaw != null ? double.tryParse(priceRaw.toString().replaceAll(RegExp(r'[^0-9.]'), '')) : null);
    final breedList = package['breeds']?.toString() ?? '';
    final services = package['services']?.toString() ?? '';
    final hasExtra = package['extra'] == true;

    final groomingPrice =
        package['grooming_price']?.toString() ??
        (price != null ? '\$${price.toStringAsFixed(0)}' : '\$68');
    final bathPrice =
        package['bath_price']?.toString() ??
        (price != null ? '\$${(price * 0.59).round()}' : '\$40');
    final singlePrice = price != null
        ? '\$${price.toStringAsFixed(0)}'
        : '\$24';

    final double cardHeight;
    if (hasExtra) {
      final painter = TextPainter(
        text: TextSpan(
          text: services,
          style: AppFonts.poppins(
            size: 18,
            weight: FontWeight.w400,
            color: Colors.white,
            height: 20 / 18,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 240);
      cardHeight = math.max(
        227,
        28 + 69 + math.max(painter.height, 45) + 50 + 21 + 8,
      );
    } else {
      cardHeight = 227;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        height: cardHeight + 64,
        child: Stack(
          children: [
            Positioned(
              top: cardHeight - 56,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                padding: const EdgeInsets.fromLTRB(23, 70, 23, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(size: 16, weight: FontWeight.w400),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: cardHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1B1F),
                          image: figmaDecorationImage(
                            'assets/images/packages/package_banner.png',
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(23, 28, 23, 21),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(
                              size: 20,
                              weight: FontWeight.w600,
                              color: Colors.white,
                              height: 20 / 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            breedList,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(
                              size: 14,
                              weight: FontWeight.w400,
                              color: Colors.white,
                              height: 20 / 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (hasExtra)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    services,
                                    style: AppFonts.poppins(
                                      size: 18,
                                      weight: FontWeight.w400,
                                      color: Colors.white,
                                      height: 20 / 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      singlePrice,
                                      style: AppFonts.montserrat(
                                        size: 22,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 27.97 / 22,
                                      ),
                                    ),
                                    Text(
                                      "& UP",
                                      style: AppFonts.poppins(
                                        size: 14,
                                        weight: FontWeight.w400,
                                        color: Colors.white,
                                        height: 20 / 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else ...[
                            _priceRow(label: "Grooming", price: groomingPrice),
                            const SizedBox(height: 10),
                            _priceRow(label: "Bath", price: bathPrice),
                          ],
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.goNamed(
                              RouteNames.bookingService,
                              extra: {'service': package, 'from_popular': true},
                            ),
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                "Book Now",
                                style: AppFonts.poppins(
                                  size: 17.7,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow({required String label, required String price}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppFonts.poppins(
              size: 18,
              weight: FontWeight.w400,
              color: Colors.white,
              height: 20 / 18,
            ),
          ),
        ),
        Text(
          price,
          style: AppFonts.montserrat(
            size: 22,
            weight: FontWeight.w700,
            color: Colors.white,
            height: 27.97 / 22,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "& UP",
          style: AppFonts.poppins(
            size: 14,
            weight: FontWeight.w400,
            color: Colors.white,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

