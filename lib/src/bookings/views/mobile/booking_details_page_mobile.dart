import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_calendar_service.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';

class BookingDetailsPageMobile extends StatefulWidget {
  final Map<String, dynamic>? bookingData;

  const BookingDetailsPageMobile({
    super.key,
    this.bookingData,
  });

  @override
  State<BookingDetailsPageMobile> createState() => _BookingDetailsPageMobileState();
}

class _BookingDetailsPageMobileState extends State<BookingDetailsPageMobile> {
  final Logger _log = Logger();
  Map<String, dynamic>? _fetchedPet;

  @override
  void initState() {
    super.initState();
    _fetchPetData();
  }

  int? _extractPetId(Map<String, dynamic> summary) {
    final raw = summary['petId'] ??
        summary['pet_id'] ??
        summary['PetId'] ??
        summary[Constants.database.COLUMN_PET_ID] ??
        (summary['pet'] is Map
            ? (summary['pet']['id'] ??
               summary['pet']['petId'] ??
               summary['pet']['pet_id'] ??
               summary['pet']['_id'] ??
               summary['pet'][Constants.database.COLUMN_ID])
            : null) ??
        (summary['Pet'] is Map
            ? (summary['Pet']['id'] ??
               summary['Pet']['petId'] ??
               summary['Pet']['pet_id'] ??
               summary['Pet']['_id'] ??
               summary['Pet'][Constants.database.COLUMN_ID])
            : null);
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String _extractRawPetName(Map<String, dynamic> summary) {
    final embedded = (summary['pet'] is Map)
        ? Map<String, dynamic>.from(summary['pet'] as Map)
        : (summary['Pet'] is Map ? Map<String, dynamic>.from(summary['Pet'] as Map) : null);
    final raw = embedded?[Constants.database.COLUMN_PET_NAME] ??
        embedded?['name'] ??
        embedded?['petName'] ??
        embedded?['pet_name'] ??
        summary['pet_name'] ??
        summary['petName'] ??
        summary['name'] ??
        summary[Constants.database.COLUMN_PET_NAME];
    return raw?.toString().trim() ?? '';
  }

  Future<void> _fetchPetData() async {
    try {
      context.read<PetBloc>().add(const GetAllPets());
    } catch (_) {}

    final summary = widget.bookingData ?? ServicesLocator.bookingDraft.lastBooking ?? const <String, dynamic>{};
    final petId = _extractPetId(summary);
    if (petId != null && petId > 0) {
      try {
        final pet = await ServicesLocator.petRepository.getPetById(petId);
        if (mounted && pet != null && pet.isNotEmpty) {
          setState(() {
            _fetchedPet = pet;
          });
        }
      } catch (e) {
        _log.w("BookingDetailsPageMobile::_fetchPetData::Error: $e");
      }
    }
  }

  String? _resolvePetPhoto(
    Map<String, dynamic>? matchedPet,
    Map<String, dynamic>? embeddedPet,
    Map<String, dynamic> summary,
  ) {
    final candidates = [
      matchedPet?[Constants.database.COLUMN_PHOTO_URL],
      matchedPet?['profilePictureUrl'],
      matchedPet?['profilePicture'],
      matchedPet?['profile_picture_url'],
      matchedPet?['profile_picture'],
      matchedPet?['photo_url'],
      matchedPet?['photoUrl'],
      matchedPet?['petPhotoUrl'],
      matchedPet?['pet_photo_url'],
      matchedPet?['petPhoto'],
      matchedPet?['pet_photo'],
      matchedPet?['image'],
      matchedPet?['avatar'],
      matchedPet?['petImage'],
      matchedPet?['pet_image'],
      embeddedPet?[Constants.database.COLUMN_PHOTO_URL],
      embeddedPet?['profilePictureUrl'],
      embeddedPet?['profilePicture'],
      embeddedPet?['photo_url'],
      embeddedPet?['photoUrl'],
      embeddedPet?['pet_photo_url'],
      embeddedPet?['petPhotoUrl'],
      embeddedPet?['pet_photo'],
      embeddedPet?['image'],
      embeddedPet?['avatar'],
      summary['pet_photo'],
      summary['pet_photo_url'],
      summary['petPhotoUrl'],
      summary['petPhoto'],
      summary['photo_url'],
      summary['photoUrl'],
      summary['profilePictureUrl'],
      summary['profilePicture'],
      summary['image'],
      summary['avatar'],
    ];

    for (final c in candidates) {
      if (c != null) {
        final s = c.toString().trim();
        if (s.isNotEmpty && s != 'null' && s != 'undefined') {
          return s;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final BookingDraft draft = ServicesLocator.bookingDraft;
    final summary = widget.bookingData ?? draft.lastBooking ?? const <String, dynamic>{};

    final rawStatus = summary['status']?.toString().toLowerCase() ?? 'confirmed';
    final statusDisplay = _formatStatusLabel(rawStatus);

    final petId = _extractPetId(summary);

    // Watch PetBloc state to react in real-time to any pet profile updates
    List<Map<String, dynamic>> userPets = const [];
    try {
      userPets = context.watch<PetBloc>().state.pets;
    } catch (_) {}

    // Find saved pet profile by petId
    Map<String, dynamic>? matchedPet;
    if (petId != null && petId > 0 && userPets.isNotEmpty) {
      for (final p in userPets) {
        final pId = p[Constants.database.COLUMN_ID] ?? p['id'] ?? p['_id'] ?? p['petId'];
        if (pId != null && (pId == petId || pId.toString() == petId.toString())) {
          matchedPet = p;
          break;
        }
      }
    }

    // Fallback to directly fetched pet from repository
    matchedPet ??= _fetchedPet;

    // Fallback by pet name from userPets if ID match wasn't found
    if (matchedPet == null && userPets.isNotEmpty) {
      final summaryName = _extractRawPetName(summary);
      if (summaryName.isNotEmpty && summaryName != 'Teddy' && summaryName != 'Pet') {
        for (final p in userPets) {
          final pName = (p[Constants.database.COLUMN_PET_NAME] ?? p['name'] ?? p['petName'])?.toString();
          if (pName != null && pName.toLowerCase() == summaryName.toLowerCase()) {
            matchedPet = p;
            break;
          }
        }
      }
    }

    final embeddedPet = (summary['pet'] is Map)
        ? Map<String, dynamic>.from(summary['pet'] as Map)
        : (summary['Pet'] is Map ? Map<String, dynamic>.from(summary['Pet'] as Map) : null);

    final petNameRaw = matchedPet?[Constants.database.COLUMN_PET_NAME]?.toString().trim() ??
        matchedPet?['name']?.toString().trim() ??
        matchedPet?['petName']?.toString().trim() ??
        embeddedPet?['pet_name']?.toString().trim() ??
        embeddedPet?['petName']?.toString().trim() ??
        embeddedPet?['name']?.toString().trim() ??
        summary['pet_name']?.toString().trim() ??
        summary['petName']?.toString().trim() ??
        summary['name']?.toString().trim() ??
        '';
    final petName = petNameRaw.isNotEmpty && petNameRaw != 'null' ? petNameRaw : 'Pet';

    final petBreedRaw = matchedPet?[Constants.database.COLUMN_BREED]?.toString().trim() ??
        matchedPet?['breed']?.toString().trim() ??
        matchedPet?['petBreed']?.toString().trim() ??
        embeddedPet?['pet_breed']?.toString().trim() ??
        embeddedPet?['petBreed']?.toString().trim() ??
        embeddedPet?['breed']?.toString().trim() ??
        summary['pet_breed']?.toString().trim() ??
        summary['petBreed']?.toString().trim() ??
        summary['breed']?.toString().trim() ??
        '';
    final petBreed = (petBreedRaw.isNotEmpty && petBreedRaw != 'null' && petBreedRaw != 'N/A')
        ? petBreedRaw
        : 'Unknown';

    final petGenderRaw = matchedPet?['gender']?.toString().trim() ??
        embeddedPet?['gender']?.toString().trim() ??
        summary['gender']?.toString().trim() ??
        '';
    final petGender = (petGenderRaw.isNotEmpty && petGenderRaw != 'null')
        ? (petGenderRaw.toLowerCase() == 'female'
            ? 'Female'
            : (petGenderRaw.toLowerCase() == 'male' ? 'Male' : petGenderRaw))
        : '';

    final petWeightRaw = matchedPet?[Constants.database.COLUMN_WEIGHT]?.toString() ??
        matchedPet?['weight']?.toString() ??
        matchedPet?['petWeight']?.toString() ??
        embeddedPet?['pet_weight']?.toString() ??
        embeddedPet?['weight']?.toString() ??
        embeddedPet?['petWeight']?.toString() ??
        summary['pet_weight']?.toString() ??
        summary['petWeight']?.toString() ??
        summary['weight']?.toString();

    final petBirthDateRaw = matchedPet?[Constants.database.COLUMN_BIRTH_DATE]?.toString() ??
        matchedPet?['dateOfBirth']?.toString() ??
        matchedPet?['birth_date']?.toString() ??
        matchedPet?['birthDate']?.toString() ??
        embeddedPet?['pet_birth_date']?.toString() ??
        embeddedPet?['birth_date']?.toString() ??
        embeddedPet?['dateOfBirth']?.toString() ??
        embeddedPet?['birthDate']?.toString() ??
        summary['pet_birth_date']?.toString() ??
        summary['birth_date']?.toString() ??
        summary['dateOfBirth']?.toString() ??
        summary['birthDate']?.toString();

    final directAge = matchedPet?['age'] ?? embeddedPet?['age'] ?? summary['age'];

    final petPhoto = _resolvePetPhoto(matchedPet, embeddedPet, summary);

    final rawServiceName = summary['service_name']?.toString().trim() ??
        summary['service']?['service_name']?.toString().trim() ??
        '';
    final serviceName = rawServiceName.isNotEmpty ? rawServiceName : 'Full Grooming';

    final addOnsList = _extractAddOns(summary);
    final hasAddOns = addOnsList.isNotEmpty ||
        summary['has_addons'] == true ||
        (summary['addons_count'] != null && (summary['addons_count'] as int) > 0);

    final dateLabel = summary['date_label']?.toString().trim() ??
        summary['booking_date']?.toString().trim() ??
        summary['bookingDate']?.toString().trim() ??
        summary['date']?.toString().trim() ??
        '';
    final timeLabel = summary['time_label']?.toString().trim() ??
        summary['start_time']?.toString().trim() ??
        summary['startTime']?.toString().trim() ??
        summary['time']?.toString().trim() ??
        '';

    final formattedWeight = _formatWeight(petWeightRaw);
    final formattedAge = _petAge(petBirthDateRaw, directAge);

    final serviceDisplayText = hasAddOns ? '$serviceName + Add On Services' : serviceName;
    final dateTimeDisplayText = (dateLabel.isNotEmpty && timeLabel.isNotEmpty)
        ? '$dateLabel · $timeLabel'
        : (dateLabel.isNotEmpty
            ? dateLabel
            : (timeLabel.isNotEmpty ? timeLabel : 'Aug 4, 2026 · 10:30 AM'));

    bool canPop = false;
    try {
      canPop = context.canPop();
    } catch (_) {
      try {
        canPop = Navigator.canPop(context);
      } catch (_) {}
    }

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        try {
          context.goNamed(RouteNames.myBookings);
        } catch (_) {}
      },
      child: Scaffold(
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Navigation Bar: Back Arrow on left & Centered Logo
                    SizedBox(
                      width: double.infinity,
                      height: 75,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () {
                                try {
                                  if (context.canPop()) {
                                    context.pop();
                                    return;
                                  }
                                } catch (_) {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                    return;
                                  }
                                }
                                try {
                                  context.goNamed(RouteNames.myBookings);
                                } catch (_) {}
                              },
                              behavior: HitTestBehavior.opaque,
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.arrow_back,
                                  color: Colors.black,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          SvgPicture.asset(
                            'assets/images/common/logo.svg',
                            width: 120,
                            height: 68,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(width: 120, height: 68),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Main White Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pet Details Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(16),
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
                                      petName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.poppins(
                                        size: 20,
                                        weight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        SvgPicture.asset(
                                          'assets/images/pets/icon_dog_breed.svg',
                                          width: 14,
                                          height: 14,
                                          colorFilter: const ColorFilter.mode(
                                              Color(0xFF374151), BlendMode.srcIn),
                                          errorBuilder: (c, e, s) => const Icon(
                                              Icons.pets,
                                              size: 14,
                                              color: Color(0xFF374151)),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              text: "Breed: ",
                                              style: AppFonts.poppins(
                                                size: 13,
                                                weight: FontWeight.w400,
                                                color: const Color(0xFF374151),
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: petBreed,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                if (petGender.isNotEmpty)
                                                  TextSpan(
                                                    text: ' · $petGender',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF4B5563),
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
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SvgPicture.asset(
                                                'assets/images/pets/icon_pet_weight.svg',
                                                width: 14,
                                                height: 14,
                                                colorFilter: const ColorFilter.mode(
                                                    Color(0xFF374151), BlendMode.srcIn),
                                                errorBuilder: (c, e, s) => const Icon(
                                                    Icons.fitness_center,
                                                    size: 14,
                                                    color: Color(0xFF374151)),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text.rich(
                                                  TextSpan(
                                                    text: "Weight: ",
                                                    style: AppFonts.poppins(
                                                      size: 13,
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
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.pets,
                                                size: 13,
                                                color: Color(0xFF374151),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text.rich(
                                                  TextSpan(
                                                    text: "Age: ",
                                                    style: AppFonts.poppins(
                                                      size: 13,
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

                          const SizedBox(height: 18),
                          const _DashedDivider(),
                          const SizedBox(height: 18),

                          // Status Tag Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: _statusBgColor(rawStatus),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _statusBorderColor(rawStatus), width: 1),
                            ),
                            child: Text(
                              statusDisplay,
                              style: AppFonts.poppins(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: _statusTextColor(rawStatus),
                              ),
                            ),
                          ),

                          // Cancellation Reason Box
                          if (rawStatus == 'cancelled' ||
                              rawStatus == 'canceled' ||
                              (summary['cancellationReason'] != null && summary['cancellationReason'].toString().isNotEmpty) ||
                              (summary['cancellation_reason'] != null && summary['cancellation_reason'].toString().isNotEmpty)) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Cancellation Reason: ${summary['cancellationReason'] ?? summary['cancellation_reason'] ?? Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT}',
                                      style: AppFonts.poppins(
                                        size: 12.5,
                                        weight: FontWeight.w500,
                                        color: const Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Pending Acceptance Notice
                          if (rawStatus == 'pending') ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Awaiting groomer acceptance · Auto-cancels if not accepted by scheduled appointment time',
                                      style: AppFonts.poppins(
                                        size: 12,
                                        weight: FontWeight.w500,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // Detail Row 1: Scissors -> Service Name (+ Add On Services)
                          _detailRow(
                            icon: SvgPicture.asset(
                              'assets/images/bookings/icon_scissors.svg',
                              width: 17,
                              height: 17,
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcIn),
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.content_cut,
                                      size: 17, color: Colors.black),
                            ),
                            label: serviceDisplayText,
                          ),
                          const SizedBox(height: 14),

                          // Detail Row 2: Calendar Clock -> Date & Time
                          _detailRow(
                            icon: SvgPicture.asset(
                              'assets/images/bookings/fi_833593_1_1808.svg',
                              width: 17,
                              height: 17,
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcIn),
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.calendar_today,
                                      size: 17, color: Colors.black),
                            ),
                            label: dateTimeDisplayText,
                          ),
                          const SizedBox(height: 14),

                          // Detail Row 3: Location Pin -> Spa Location
                          _detailRow(
                            icon: SvgPicture.asset(
                              'assets/images/common/icon_pin.svg',
                              width: 14,
                              height: 17,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.location_on,
                                      size: 17, color: Colors.black),
                            ),
                            label: "Shear Heaven Pet Spa, Arlington",
                          ),

                          // Add On Services Section (2-Column Grid)
                          if (addOnsList.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              "Add On Services",
                              style: AppFonts.poppins(
                                size: 15.5,
                                weight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildAddOns2Column(addOnsList),
                          ],

                          const SizedBox(height: 24),

                          // Action Button: Add To Calender
                          GestureDetector(
                            onTap: () => BookingCalendarService.addToCalendar(context, summary),
                            child: Container(
                              height: 50,
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF262626),
                                    Color(0xFF111111),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/bookings/fi_6816684_1_1828.svg',
                                    width: 17,
                                    height: 17,
                                    colorFilter: const ColorFilter.mode(
                                        Colors.white, BlendMode.srcIn),
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.event_available,
                                            size: 17, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Add To Calender",
                                    style: AppFonts.poppins(
                                      size: 15.5,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Go to Home
                    GestureDetector(
                      onTap: () => context.goNamed(RouteNames.home),
                      child: Text(
                        "Go to Home",
                        style: AppFonts.poppins(
                          size: 15,
                          weight: FontWeight.w700,
                          color: Colors.black,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOns2Column(List<String> items) {
    final leftItems = <String>[];
    final rightItems = <String>[];
    for (int i = 0; i < items.length; i++) {
      if (i % 2 == 0) {
        leftItems.add(items[i]);
      } else {
        rightItems.add(items[i]);
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: leftItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildAddOnItem(item),
            )).toList(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rightItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildAddOnItem(item),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAddOnItem(String addOn) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFF3F4F6),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.pets, size: 11, color: Colors.black),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            addOn,
            style: AppFonts.poppins(
              size: 13.5,
              weight: FontWeight.w500,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<String> _extractAddOns(Map<String, dynamic> booking) {
    final list = <String>[];
    final rawAddOns = booking['addons'] ??
        booking['addOns'] ??
        booking['add_ons'] ??
        booking['addons_list'] ??
        booking['services_addons'];
    if (rawAddOns is List) {
      for (final item in rawAddOns) {
        if (item is Map) {
          final name = item['name'] ??
              item['service_name'] ??
              item['title'] ??
              item['addOnName'];
          if (name != null && name.toString().isNotEmpty) {
            list.add(name.toString());
          }
        } else if (item != null && item.toString().isNotEmpty) {
          list.add(item.toString());
        }
      }
    }
    if (list.isEmpty) {
      list.addAll(['Nail Grinding', 'Teeth Brushing', 'Blueberry Facial']);
    }
    return list;
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'in_progress':
      case 'inprogress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'pending':
        return 'Pending';
      default:
        return 'Confirmed';
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
      case 'completed':
        return const Color(0xFFF0FDF4);
      case 'in_progress':
      case 'inprogress':
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF0FDF4);
    }
  }

  Color _statusBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
      case 'completed':
        return const Color(0xFF22C55E);
      case 'in_progress':
      case 'inprogress':
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF22C55E);
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'in_progress':
      case 'inprogress':
      case 'pending':
        return const Color(0xFFD97706);
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF16A34A);
    }
  }

  String _formatWeight(String? weight) {
    if (weight == null) return 'N/A';
    final trimmed = weight.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'N/A') return 'N/A';
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('kg') ||
        lower.endsWith('lbs') ||
        lower.endsWith('lb') ||
        lower.contains('(')) {
      return trimmed;
    }
    if (double.tryParse(trimmed) != null) {
      return '${trimmed}kg';
    }
    return trimmed;
  }

  String _petAge(String? birthDate, [dynamic directAge]) {
    if (directAge != null) {
      final directStr = directAge.toString().trim();
      if (directStr.isNotEmpty && directStr != 'null' && directStr != 'N/A') {
        final parsedNum = num.tryParse(directStr);
        if (parsedNum != null) {
          return parsedNum == 1 ? '1yr' : '${parsedNum}yrs';
        }
        return directStr;
      }
    }
    if (birthDate == null ||
        birthDate.isEmpty ||
        birthDate == 'null' ||
        birthDate == 'N/A') {
      return 'N/A';
    }
    final parsed = DateTime.tryParse(birthDate);
    if (parsed == null) return birthDate.trim();
    final now = DateTime.now();
    var years = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      years--;
    }
    if (years <= 0) {
      final months = (now.difference(parsed).inDays / 30.4).round();
      return months <= 0 ? '< 1mo' : '${months}mos';
    }
    return '${years}yrs';
  }

  Widget _buildPetImage(String? photo) {
    if (photo != null) {
      final clean = photo.trim();
      if (clean.isNotEmpty && clean != 'null' && clean != 'undefined') {
        if (clean.startsWith('http://') || clean.startsWith('https://')) {
          return Image.network(
            clean,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } else if (clean.startsWith('assets/')) {
          return Image.asset(
            clean,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } else if (clean.startsWith('/') ||
            clean.startsWith('uploads/') ||
            clean.startsWith('images/')) {
          final url = clean.startsWith('/')
              ? '${Constants.app.BASE_URL}$clean'
              : '${Constants.app.BASE_URL}/$clean';
          return Image.network(
            url,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } else {
          try {
            final file = File(clean);
            if (file.existsSync()) {
              return Image.file(
                file,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              );
            }
          } catch (_) {}
          if (clean.contains('/') && !clean.contains('\\')) {
            return Image.network(
              '${Constants.app.BASE_URL}/$clean',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            );
          }
        }
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Image.asset(
      'assets/images/pets/sample_pet.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: const Icon(Icons.pets, color: Colors.black45, size: 32),
      ),
    );
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
              size: 14.5,
              weight: FontWeight.w500,
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
