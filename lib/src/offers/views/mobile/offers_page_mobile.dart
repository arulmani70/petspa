import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/offer_details_dialog.dart';
import 'package:shear_heaven_pet_spa/src/offers/bloc/offer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/offers/models/offer_model.dart';

class OffersPageMobile extends StatefulWidget {
  const OffersPageMobile({super.key});

  @override
  State<OffersPageMobile> createState() => _OffersPageMobileState();
}

class _OffersPageMobileState extends State<OffersPageMobile> {
  @override
  void initState() {
    super.initState();
    context.read<OfferBloc>().add(const FetchOffers());
  }

  Future<void> _handleRefresh() async {
    context.read<OfferBloc>().add(const FetchOffers());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed(RouteNames.home);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAFAFA),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(RouteNames.home);
              }
            },
          ),
        title: Text(
          'Available Offers',
          style: AppFonts.parkinsans(
            size: 18,
            weight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
      ),
      body: BlocBuilder<OfferBloc, OfferState>(
        builder: (context, state) {
          final offers = state.offers;
          final countText = offers.isNotEmpty
              ? '${offers.length} offers available for your account'
              : '3 offers available for your account';

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.black,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  Text(
                    countText,
                    style: AppFonts.poppins(
                      size: 14,
                      weight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (offers.isNotEmpty)
                    ...offers.map((offer) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildDynamicOfferCard(offer),
                        ))
                  else ...[
                    _buildStaticOfferCard(
                      imagePath: 'assets/images/common/offer_1.png',
                      badgeText: '50% OFF',
                      title: '50% Off Full Grooming for New Pets!',
                      isRedTimer: true,
                      timerText: 'Ends in 2 days 14:32:10',
                      promoCode: 'PAWSOME50',
                      description:
                          "Get 50% off your pet's first Full Grooming session with us. A perfect way to try the royal treatment your pet deserves.",
                      eligibleServices: 'Full Grooming, Spa Package',
                      termsConditions:
                          'Valid for first-time customers only · Cannot be combined with other offers · Limit one redemption per pet · Valid at Shear Heaven Pet Spa, Calicut only.',
                    ),
                    const SizedBox(height: 16),
                    _buildStaticOfferCard(
                      imagePath: 'assets/images/common/offer_2.png',
                      badgeText: 'FREE ADD-ON',
                      title: 'Summer Splash: Free Nail Trimming',
                      isRedTimer: false,
                      timerText: 'Ends Aug 20',
                      promoCode: 'PAWSOME50',
                      description:
                          "Complimentary nail trimming add-on with every grooming appointment booked this summer season.",
                      eligibleServices: 'All Grooming Services',
                      termsConditions:
                          'Valid until Aug 20 · One redemption per pet · Subject to slot availability.',
                    ),
                    const SizedBox(height: 16),
                    _buildStaticOfferCard(
                      imagePath: 'assets/images/common/offer_3.png',
                      badgeText: 'REFER & EARN',
                      title: 'Refer a Friend, Get 20% Off',
                      isRedTimer: false,
                      timerText: 'No expiry',
                      promoCode: 'PAWSOME50',
                      description:
                          "Refer a fellow pet parent and both of you enjoy 20% off on your next pet spa visit!",
                      eligibleServices: 'All Services & Packages',
                      termsConditions:
                          'Referral discount applies once your friend completes their first service booking.',
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    ),
    );
  }

  Widget _buildDynamicOfferCard(OfferModel offer) {
    return _buildStaticOfferCard(
      imagePath: offer.imageUrl ?? 'assets/images/common/offer_1.png',
      badgeText: offer.discountBadge,
      title: offer.title,
      isRedTimer: offer.expiryDate != null,
      timerText: offer.formattedExpiry,
      promoCode: offer.promoCode,
      description: offer.description.isNotEmpty
          ? offer.description
          : "Get special discounts on our premium pet grooming packages.",
      eligibleServices: 'Full Grooming, Spa Package',
      termsConditions:
          'Valid for selected services only · Subject to store terms & conditions.',
    );
  }

  Widget _buildStaticOfferCard({
    required String imagePath,
    required String badgeText,
    required String title,
    required bool isRedTimer,
    required String timerText,
    required String promoCode,
    String? description,
    String? eligibleServices,
    String? termsConditions,
  }) {
    return GestureDetector(
      onTap: () {
        OfferDetailsDialog.show(
          context,
          imagePath: imagePath,
          badgeText: badgeText,
          title: title,
          timerText: timerText,
          promoCode: promoCode,
          description: description ??
              "Get 50% off your pet's first Full Grooming session with us. A perfect way to try the royal treatment your pet deserves.",
          eligibleServices: eligibleServices ?? 'Full Grooming, Spa Package',
          termsConditions: termsConditions ??
              'Valid for first-time customers only · Cannot be combined with other offers · Limit one redemption per pet · Valid at Shear Heaven Pet Spa, Calicut only.',
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: imagePath.startsWith('http')
                      ? Image.network(
                          imagePath,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 160,
                            color: Colors.grey.shade300,
                            child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                          ),
                        )
                      : Image.asset(
                          imagePath,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 160,
                            color: Colors.grey.shade300,
                            child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                          ),
                        ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      badgeText,
                      style: AppFonts.parkinsans(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.parkinsans(
                      size: 16,
                      weight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: isRedTimer ? const Color(0xFFD32F2F) : const Color(0xFF757575),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timerText,
                        style: AppFonts.poppins(
                          size: 12,
                          weight: FontWeight.w500,
                          color: isRedTimer ? const Color(0xFFD32F2F) : const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          promoCode,
                          style: AppFonts.parkinsans(
                            size: 12,
                            weight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          OfferDetailsDialog.show(
                            context,
                            imagePath: imagePath,
                            badgeText: badgeText,
                            title: title,
                            timerText: timerText,
                            promoCode: promoCode,
                            description: description ??
                                "Get 50% off your pet's first Full Grooming session with us. A perfect way to try the royal treatment your pet deserves.",
                            eligibleServices:
                                eligibleServices ?? 'Full Grooming, Spa Package',
                            termsConditions: termsConditions ??
                                'Valid for first-time customers only · Cannot be combined with other offers · Limit one redemption per pet · Valid at Shear Heaven Pet Spa, Calicut only.',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            'Claim Now',
                            style: AppFonts.parkinsans(
                              size: 14,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
