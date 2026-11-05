import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
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

  void _openOfferDetails(OfferModel offer) {
    final imagePath = offer.imageUrl != null && offer.imageUrl!.isNotEmpty
        ? offer.imageUrl!
        : 'assets/images/common/offer_1.png';

    final terms = offer.minOrderAmount != null && offer.minOrderAmount! > 0
        ? 'Minimum order amount of \$${offer.minOrderAmount!.toStringAsFixed(0)} required. Valid until ${offer.validUntil ?? 'further notice'} · Cannot be combined with other offers · Subject to store terms & conditions.'
        : 'Valid until ${offer.validUntil ?? 'further notice'} · Cannot be combined with other offers · Limit one redemption per pet · Subject to store terms & conditions.';

    OfferDetailsDialog.show(
      context,
      imagePath: imagePath,
      badgeText: offer.discountBadge,
      title: offer.title,
      timerText: offer.formattedExpiry,
      promoCode: offer.promoCode,
      description: offer.description.isNotEmpty
          ? offer.description
          : (offer.label ?? 'Special discount available on your next booking.'),
      eligibleServices: offer.appliesToText,
      termsConditions: terms,
      onClaim: () {
        Clipboard.setData(ClipboardData(text: offer.promoCode));
        ServicesLocator.bookingDraft.applyOffer({
          'offerId': offer.id,
          'promoCode': offer.promoCode,
          'couponCode': offer.promoCode,
          'title': offer.title,
          'description': offer.description,
          'badgeText': offer.discountBadge,
          'discountType': offer.discountType,
          'discountValue': offer.discountValue,
          'appliesTo': offer.appliesTo,
        });
        ToastUtil.showSuccessToast(
          context,
          'Promo ${offer.promoCode} applied to booking!',
        );
        context.pushNamed(RouteNames.bookingService);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canPop = false;
    try {
      canPop = context.canPop();
    } catch (_) {
      canPop = Navigator.of(context).canPop();
    }

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        try {
          context.goNamed(RouteNames.home);
        } catch (_) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
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
              try {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
              } catch (_) {}
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                try {
                  context.goNamed(RouteNames.home);
                } catch (_) {}
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

            // Loading state
            if (state.status == OfferStatus.loading && offers.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2.5,
                ),
              );
            }

            // Error state
            if (state.status == OfferStatus.failure && offers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 52,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Unable to load offers',
                        style: AppFonts.parkinsans(
                          size: 17,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.message.isNotEmpty
                            ? state.message
                            : 'Please check your connection and try again.',
                        style: AppFonts.poppins(
                          size: 13,
                          color: const Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _handleRefresh,
                        child: Text(
                          'Try Again',
                          style: AppFonts.parkinsans(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Empty state
            if (offers.isEmpty) {
              return RefreshIndicator(
                onRefresh: _handleRefresh,
                color: Colors.black,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          size: 56,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No offers available right now',
                          style: AppFonts.parkinsans(
                            size: 16,
                            weight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for seasonal promotions, special packages, and exclusive discounts.',
                          style: AppFonts.poppins(
                            size: 13,
                            color: const Color(0xFF6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Loaded state with actual API offers
            final countText =
                '${offers.length} ${offers.length == 1 ? 'offer' : 'offers'} available for your account';

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              color: Colors.black,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    ...offers.map((offer) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildDynamicOfferCard(offer),
                        )),
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
    final imagePath = offer.imageUrl != null && offer.imageUrl!.isNotEmpty
        ? offer.imageUrl!
        : 'assets/images/common/offer_1.png';

    final isRedTimer = offer.isExpired;

    return GestureDetector(
      onTap: () => _openOfferDetails(offer),
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
            // Banner Image & Badges
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
                            child: const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            ),
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
                            child: const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            ),
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
                      offer.discountBadge,
                      style: AppFonts.parkinsans(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                if (offer.appliesTo != null && offer.appliesTo!.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        offer.appliesToText,
                        style: AppFonts.poppins(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Card Content
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
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
                        color: isRedTimer
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF757575),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        offer.formattedExpiry,
                        style: AppFonts.poppins(
                          size: 12,
                          weight: FontWeight.w500,
                          color: isRedTimer
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF757575),
                        ),
                      ),
                      if (offer.minOrderAmount != null && offer.minOrderAmount! > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•  Min. \$${offer.minOrderAmount!.toStringAsFixed(0)}',
                          style: AppFonts.poppins(
                            size: 12,
                            color: const Color(0xFF757575),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (offer.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      offer.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.poppins(
                        size: 13,
                        color: const Color(0xFF616161),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Promo Code pill with tap-to-copy
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: offer.promoCode));
                          ToastUtil.showSuccessToast(
                            context,
                            'Promo code ${offer.promoCode} copied!',
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                offer.promoCode,
                                style: AppFonts.parkinsans(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Claim Now Button
                      InkWell(
                        onTap: () => _openOfferDetails(offer),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
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
