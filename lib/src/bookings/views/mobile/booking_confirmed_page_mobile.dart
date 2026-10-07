import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
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
    final petName = summary['pet_name']?.toString() ?? '';
    final petBreed = summary['pet_breed']?.toString() ?? '';
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
    final serviceName = summary['service_name']?.toString() ?? '';
    final dateLabel = summary['date_label']?.toString() ?? '';
    final timeLabel = summary['time_label']?.toString() ?? '';
    final totalPrice = summary['total_price'];
    final durationMinutes = summary['total_duration_minutes'];


    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 33),
              SvgPicture.asset(
                'assets/images/common/logo.svg',
                width: 111,
                height: 63,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(width: 111, height: 63),
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 31, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Column(
                  children: [
                    SvgPicture.asset(
                      'assets/images/bookings/fi_4436481_1_1782.svg',
                      width: 66,
                      height: 66,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check, size: 40, color: Color(0xFF4BAE4F)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      "Booking Confirmed",
                      style: AppFonts.parkinsans(size: 22, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$petName's appointment is all set. See you at the salon!",
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(size: 14, weight: FontWeight.w400),
                    ),
                    const SizedBox(height: 46),
                    Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: _buildPetImage(petPhoto)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(petName, style: AppFonts.poppins(size: 20, weight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text("Breed: $petBreed", style: AppFonts.poppins(size: 13.4, weight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: Color(0xFFE4E9EC), height: 1),
                    const SizedBox(height: 18),
                    _detailRow(
                      icon: SvgPicture.asset(
                        'assets/images/common/fi_1144760_1_2311.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.cleaning_services, size: 18, color: Colors.black),
                      ),
                      label: serviceName,
                    ),
                    const SizedBox(height: 15),
                    _detailRow(
                      icon: SvgPicture.asset(
                        'assets/images/bookings/fi_833593_1_1808.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.calendar_today, size: 16, color: Colors.black),
                      ),
                      label: "$dateLabel · $timeLabel",
                    ),
                    if (durationMinutes != null) ...[
                      const SizedBox(height: 15),
                      _detailRow(
                        icon: const Icon(Icons.schedule, size: 16, color: Colors.black),
                        label: "Duration: $durationMinutes min",
                      ),
                    ],
                    if (summary['applied_offer'] != null) ...[
                      const SizedBox(height: 15),
                      _detailRow(
                        icon: const Icon(Icons.local_offer_outlined, size: 16, color: Color(0xFF16A34A)),
                        label: "Promo Applied: ${summary['applied_offer']?['promoCode'] ?? ''}",
                      ),
                    ],
                    if (totalPrice != null) ...[
                      const SizedBox(height: 15),
                      _detailRow(
                        icon: SvgPicture.asset(
                          'assets/images/bookings/fi_1076745_1_1768.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.attach_money, size: 16, color: Colors.black),
                        ),
                        label: "Total: \$$totalPrice",
                      ),
                    ],
                    const SizedBox(height: 15),
                    _detailRow(
                      icon: SvgPicture.asset(
                        'assets/images/common/icon_pin.svg',
                        width: 10,
                        height: 13,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.location_on, size: 17, color: Colors.black),
                      ),
                      label: "Shear Heaven Pet Spa, Arlington",
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/bookings/fi_6816684_1_1828.svg',
                                    width: 14,
                                    height: 14,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.event_available, size: 14, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Add to Calender",
                                    style: AppFonts.parkinsans(size: 16, weight: FontWeight.w600, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.goNamed(RouteNames.myBookings),
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black),
                            ),
                            child: Text(
                              "View",
                              style: AppFonts.parkinsans(size: 16, weight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              GestureDetector(
                onTap: () => context.goNamed(RouteNames.home),
                child: Text(
                  "Go to Home",
                  style: AppFonts.parkinsans(size: 16, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetImage(String? photo) {
    if (photo != null && photo.isNotEmpty) {
      if (photo.startsWith('http')) {
        return Image.network(
          photo,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.pets, color: Colors.black, size: 30),
        );
      } else if (photo.startsWith('/')) {
        return Image.network(
          '${Constants.app.BASE_URL}$photo',
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.pets, color: Colors.black, size: 30),
        );
      } else if (photo.startsWith('assets/')) {
        return Image.asset(
          photo,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.pets, color: Colors.black, size: 30),
        );
      } else {
        try {
          final file = File(photo);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.pets, color: Colors.black, size: 30),
            );
          }
        } catch (_) {}
      }
    }
    return const Icon(Icons.pets, color: Colors.black, size: 30);
  }

  Widget _detailRow({required Widget icon, required String label}) {
    return Row(
      children: [
        SizedBox(width: 18, height: 18, child: Center(child: icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppFonts.poppins(size: 16, weight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}
