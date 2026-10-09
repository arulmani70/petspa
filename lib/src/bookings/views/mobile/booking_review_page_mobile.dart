import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/slot_capacity.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_header.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';

import 'package:shear_heaven_pet_spa/src/offers/models/offer_model.dart';

class BookingReviewPageMobile extends StatefulWidget {
  const BookingReviewPageMobile({super.key});

  @override
  State<BookingReviewPageMobile> createState() => _BookingReviewPageMobileState();
}

class _BookingReviewPageMobileState extends State<BookingReviewPageMobile> {
  late final BookingDraft _draft;
  bool _confirming = false;
  bool _isApplyingPromo = false;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();
  final Logger _log = Logger();

  @override
  void initState() {
    super.initState();
    _draft = ServicesLocator.bookingDraft;
    if (_draft.appliedPromoCode != null) {
      _promoController.text = _draft.appliedPromoCode!;
    }
    _ensurePetDetails();
  }

  Future<void> _ensurePetDetails() async {
    try {
      if (ServicesLocator.sessionService.isLoggedIn) {
        final pets = await ServicesLocator.petRepository.getAllPets();
        if (pets.isNotEmpty && mounted) {
          final currentPetId = int.tryParse(_draft.pet?['id']?.toString() ?? '0') ?? 0;
          if (currentPetId == 0) {
            final selectedBreed = _draft.pet?['breed']?.toString().toLowerCase() ?? '';
            final matched = pets.firstWhere(
              (p) => selectedBreed.isNotEmpty && p['breed']?.toString().toLowerCase() == selectedBreed,
              orElse: () => pets.first,
            );
            _draft.setPet(matched);
          }
        }
      }
    } catch (e) {
      _log.d("BookingReviewPage::_ensurePetDetails::Error: $e");
    }

    if (_draft.pet == null) {
      final svcName = _draft.service?['service_name']?.toString() ?? _draft.service?['name']?.toString() ?? '';
      final breedName = svcName.contains(' — ') ? svcName.split(' — ').first.trim() : 'My Pet';
      _draft.setPet({
        'pet_name': breedName,
        'breed': breedName != 'My Pet' ? breedName : 'All Breeds',
        'weight': 'Standard',
        'photo_url': _draft.service?['imageUrl'] ?? _draft.service?['photo_url'],
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromoCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      ToastUtil.showErrorToast(context, 'Please enter a promo code.');
      return;
    }

    if (_isApplyingPromo) return;
    setState(() => _isApplyingPromo = true);

    try {
      final baseAmount = _draft.totalPrice ?? _draft.estimatedTotal;
      final result = await ServicesLocator.offerRepository.validatePromo(
        promoCode: trimmed,
        orderAmount: baseAmount > 0 ? baseAmount : 100.0,
      );

      if (!mounted) return;

      if (result.success) {
        _draft.applyOffer({
          'promoCode': result.promoCode ?? trimmed,
          'discountAmount': result.discountAmount,
          'discountType': result.discountType,
          'discountValue': result.discountValue,
          'finalAmount': result.finalAmount,
          'description': result.description ?? '${result.promoCode ?? trimmed} applied',
        });
        _promoController.text = result.promoCode ?? trimmed;
        ToastUtil.showSuccessToast(context, result.message.isNotEmpty ? result.message : 'Promo code applied successfully!');
      } else {
        ToastUtil.showErrorToast(context, result.message);
      }
    } catch (e) {
      if (!mounted) return;
      ToastUtil.showErrorToast(context, 'Failed to validate promo code. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isApplyingPromo = false);
      }
    }
  }

  void _removePromoCode() {
    setState(() {
      _draft.removeOffer();
      _promoController.clear();
    });
    ToastUtil.showSuccessToast(context, 'Promo code removed.');
  }

  Future<void> _showAvailableOffersModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<OfferModel>>(
              future: ServicesLocator.offerRepository.getOffers(),
              builder: (context, snapshot) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_offer_outlined, color: Color(0xFF111827), size: 22),
                              const SizedBox(width: 8),
                              Text(
                                "Available Offers",
                                style: AppFonts.parkinsans(
                                  size: 18,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    Expanded(
                      child: _buildOffersModalBody(snapshot, scrollController, modalContext),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOffersModalBody(
    AsyncSnapshot<List<OfferModel>> snapshot,
    ScrollController scrollController,
    BuildContext modalContext,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF111827), strokeWidth: 2.5),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                'Could not load offers',
                style: AppFonts.poppins(size: 15, weight: FontWeight.w600, color: const Color(0xFF111827)),
              ),
              const SizedBox(height: 6),
              Text(
                'Please check your network and try again.',
                style: AppFonts.poppins(size: 13, color: const Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final offers = snapshot.data ?? [];
    if (offers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_offer_outlined, size: 54, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 14),
              Text(
                'No offers available right now',
                style: AppFonts.poppins(size: 15.5, weight: FontWeight.w600, color: const Color(0xFF374151)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Check back later for seasonal promotions and special discounts.',
                style: AppFonts.poppins(size: 12.5, color: const Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final offer = offers[index];
        final isApplied = _draft.appliedPromoCode?.toUpperCase() == offer.promoCode.toUpperCase();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isApplied ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isApplied ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isApplied ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.card_giftcard_outlined,
                  size: 22,
                  color: isApplied ? const Color(0xFF16A34A) : const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            offer.promoCode,
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (isApplied) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Active',
                              style: AppFonts.poppins(size: 10.5, weight: FontWeight.w600, color: const Color(0xFF059669)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      offer.title,
                      style: AppFonts.poppins(size: 14.5, weight: FontWeight.w600, color: const Color(0xFF111827)),
                    ),
                    if (offer.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        offer.description,
                        style: AppFonts.poppins(size: 12.5, color: const Color(0xFF4B5563)),
                      ),
                    ],
                    if (offer.minOrderAmount != null && offer.minOrderAmount! > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Min. order \$${offer.minOrderAmount!.toStringAsFixed(0)}',
                        style: AppFonts.poppins(size: 11, color: const Color(0xFF9CA3AF)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApplied ? const Color(0xFFDC2626) : const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(modalContext).pop();
                  if (isApplied) {
                    _removePromoCode();
                  } else {
                    _applyPromoCode(offer.promoCode);
                  }
                },
                child: Text(
                  isApplied ? 'Remove' : 'Apply',
                  style: AppFonts.poppins(size: 12.5, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGuestLoginPrompt() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign In to Book Appointment',
          style: AppFonts.parkinsans(
            size: 18,
            weight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        content: Text(
          'Please sign in or create an account to finalize your booking and secure your appointment.',
          style: AppFonts.poppins(
            size: 14,
            color: const Color(0xFF374151),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF111827)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pushNamed(RouteNames.signup);
            },
            child: Text(
              'Create Account',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pushNamed(RouteNames.login);
            },
            child: Text(
              'Sign In',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (!ServicesLocator.sessionService.isLoggedIn) {
      _showGuestLoginPrompt();
      return;
    }

    if (_confirming) return;
    setState(() => _confirming = true);

    try {
      _log.d("BookingReviewPage::_confirmBooking::Starting booking confirmation");

      int petId = int.tryParse(_draft.pet?['id']?.toString() ?? '0') ?? 0;
      if (petId == 0 && ServicesLocator.sessionService.isLoggedIn) {
        try {
          final pets = await ServicesLocator.petRepository.getAllPets();
          if (pets.isNotEmpty) {
            final selectedBreed = _draft.pet?['breed']?.toString().toLowerCase() ?? '';
            final matched = pets.firstWhere(
              (p) => selectedBreed.isNotEmpty && p['breed']?.toString().toLowerCase() == selectedBreed,
              orElse: () => pets.first,
            );
            _draft.setPet(matched);
            petId = int.tryParse(matched['id']?.toString() ?? '0') ?? 0;
          } else {
            final rawName = _draft.pet?['pet_name']?.toString() ?? 'My Pet';
            final rawBreed = _draft.pet?['breed']?.toString() ?? 'All Breeds';
            final newPetId = await ServicesLocator.petRepository.createPet({
              Constants.database.COLUMN_PET_NAME: rawName,
              Constants.database.COLUMN_BREED: rawBreed != 'All Breeds' ? rawBreed : 'Dog',
              Constants.database.COLUMN_WEIGHT: _draft.pet?['weight']?.toString() ?? 'Standard',
            });
            if (newPetId > 0) {
              petId = newPetId;
              final newPetMap = Map<String, dynamic>.from(_draft.pet ?? {});
              newPetMap['id'] = newPetId;
              _draft.setPet(newPetMap);
            }
          }
        } catch (e) {
          _log.w("BookingReviewPage::_confirmBooking::Auto-resolve pet exception: $e");
        }
      }

      final ids = _draft.extractServiceIds();
      final serviceId = ids['serviceId'] as int?;
      final packageId = ids['packageId'] as int?;

      int groomerId = 0;
      final gId = _draft.groomer?['id']?.toString() ?? '';
      if (gId.isNotEmpty && gId != 'any') {
        groomerId = int.tryParse(gId) ?? 0;
      }

      final addOnIds = _draft.extractAddOnIds();
      final bookingDate = _draft.date != null ? DateFormat('yyyy-MM-dd').format(_draft.date!) : '';
      final startTime = _draft.timeSlot ?? '';
      final endTime = _draft.endTime ?? '';

      if (petId == 0 ||
          bookingDate.isEmpty ||
          startTime.isEmpty ||
          endTime.isEmpty ||
          (packageId == null && serviceId == null)) {
        if (!mounted) return;
        ToastUtil.showErrorToast(
            context, 'Missing required booking information. Please go back and select a time slot.');
        setState(() => _confirming = false);
        return;
      }

      if (_draft.date == null || !BookingDateUtils.isDateAllowed(_draft.date)) {
        if (!mounted) return;
        ToastUtil.showErrorToast(
            context, BookingDateUtils.invalidDateMessage);
        setState(() => _confirming = false);
        return;
      }

      final session = ServicesLocator.sessionService;

      final effectiveServiceId = (serviceId != null && serviceId > 0)
          ? serviceId
          : (packageId != null && packageId > 0 ? packageId : null);
      final effectivePackageId = (packageId != null && packageId > 0)
          ? packageId
          : null;

      // ---- Step 1: POST /api/availability — fresh pre-flight capacity validation ---
      _log.d("BookingReviewPage::_confirmBooking::Refreshing slot availability before booking");

      final validateResponse = await ServicesLocator.bookingRepository.getAvailability(
        date: bookingDate,
        serviceId: effectiveServiceId,
        packageId: (effectivePackageId != null && effectivePackageId != effectiveServiceId)
            ? effectivePackageId
            : null,
        addOnIds: addOnIds.isEmpty ? null : addOnIds,
        groomerId: groomerId > 0 ? groomerId : null,
      );

      if (!mounted) return;

      _log.d("BookingReviewPage::_confirmBooking::Availability response received");

      String correctedEndTime = endTime;

      if (validateResponse != null &&
          validateResponse['success'] == true &&
          validateResponse['data'] != null) {
        final availData  = validateResponse['data'] as Map<String, dynamic>;
        final availSlots = availData['availableSlots'] as List<dynamic>? ?? [];
        final apiDurMin  = availData['totalDurationMinutes'];

        // ── Recalculate endTime from backend duration + startTime ────────────
        if (apiDurMin is num && apiDurMin > 0) {
          correctedEndTime = _addMinutes(startTime, apiDurMin.toInt());
          _draft.apiDurationMinutes = apiDurMin.toInt();
        }

        final apiPrice = availData['totalPrice'];
        if (apiPrice is num) {
          _draft.apiTotalPrice = apiPrice.toDouble();
        }

        // ── Step 1b: Exact Slot Matching & Capacity Validation ───────────────
        _log.d("BookingReviewPage::_confirmBooking::Validating selected slot capacity");

        final matchingSlot = availSlots.whereType<Map>().firstWhere(
          (s) => s['startTime']?.toString() == startTime,
          orElse: () => <String, dynamic>{},
        );

        if (matchingSlot.isEmpty) {
          _log.d("BookingReviewPage::_confirmBooking::Selected slot is full or unavailable");
          ToastUtil.showErrorToast(
              context,
              'This slot is no longer available. Please go back and select another time.');
          setState(() => _confirming = false);
          return;
        }

        final capacity = SlotCapacity.fromSlotData(
          Map<String, dynamic>.from(matchingSlot),
          groomerData: _draft.groomer,
        );

        _log.d("BookingReviewPage::_confirmBooking::Capacity status: "
            "${capacity.bookingCount}/${capacity.maxBookings}, remaining=${capacity.remaining}, available=${capacity.isAvailable}");

        if (!mounted) return;

        final isCapacityAvailable = capacity.isAvailable &&
            capacity.remaining > 0 &&
            capacity.bookingCount < capacity.maxBookings;

        if (!isCapacityAvailable) {
          const errorMsg = 'This slot is no longer available. Please go back and select another time.';
          _log.d("BookingReviewPage::_confirmBooking::Selected slot is blocked: $errorMsg");
          ToastUtil.showErrorToast(context, errorMsg);
          setState(() => _confirming = false);
          return;
        }

        _log.d("BookingReviewPage::_confirmBooking::Selected slot is available");

        // Update draft slot with corrected endTime
        _draft.setSelectedSlot({
          'startTime'  : startTime,
          'endTime'    : correctedEndTime,
          'groomerId'  : _draft.selectedSlot?['groomerId'],
          'groomerName': _draft.selectedSlot?['groomerName'] ?? '',
        });
      } else {
        // Availability API call failed — do not blindly create booking
        final errMsg = validateResponse?['message']?.toString() ?? '';
        _log.w('BookingReviewPage::_confirmBooking::Availability check failed: $errMsg');

        String userMsg;
        if (validateResponse != null &&
            validateResponse['success'] == false &&
            errMsg.isNotEmpty) {
          userMsg = errMsg;
        } else {
          userMsg = 'Could not verify availability. Please go back and try again.';
        }
        ToastUtil.showErrorToast(context, userMsg);
        setState(() => _confirming = false);
        return;
      }

      // ---- Step 1c: Client-Side Customer Duplicate Booking Check -----------
      final finalStartTime = _draft.timeSlot ?? startTime;
      final finalEndTime   = _draft.endTime   ?? correctedEndTime;

      try {
        if (session.isLoggedIn) {
          final userBookings = await ServicesLocator.bookingRepository.getUpcomingBookingsApi();
          final isDuplicate = BookingDateUtils.isSlotAlreadyBookedByUser(
            slotDate: bookingDate,
            slotStartTime: finalStartTime,
            slotEndTime: finalEndTime,
            slotGroomerId: groomerId,
            slotDurationMinutes: _draft.apiDurationMinutes,
            userBookings: userBookings,
          );
          if (isDuplicate) {
            _log.w("BookingReviewPage::_confirmBooking::Customer already owns an active booking overlapping ($bookingDate, $finalStartTime-$finalEndTime, groomerId=$groomerId)");
            if (!mounted) return;
            ToastUtil.showErrorToast(
              context,
              'You already have an active booking for this date and time slot. Please choose another time.',
            );
            setState(() => _confirming = false);
            return;
          }
        }
      } catch (e) {
        _log.d("BookingReviewPage::_confirmBooking::Duplicate check exception: $e");
      }

      // ---- Step 2: POST /api/bookings — create booking ----------------------
      final createPayload = <String, dynamic>{
        'ClientId'   : session.clientId ?? 'SHEAR-001',
        'RegionId'   : session.regionId ?? 'DWG-001',
        'StoreId'    : session.storeId  ?? 'SHEAR-001',
        'petId'      : petId,
        if (effectiveServiceId != null) 'serviceId': effectiveServiceId, // ignore: use_null_aware_elements
        if (effectivePackageId != null && effectivePackageId != effectiveServiceId)
          'packageId': effectivePackageId, // ignore: use_null_aware_elements
        'addOnIds'   : addOnIds,
        'groomerId'  : groomerId,
        'bookingDate': bookingDate,
        'startTime'  : finalStartTime,
        'endTime'    : finalEndTime,
      };

      _log.d("BookingReviewPage::_confirmBooking::Calling POST /api/bookings");

      final response = await ServicesLocator.bookingRepository.createBookingApi(createPayload);

      if (response != null && response['success'] == true) {
        _log.d("BookingReviewPage::_confirmBooking::Booking created successfully");
        final data = response['data'] as Map<String, dynamic>?;
        final bookingId = data?['bookingId'];
        final apiPrice = data?['totalPrice'];
        final finalConfirmedPrice = _draft.discountedTotalPrice ??
            (apiPrice is num ? apiPrice.toDouble() : _draft.totalPrice);

        final petData = _draft.pet;
        final petPhoto = petData?[Constants.database.COLUMN_PHOTO_URL]?.toString() ??
            petData?['profilePictureUrl']?.toString() ??
            petData?['profilePicture']?.toString() ??
            petData?['photo_url']?.toString() ??
            petData?['avatar']?.toString() ??
            petData?['image']?.toString() ??
            petData?['photo']?.toString();

        _draft.lastBooking = {
          'booking_id': bookingId,
          'status': data?['status'] ?? 'confirmed',
          'total_price': finalConfirmedPrice,
          'total_duration_minutes': data?['totalDurationMinutes'] ?? _draft.duration,
          'pet_name': petData?['pet_name']?.toString() ?? petData?[Constants.database.COLUMN_PET_NAME]?.toString() ?? '',
          'pet_breed': petData?['breed']?.toString() ?? petData?[Constants.database.COLUMN_BREED]?.toString() ?? '',
          'pet_weight': petData?['weight']?.toString() ?? petData?[Constants.database.COLUMN_WEIGHT]?.toString(),
          'pet_birth_date': petData?['birth_date']?.toString() ?? petData?[Constants.database.COLUMN_BIRTH_DATE]?.toString(),
          'pet_photo': petPhoto,
          'pet_photo_url': petPhoto,
          'photo_url': petPhoto,
          'service_name': _draft.service?['service_name']?.toString() ?? _draft.service?[Constants.database.COLUMN_SERVICE_NAME]?.toString() ?? '',
          'has_addons': _draft.addOns.isNotEmpty,
          'addons_count': _draft.addOns.length,
          'date_label': _draft.date != null ? DateFormat('MMM d, yyyy').format(_draft.date!) : '',
          'time_label': _formatSlotTime(_draft.timeSlot ?? ''),
          'booking_date': _draft.date != null ? DateFormat('yyyy-MM-dd').format(_draft.date!) : '',
          'start_time': _draft.timeSlot ?? '',
          'end_time': _draft.endTime ?? '',
          'groomer_name': _draft.groomer?['name']?.toString() ?? '',
          'applied_offer': _draft.appliedOffer,
          'discount_amount': _draft.discountAmount,
        };
        _draft.reset();

        if (!mounted) return;
        context.goNamed(RouteNames.bookingConfirmed);
      } else {
        if (!mounted) return;

        if (response != null &&
            (response['code'] == 'GROOMER_NOT_AVAILABLE' || response['statusCode'] == 409)) {
          _log.d("BookingReviewPage::_confirmBooking::Groomer slot capacity reached");
          final errorMsg = response['message']?.toString() ??
              'Sorry, this slot was just taken. Please select another time.';
          ToastUtil.showErrorToast(context, errorMsg);
          context.pop();
        } else if (response != null && response['message'] != null) {
          String errMsg = response['message'] as String;
          if (response['errors'] != null &&
              response['errors'] is List &&
              (response['errors'] as List).isNotEmpty) {
            errMsg += ': ${(response['errors'] as List)[0]['message'] ?? ''}';
          }
          ToastUtil.showErrorToast(context, errMsg);
        } else {
          ToastUtil.showErrorToast(context, 'Could not create booking. Please try again.');
        }
        setState(() => _confirming = false);
      }
    } catch (error) {
      _log.e("BookingReviewPage::_confirmBooking::Booking confirmation failed: $error");
      if (!mounted) return;
      ToastUtil.showErrorToast(context, 'Network error: Could not create booking.');
      setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const db = DatabaseConstants();
    final petData = _draft.pet;
    final svcName = _draft.service?['service_name']?.toString() ?? _draft.service?['name']?.toString() ?? '';
    final inferredBreed = svcName.contains(' — ') ? svcName.split(' — ').first.trim() : '';

    String petName = petData?[db.COLUMN_PET_NAME]?.toString() ?? petData?['pet_name']?.toString() ?? '';
    if (petName.isEmpty || petName == 'N/A') {
      petName = inferredBreed.isNotEmpty ? inferredBreed : 'My Pet';
    }

    String petBreed = petData?[db.COLUMN_BREED]?.toString() ?? petData?['breed']?.toString() ?? '';
    if (petBreed.isEmpty || petBreed == 'N/A') {
      petBreed = inferredBreed.isNotEmpty ? inferredBreed : 'All Breeds';
    }

    final rawWeight = petData?[db.COLUMN_WEIGHT]?.toString() ?? petData?['weight']?.toString();
    final petWeight = (rawWeight != null && rawWeight.isNotEmpty && rawWeight != 'N/A')
        ? (rawWeight.toLowerCase().endsWith('kg') || rawWeight.toLowerCase().endsWith('lbs') || rawWeight.toLowerCase() == 'standard'
            ? rawWeight
            : '${rawWeight}kg')
        : 'Standard';

    final petBirth = petData?[db.COLUMN_BIRTH_DATE]?.toString() ?? petData?['birth_date']?.toString();
    final rawAge = petData?['age']?.toString();
    final petAgeDisplay = (petBirth != null && petBirth.isNotEmpty && petBirth != 'null')
        ? _petAge(petBirth)
        : (rawAge != null && rawAge.isNotEmpty && rawAge != 'N/A' ? rawAge : 'All Ages');

    final petPhoto = petData?[db.COLUMN_PHOTO_URL]?.toString() ??
        petData?['photo_url']?.toString() ??
        petData?['imageUrl']?.toString() ??
        _draft.service?['imageUrl']?.toString() ??
        _draft.service?['photo_url']?.toString();

    final serviceName = _draft.service?[db.COLUMN_SERVICE_NAME]?.toString() ?? _draft.service?['service_name']?.toString() ?? _draft.service?['name']?.toString() ?? 'Full Grooming';
    final serviceDesc = _draft.service?[db.COLUMN_DESCRIPTION]?.toString() ?? _draft.service?['description']?.toString() ?? 'Bath, trim, nails, and ears — the complete pampering session.';
    final date = _draft.date ?? DateTime.now();
    final slot = _draft.timeSlot ?? '';

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed(RouteNames.bookingDateTime);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BookingHeader(
              title: "Review & Confirm",
              step: 4,
              subtitle: "Step 4 of 4 - Review the Booking and Confirm",
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(17, 20, 17, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPromoCodeSection(),
                    _sectionTitle("Selected Pet", () => context.goNamed(RouteNames.petSelect)),
                    const SizedBox(height: 12),
                    _reviewCard(
                      image: _petImage(petPhoto),
                      imageDecoration: petPhoto != null && petPhoto.isNotEmpty ? null : const Color(0xFFFAFAFA),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            petName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(size: 18, weight: FontWeight.w700, color: Colors.black),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/images/pets/icon_dog_breed.svg',
                                width: 13,
                                height: 13,
                                colorFilter: const ColorFilter.mode(Color(0xFF374151), BlendMode.srcIn),
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.pets, size: 13, color: Color(0xFF374151)),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: AppFonts.poppins(size: 12, color: const Color(0xFF374151)),
                                    children: [
                                      const TextSpan(text: "Breed: ", style: TextStyle(fontWeight: FontWeight.w400)),
                                      TextSpan(
                                        text: petBreed,
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                                      ),
                                    ],
                                  ),
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
                                      colorFilter: const ColorFilter.mode(Color(0xFF374151), BlendMode.srcIn),
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.fitness_center, size: 13, color: Color(0xFF374151)),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: RichText(
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: AppFonts.poppins(size: 12, color: const Color(0xFF374151)),
                                          children: [
                                            const TextSpan(text: "Weight: ", style: TextStyle(fontWeight: FontWeight.w400)),
                                            TextSpan(
                                              text: petWeight,
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                                            ),
                                          ],
                                        ),
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
                                      colorFilter: const ColorFilter.mode(Color(0xFF374151), BlendMode.srcIn),
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.pets, size: 13, color: Color(0xFF374151)),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: RichText(
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: AppFonts.poppins(size: 12, color: const Color(0xFF374151)),
                                          children: [
                                            const TextSpan(text: "Age: ", style: TextStyle(fontWeight: FontWeight.w400)),
                                            TextSpan(
                                              text: petAgeDisplay,
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                                            ),
                                          ],
                                        ),
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
                    const SizedBox(height: 24),
                    _sectionTitle("Selected Service", () => context.pushNamed(RouteNames.bookingService)),
                    const SizedBox(height: 12),
                    _reviewCard(
                      image: _serviceImage(_draft.service),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(size: 17, weight: FontWeight.w600, color: Colors.black),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serviceDesc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(size: 13, weight: FontWeight.w300, color: const Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ),
                    if (_draft.addOns.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionTitle("Selected Add-ons", () => context.pushNamed(RouteNames.bookingService)),
                      const SizedBox(height: 12),
                      ..._draft.addOns.map((addOn) {
                        final addOnName = addOn['name'] ?? addOn['service_name'] ?? addOn['title'] ?? 'Add-on';
                        final addOnDesc = addOn['description'] ?? addOn['short_description'] ?? '';
                        final addOnPrice = addOn['price'] != null ? '\$${(addOn['price'] as num).toStringAsFixed(0)}' : '';
                        final addOnDur = addOn['duration'] ?? addOn['duration_minutes'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _reviewCard(
                            image: _serviceImage(addOn),
                            height: 100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        addOnName.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppFonts.poppins(size: 16, weight: FontWeight.w600, color: Colors.black),
                                      ),
                                    ),
                                    if (addOnPrice.isNotEmpty)
                                      Text(
                                        addOnPrice,
                                        style: AppFonts.poppins(size: 14.5, weight: FontWeight.w700, color: Colors.black),
                                      ),
                                  ],
                                ),
                                if (addOnDesc.toString().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    addOnDesc.toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.poppins(size: 12.5, weight: FontWeight.w300, color: const Color(0xFF6B7280)),
                                  ),
                                ],
                                if (addOnDur != null) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 12, color: Color(0xFF6B7280)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$addOnDur min',
                                        style: AppFonts.poppins(size: 11.5, weight: FontWeight.w500, color: const Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                    _sectionTitle("Selected Date & Time", () => context.pushNamed(RouteNames.bookingDateTime)),
                    const SizedBox(height: 12),
                    _reviewCard(
                      image: Center(
                        child: SvgPicture.asset(
                          'assets/images/bookings/fi_2693507_1_1728.svg',
                          width: 32,
                          height: 32,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.calendar_month, color: Colors.white, size: 32),
                        ),
                      ),
                      imageDecoration: Colors.black,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${DateFormat('MMM d, yyyy').format(date)} · ${_formatSlotTime(slot)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(size: 17, weight: FontWeight.w600, color: Colors.black),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _draft.groomer?['name'] != null &&
                                    _draft.groomer!['name'] != 'No. pref'
                                ? _draft.groomer!['name'].toString()
                                : 'No groomer preference',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.poppins(size: 13, weight: FontWeight.w300, color: const Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Notes for the groomer (optional)",
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 94,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 4,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.black, height: 16 / 14, letterSpacing: 0),
                        decoration: const InputDecoration(
                          hintText: "Eg: Teddy gets a little anxious with dryers...",
                          hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w300, color: Color(0xFFAFAFAF), height: 16 / 14, letterSpacing: 0),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(17, 21, 17, 24 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          'assets/images/bookings/fi_1076745_1_1768.svg',
                          width: 25,
                          height: 25,
                          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.account_balance_wallet, size: 22, color: Colors.black),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Payment is handled at the salon. No online payment required to confirm.",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _confirmBooking,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3A3A3A), Colors.black],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _confirming
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              "Confirm Booking",
                              style: AppFonts.parkinsans(
                                size: 18,
                                weight: FontWeight.w700,
                                color: Colors.white,
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
  );
}

  /// Adds [minutes] to a "HH:mm" time string and returns the result as "HH:mm".
  String _addMinutes(String hhmm, int minutes) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final totalMinutes =
        (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0) + minutes;
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _formatSlotTime(String slot) {
    if (slot.isEmpty) return '';
    if (slot.toUpperCase().contains('AM') || slot.toUpperCase().contains('PM')) {
      return slot;
    }
    final parts = slot.split(':');
    if (parts.isEmpty) return slot;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final meridiem = hour < 12 ? 'AM' : 'PM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:${minute.padLeft(2, '0')} $meridiem';
  }

  String _petAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty || birthDate == 'null') return 'All Ages';
    final parsed = DateTime.tryParse(birthDate);
    if (parsed == null) return 'All Ages';
    final now = DateTime.now();
    var years = now.year - parsed.year;
    if (now.month < parsed.month || (now.month == parsed.month && now.day < parsed.day)) {
      years--;
    }
    return years <= 0 ? '${(now.difference(parsed).inDays / 30.4).round()}mos' : '${years}yrs';
  }

  Widget _petImage(String? photo) {
    if (photo != null && photo.isNotEmpty) {
      if (photo.startsWith('http')) {
        return Image.network(
          photo,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Center(child: Icon(Icons.pets, color: Colors.black, size: 32)),
        );
      } else if (photo.startsWith('/')) {
        return Image.network(
          '${Constants.app.BASE_URL}$photo',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Center(child: Icon(Icons.pets, color: Colors.black, size: 32)),
        );
      } else {
        return Image.asset(
          photo,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Center(child: Icon(Icons.pets, color: Colors.black, size: 32)),
        );
      }
    }
    return const Center(child: Icon(Icons.pets, color: Colors.black, size: 32));
  }

  Widget _serviceImage(Map<String, dynamic>? service) {
    final photo = service?['image_url'] ??
        service?['imageUrl'] ??
        service?['photo_url'] ??
        service?['image'];
    if (photo != null && photo.toString().isNotEmpty) {
      final photoStr = photo.toString();
      if (photoStr.startsWith('http')) {
        return Image.network(
          photoStr,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _defaultServiceIcon(),
        );
      } else if (photoStr.startsWith('/')) {
        return Image.network(
          '${Constants.app.BASE_URL}$photoStr',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _defaultServiceIcon(),
        );
      } else {
        return Image.asset(
          photoStr,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _defaultServiceIcon(),
        );
      }
    }
    return _defaultServiceIcon();
  }

  Widget _defaultServiceIcon() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      alignment: Alignment.center,
      child: const Icon(Icons.cleaning_services, color: Colors.white, size: 32),
    );
  }

  Widget _sectionTitle(String title, VoidCallback onEdit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onEdit,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit, size: 16, color: Colors.black),
              SizedBox(width: 4),
              Text("Edit", style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewCard({
    required Widget child,
    required Widget image,
    Color? imageDecoration,
    double height = 109,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.fromLTRB(9, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 89,
            height: 89,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: imageDecoration ?? const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(15),
            ),
            child: image,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    final appliedOffer = _draft.appliedOffer;
    final isApplied = appliedOffer != null;
    final appliedCode = _draft.appliedPromoCode ?? '';
    final offerDesc = appliedOffer?['description']?.toString() ?? 'Special discount applied';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Have a promo code?",
          style: AppFonts.poppins(
            size: 16,
            weight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),

        // Input & Apply Row
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                ),
                child: TextField(
                  controller: _promoController,
                  textCapitalization: TextCapitalization.characters,
                  style: AppFonts.poppins(
                    size: 15,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    letterSpacing: 0.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: "Enter promo code",
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (value) => _applyPromoCode(value),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isApplyingPromo ? null : () => _applyPromoCode(_promoController.text),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isApplyingPromo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        "Apply",
                        style: AppFonts.poppins(
                          size: 15,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // View Available Offers Link
        GestureDetector(
          onTap: _showAvailableOffersModal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/bookings/fi_1076745_1_1768.svg',
                width: 15,
                height: 15,
                colorFilter: const ColorFilter.mode(Color(0xFF374151), BlendMode.srcIn),
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.card_giftcard_outlined, size: 15, color: Color(0xFF374151)),
              ),
              const SizedBox(width: 6),
              Text(
                "View available offers",
                style: AppFonts.poppins(
                  size: 13,
                  weight: FontWeight.w500,
                  color: const Color(0xFF374151),
                ).copyWith(decoration: TextDecoration.underline),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const _DashedDivider(),
        const SizedBox(height: 16),

        // Applied Offer Banner
        if (isApplied) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
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
                    size: 22,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$appliedCode applied",
                        style: AppFonts.poppins(
                          size: 14,
                          weight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        offerDesc,
                        style: AppFonts.poppins(
                          size: 12.5,
                          weight: FontWeight.w400,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _removePromoCode,
                  child: Text(
                    "Remove",
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: const Color(0xFF166534),
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
          const SizedBox(height: 8),
        ],
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

