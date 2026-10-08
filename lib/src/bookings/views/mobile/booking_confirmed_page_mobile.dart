import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_calendar_service.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

class BookingConfirmedPageMobile extends StatelessWidget {
  const BookingConfirmedPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final BookingDraft draft = ServicesLocator.bookingDraft;
    final summary = draft.lastBooking ?? const <String, dynamic>{};
    final status = summary['status']?.toString().toLowerCase() ?? 'confirmed';
    final isFailed = status == 'failed';

    final petName = summary['pet_name']?.toString().trim() ?? '';
    final petBreed = summary['pet_breed']?.toString().trim() ?? '';
    final petWeightRaw = summary['pet_weight']?.toString();
    final petBirthDateRaw = summary['pet_birth_date']?.toString();

    final petPhoto = summary['pet_photo']?.toString() ??
        summary['pet_photo_url']?.toString() ??
        summary['photo_url']?.toString() ??
        summary['profilePictureUrl']?.toString() ??
        summary['profilePicture']?.toString() ??
        summary['avatar']?.toString() ??
        summary['image']?.toString() ??
        summary['photo']?.toString() ??
        draft.pet?['photo_url']?.toString() ??
        draft.pet?['profilePictureUrl']?.toString() ??
        draft.pet?['profilePicture']?.toString();

    final rawServiceName = summary['service_name']?.toString().trim() ?? '';
    final serviceName = rawServiceName.isNotEmpty ? rawServiceName : 'Full Grooming';
    final hasAddOns = summary['has_addons'] == true ||
        (summary['addons_count'] != null && (summary['addons_count'] as int) > 0);

    final dateLabel = summary['date_label']?.toString().trim() ?? '';
    final timeLabel = summary['time_label']?.toString().trim() ?? '';

    final appliedOffer = summary['applied_offer'] as Map<String, dynamic>?;
    final promoCode = appliedOffer?['promoCode']?.toString() ??
        appliedOffer?['code']?.toString() ??
        summary['promo_code']?.toString();
    final promoDescription = appliedOffer?['description']?.toString() ??
        appliedOffer?['title']?.toString() ??
        (appliedOffer?['discountPercent'] != null
            ? '${appliedOffer!['discountPercent']}% off $serviceName'
            : (promoCode != null ? '$promoCode applied' : ''));

    final petDisplayName = petName.isNotEmpty ? petName : 'Your pet';
    final formattedWeight = _formatWeight(petWeightRaw);
    final formattedAge = _petAge(petBirthDateRaw);

    final serviceDisplayText = hasAddOns ? '$serviceName + Add On Services' : serviceName;
    final dateTimeDisplayText = (dateLabel.isNotEmpty && timeLabel.isNotEmpty)
        ? '$dateLabel · $timeLabel'
        : (dateLabel.isNotEmpty
            ? dateLabel
            : (timeLabel.isNotEmpty ? timeLabel : 'Aug 4, 2026 · 10:30 AM'));

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/common/welcome_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFF0F6FF),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  // Shear Heaven Logo
                  SvgPicture.asset(
                    'assets/images/common/logo.svg',
                    width: 115,
                    height: 65,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(width: 115, height: 65),
                  ),
                  const SizedBox(height: 18),
                  // Main Confirmation Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Status Badge Icon
                        if (isFailed)
                          Container(
                            width: 66,
                            height: 66,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF04438),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.close, color: Colors.white, size: 36),
                          )
                        else
                          SvgPicture.asset(
                            'assets/images/bookings/fi_4436481_1_1782.svg',
                            width: 66,
                            height: 66,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 66,
                              height: 66,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4BAE4F),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 40, color: Colors.white),
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Title
                        Text(
                          isFailed ? "Booking Failed" : "Booking Confirmed",
                          textAlign: TextAlign.center,
                          style: AppFonts.parkinsans(
                            size: 22,
                            weight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Subtitle
                        Text(
                          isFailed
                              ? "$petDisplayName's appointment is failed. Retry booking or please check again later."
                              : "$petDisplayName's appointment is all set. See you at the salon!",
                          textAlign: TextAlign.center,
                          style: AppFonts.poppins(
                            size: 13.5,
                            weight: FontWeight.w400,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Pet Details Card Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(child: _buildPetImage(petPhoto)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    petName.isNotEmpty ? petName : 'My Pet',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.poppins(
                                      size: 18,
                                      weight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      SvgPicture.asset(
                                        'assets/images/pets/icon_dog_breed.svg',
                                        width: 13,
                                        height: 13,
                                        colorFilter: const ColorFilter.mode(
                                            Color(0xFF374151), BlendMode.srcIn),
                                        errorBuilder: (c, e, s) => const Icon(
                                            Icons.pets,
                                            size: 13,
                                            color: Color(0xFF374151)),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            text: "Breed: ",
                                            style: AppFonts.poppins(
                                              size: 12,
                                              weight: FontWeight.w400,
                                              color: const Color(0xFF374151),
                                            ),
                                            children: [
                                              TextSpan(
                                                text: petBreed.isNotEmpty && petBreed != 'N/A' ? petBreed : 'All Breeds',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Flexible(
                                        flex: 1,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SvgPicture.asset(
                                              'assets/images/pets/icon_pet_weight.svg',
                                              width: 13,
                                              height: 13,
                                              colorFilter: const ColorFilter.mode(
                                                  Color(0xFF374151), BlendMode.srcIn),
                                              errorBuilder: (c, e, s) => const Icon(
                                                  Icons.fitness_center,
                                                  size: 13,
                                                  color: Color(0xFF374151)),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text.rich(
                                                TextSpan(
                                                  text: "Weight: ",
                                                  style: AppFonts.poppins(
                                                    size: 12,
                                                    weight: FontWeight.w400,
                                                    color: const Color(0xFF374151),
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: formattedWeight,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        flex: 1,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SvgPicture.asset(
                                              'assets/images/pets/icon_pet_age.svg',
                                              width: 13,
                                              height: 13,
                                              colorFilter: const ColorFilter.mode(
                                                  Color(0xFF374151), BlendMode.srcIn),
                                              errorBuilder: (c, e, s) => const Icon(
                                                  Icons.cake_outlined,
                                                  size: 13,
                                                  color: Color(0xFF374151)),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text.rich(
                                                TextSpan(
                                                  text: "Age: ",
                                                  style: AppFonts.poppins(
                                                    size: 12,
                                                    weight: FontWeight.w400,
                                                    color: const Color(0xFF374151),
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: formattedAge,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const _DashedDivider(),
                        const SizedBox(height: 16),

                        // Detail Row 1: Scissors -> Service Name (+ Add On Services)
                        _detailRow(
                          icon: SvgPicture.asset(
                            'assets/images/bookings/icon_scissors.svg',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                                Colors.black, BlendMode.srcIn),
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.content_cut,
                                    size: 16, color: Colors.black),
                          ),
                          label: serviceDisplayText,
                        ),
                        const SizedBox(height: 12),

                        // Detail Row 2: Calendar Clock -> Date & Time
                        _detailRow(
                          icon: SvgPicture.asset(
                            'assets/images/bookings/fi_833593_1_1808.svg',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                                Colors.black, BlendMode.srcIn),
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.calendar_today,
                                    size: 16, color: Colors.black),
                          ),
                          label: dateTimeDisplayText,
                        ),
                        const SizedBox(height: 12),

                        // Detail Row 3: Location Pin -> Spa Location
                        _detailRow(
                          icon: SvgPicture.asset(
                            'assets/images/common/icon_pin.svg',
                            width: 12,
                            height: 15,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.location_on,
                                    size: 16, color: Colors.black),
                          ),
                          label: "Shear Heaven Pet Spa, Arlington",
                        ),

                        // Applied Promo Banner (if promo applied)
                        if (promoCode != null && promoCode.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8EE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF86EFAC), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_outlined,
                                    size: 20,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "$promoCode Applied",
                                        style: AppFonts.poppins(
                                          size: 13.5,
                                          weight: FontWeight.w700,
                                          color: const Color(0xFF15803D),
                                        ),
                                      ),
                                      if (promoDescription.isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(
                                          promoDescription,
                                          style: AppFonts.poppins(
                                            size: 12,
                                            weight: FontWeight.w400,
                                            color: const Color(0xFF166534),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // Action Buttons
                        if (isFailed)
                          GestureDetector(
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.goNamed(RouteNames.petSelect);
                              }
                            },
                            child: Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF2B2B2B),
                                    Color(0xFF141414),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/bookings/fi_6816684_1_1828.svg',
                                    width: 15,
                                    height: 15,
                                    colorFilter: const ColorFilter.mode(
                                        Colors.white, BlendMode.srcIn),
                                    errorBuilder: (context, error,
                                            stackTrace) =>
                                        const Icon(Icons.event_available,
                                            size: 15, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Retry Booking",
                                    style: AppFonts.parkinsans(
                                      size: 15,
                                      weight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: GestureDetector(
                                  onTap: () => BookingCalendarService.addToCalendar(context, summary),
                                  child: Container(
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF2B2B2B),
                                          Color(0xFF141414),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          'assets/images/bookings/fi_6816684_1_1828.svg',
                                          width: 15,
                                          height: 15,
                                          colorFilter: const ColorFilter.mode(
                                              Colors.white, BlendMode.srcIn),
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Icon(Icons.event_available,
                                                  size: 15,
                                                  color: Colors.white),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            "Add To Calendar",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.parkinsans(
                                              size: 14,
                                              weight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: GestureDetector(
                                  onTap: () =>
                                      context.pushNamed(RouteNames.bookingDetails, extra: summary),
                                  child: Container(
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                          color: Colors.black, width: 1.2),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.visibility_outlined,
                                            size: 18, color: Colors.black),
                                        const SizedBox(width: 6),
                                        Text(
                                          "View",
                                          style: AppFonts.parkinsans(
                                            size: 14,
                                            weight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Go to Home
                  GestureDetector(
                    onTap: () => context.goNamed(RouteNames.home),
                    child: Text(
                      "Go to Home",
                      style: AppFonts.parkinsans(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.black,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(String? weight) {
    if (weight == null || weight.isEmpty || weight == 'null' || weight == 'N/A') return 'Standard';
    final trimmed = weight.trim();
    if (trimmed.toLowerCase().endsWith('kg') ||
        trimmed.toLowerCase().endsWith('lbs') ||
        trimmed.toLowerCase() == 'standard') {
      return trimmed;
    }
    return '${trimmed}kg';
  }

  String _petAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty || birthDate == 'null' || birthDate == 'N/A') return 'All Ages';
    final parsed = DateTime.tryParse(birthDate);
    if (parsed == null) return birthDate;
    final now = DateTime.now();
    var years = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      years--;
    }
    return years <= 0
        ? '${(now.difference(parsed).inDays / 30.4).round()}mos'
        : '${years}yrs';
  }

  Widget _buildPetImage(String? photo) {
    if (photo != null && photo.isNotEmpty) {
      if (photo.startsWith('http')) {
        return Image.network(
          photo,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.pets, color: Colors.black, size: 28),
        );
      } else if (photo.startsWith('/')) {
        return Image.network(
          '${Constants.app.BASE_URL}$photo',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.pets, color: Colors.black, size: 28),
        );
      } else if (photo.startsWith('assets/')) {
        return Image.asset(
          photo,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.pets, color: Colors.black, size: 28),
        );
      } else {
        try {
          final file = File(photo);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.pets, color: Colors.black, size: 28),
            );
          }
        } catch (_) {}
      }
    }
    return const Icon(Icons.pets, color: Colors.black, size: 28);
  }

  Widget _detailRow({required Widget icon, required String label}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 18, height: 18, child: Center(child: icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              size: 14,
              weight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: CustomPaint(
        painter: _DashedLinePainter(color: const Color(0xFFD1D5DB)),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height > 0 ? size.height : 1.0;
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    double startX = 0;
    while (startX < size.width) {
      final endX = (startX + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(startX, 0), Offset(endX, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
