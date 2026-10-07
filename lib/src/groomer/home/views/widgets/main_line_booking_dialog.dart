import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class MainLineBookingDialog extends StatefulWidget {
  final GroomerUser? loggedInGroomer;
  final GroomerHomeBloc? bloc;
  final VoidCallback onBookingCreated;

  const MainLineBookingDialog({
    super.key,
    required this.loggedInGroomer,
    this.bloc,
    required this.onBookingCreated,
  });

  /// Opens the Main Line Call Booking panel as a smooth slide-up bottom sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    required GroomerUser? loggedInGroomer,
    required VoidCallback onBookingCreated,
    GroomerHomeBloc? bloc,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (modalContext) => MainLineBookingDialog(
        loggedInGroomer: loggedInGroomer,
        bloc: bloc,
        onBookingCreated: onBookingCreated,
      ),
    );
  }

  @override
  State<MainLineBookingDialog> createState() => _MainLineBookingDialogState();
}

class _MainLineBookingDialogState extends State<MainLineBookingDialog> {
  final Logger _log = Logger();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  late final GroomerHomeBloc _bloc;
  bool _ownsBloc = false;

  // Selected State in UI
  CustomerSummary? _selectedCustomer;
  CustomerPetSummary? _selectedPet;
  String _selectedGroomerId = 'any';
  SalonGroomer? _selectedGroomer;
  ServiceItem? _selectedService;
  ServiceItem? _selectedPackage;
  bool _isPackageMode = false;
  bool _isServiceDropdownOpen = false;
  final Set<int> _selectedAddOnIds = {};
  DateTime _selectedDate = DateTime.now();
  String? _selectedStartTime;
  String? _selectedEndTime;
  bool _isSubmitting = false;
  bool _hasHandledSuccess = false;

  @override
  void initState() {
    super.initState();
    if (widget.bloc != null) {
      _bloc = widget.bloc!;
      _ownsBloc = false;
    } else {
      _bloc = GroomerHomeBloc(repository: ServicesLocator.groomerHomeRepository);
      _ownsBloc = true;
    }

    // Initialize selections if bloc state is already populated
    if (_bloc.state.searchedCustomers.isNotEmpty) {
      _selectedCustomer = _bloc.state.searchedCustomers.first;
    }
    if (_bloc.state.customerPets.isNotEmpty) {
      _selectedPet = _bloc.state.customerPets.first;
    }
    if (_bloc.state.bookingServices.isNotEmpty) {
      _selectedService = _bloc.state.bookingServices.first;
      _isPackageMode = false;
    } else if (_bloc.state.bookingPackages.isNotEmpty) {
      _selectedPackage = _bloc.state.bookingPackages.first;
      _isPackageMode = true;
    }
    if (_bloc.state.availableTimeSlots.isNotEmpty) {
      final firstSlot = _bloc.state.availableTimeSlots.first;
      _selectedStartTime = firstSlot['startTime']?.toString();
      _selectedEndTime = firstSlot['endTime']?.toString();
    }

    // Reset dialog state & trigger pure dynamic BLoC fetches (ZERO dummy/mock data)
    _bloc.add(const GroomerHomeResetBookingDialogEvent());
    if (_bloc.state.searchedCustomers.isEmpty) {
      _bloc.add(const GroomerHomeSearchCustomersEvent());
    }
    if (_bloc.state.salonGroomers.isEmpty) {
      _bloc.add(const GroomerHomeGetSalonGroomersEvent());
    }
    if (_bloc.state.bookingServices.isEmpty && _bloc.state.bookingPackages.isEmpty) {
      _bloc.add(const GroomerHomeGetBookingServicesEvent());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!_bloc.isClosed) {
        _bloc.add(GroomerHomeSearchCustomersEvent(
          query: query.trim().isNotEmpty ? query.trim() : null,
        ));
      }
    });
  }

  void _onCustomerSelected(CustomerSummary customer) {
    setState(() {
      _selectedCustomer = customer;
      _selectedPet = null;
    });
    // Fetch pets strictly for the real customer userId from backend API
    if (!_bloc.isClosed) {
      _bloc.add(GroomerHomeGetCustomerPetsEvent(customer.id));
    }
  }

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      BookingDateUtils.isSameCalendarDay(a, b);

  String _formatSelectedDateDisplay() =>
      BookingDateUtils.formatBookingDateDisplay(_selectedDate);

  String _fmt12(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h < 12 ? 'AM' : 'PM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }

  String _formatCurrency(num? amount) {
    if (amount == null || amount <= 0) return '\$0';
    if (amount == amount.roundToDouble()) {
      return '\$${amount.toInt()}';
    }
    return '\$${amount.toStringAsFixed(2)}';
  }

  Widget _buildLegendItem(Color bg, Color fg, String label, {Color? borderColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor ?? const Color(0xFFE5E7EB)),
          ),
          child: Text(
            '–',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppFonts.poppins(size: 10.5, color: const Color(0xFF6B7280)),
        ),
      ],
    );
  }

  void _triggerAvailabilityCheck() {
    if (_bloc.isClosed) return;
    if (_selectedService == null && _selectedPackage == null) return;

    // Immediately clear stale slot selection in local state
    if (_selectedStartTime != null || _selectedEndTime != null) {
      setState(() {
        _selectedStartTime = null;
        _selectedEndTime = null;
      });
    }

    final requestedGroomerId =
        (_selectedGroomerId != 'any' && _selectedGroomer != null && _selectedGroomer!.id > 0)
            ? _selectedGroomer!.id
            : null;
    final serviceId = _selectedService?.id;
    final packageId = _selectedPackage?.id;
    final addOnIds = _selectedAddOnIds.isNotEmpty ? _selectedAddOnIds.toList() : null;

    _bloc.add(GroomerHomeCheckAvailabilityEvent(
      date: _selectedDate,
      groomerId: requestedGroomerId,
      serviceId: serviceId,
      packageId: packageId,
      addOnIds: addOnIds,
    ));
  }

  void _handleConfirmAndCreate() {
    if (_isSubmitting || _hasHandledSuccess || _bloc.state.isCreatingBookingForUser) {
      _log.w('MainLineBookingDialog::_handleConfirmAndCreate::Submission ignored because booking is already submitting or completed.');
      return;
    }

    if (_selectedCustomer == null) {
      ToastUtil.showErrorToast(context, 'Please select a registered customer.');
      return;
    }

    if (_selectedPet == null) {
      ToastUtil.showErrorToast(context, 'Please select a registered pet for this customer.');
      return;
    }

    if (_selectedService == null && _selectedPackage == null) {
      ToastUtil.showErrorToast(context, 'Please select a service or package.');
      return;
    }

    if (_bloc.state.isCheckingAvailability) {
      ToastUtil.showErrorToast(context, 'Please wait for slot availability check to complete.');
      return;
    }

    if (_selectedStartTime == null ||
        !_bloc.state.isSlotAvailable ||
        _bloc.state.availableTimeSlots.isEmpty) {
      final groomerName = _selectedGroomer != null ? _selectedGroomer!.name : 'Selected groomer';
      ToastUtil.showErrorToast(
        context,
        '$groomerName is unavailable at the selected time. Please choose another slot.',
      );
      return;
    }

    // Verify selected slot still belongs to latest real availability response
    final latestSlot = _bloc.state.availableTimeSlots.firstWhere(
      (s) => s['startTime']?.toString() == _selectedStartTime,
      orElse: () => <String, dynamic>{},
    );

    if (latestSlot.isEmpty ||
        latestSlot['isAvailable'] == false ||
        (latestSlot['remaining'] != null &&
            latestSlot['remaining'] is num &&
            (latestSlot['remaining'] as num) <= 0)) {
      ToastUtil.showErrorToast(
        context,
        'The selected time slot is no longer available. Please choose another slot.',
      );
      return;
    }

    final realUserId = _selectedCustomer!.id;
    final realPetId = _selectedPet!.id;
    final serviceId = _selectedService?.id ?? _selectedPackage?.id ?? 1;
    final packageId = _selectedPackage?.id;
    final addOnIds = _selectedAddOnIds.isNotEmpty ? _selectedAddOnIds.toList() : null;

    // Resolve requested groomer ID (or from slot if Any Groomer)
    int requestedGroomerId = 0;
    if (_selectedGroomerId != 'any' && _selectedGroomer != null && _selectedGroomer!.id > 0) {
      requestedGroomerId = _selectedGroomer!.id;
    } else {
      final rawGId = latestSlot['groomerId'] ?? latestSlot['groomer_id'];
      if (rawGId is int && rawGId > 0) {
        requestedGroomerId = rawGId;
      } else if (rawGId != null) {
        requestedGroomerId = int.tryParse(rawGId.toString()) ?? 0;
      }
    }

    final bookingDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final startTime = _selectedStartTime!;
    final endTime = _selectedEndTime ?? (latestSlot['endTime']?.toString() ?? startTime);

    setState(() {
      _isSubmitting = true;
    });

    _log.d(
      'MainLineBookingDialog::_handleConfirmAndCreate::Dispatching booking event for User $realUserId, Pet $realPetId, Requested Groomer $requestedGroomerId (${_selectedGroomer?.name ?? "Any Groomer"}) for $bookingDate $startTime - $endTime',
    );

    _bloc.add(GroomerHomeCreateBookingForUserEvent(
      userId: realUserId,
      petId: realPetId,
      serviceId: serviceId,
      packageId: packageId,
      addOnIds: addOnIds,
      groomerId: requestedGroomerId,
      bookingDate: bookingDate,
      startTime: startTime,
      endTime: endTime,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loggedInName = widget.loggedInGroomer?.firstName.isNotEmpty == true
        ? widget.loggedInGroomer!.firstName
        : 'Staff';

    return BlocConsumer<GroomerHomeBloc, GroomerHomeState>(
      bloc: _bloc,
      listener: (context, state) {
        // Auto-select first customer when real backend customers arrive
        if (_selectedCustomer == null && state.searchedCustomers.isNotEmpty) {
          _onCustomerSelected(state.searchedCustomers.first);
        } else if (_selectedCustomer != null &&
            !state.searchedCustomers.any((c) => c.id == _selectedCustomer!.id)) {
          if (state.searchedCustomers.isNotEmpty) {
            _onCustomerSelected(state.searchedCustomers.first);
          } else {
            setState(() {
              _selectedCustomer = null;
              _selectedPet = null;
            });
          }
        }

        // Auto-select first pet when real backend pets arrive
        if (_selectedPet == null && state.customerPets.isNotEmpty) {
          setState(() {
            _selectedPet = state.customerPets.first;
          });
        }

        // If a specific groomer was selected but is no longer in the list, fallback to "Any Groomer"
        if (_selectedGroomerId != 'any' &&
            _selectedGroomer != null &&
            state.salonGroomers.isNotEmpty &&
            !state.salonGroomers.any((g) => g.id == _selectedGroomer!.id)) {
          setState(() {
            _selectedGroomerId = 'any';
            _selectedGroomer = null;
          });
          _triggerAvailabilityCheck();
        }

        // Auto-select first service/package when real backend services arrive
        if (_selectedService == null && _selectedPackage == null) {
          if (state.bookingServices.isNotEmpty) {
            setState(() {
              _selectedService = state.bookingServices.first;
              _isPackageMode = false;
            });
            _triggerAvailabilityCheck();
          } else if (state.bookingPackages.isNotEmpty) {
            setState(() {
              _selectedPackage = state.bookingPackages.first;
              _isPackageMode = true;
            });
            _triggerAvailabilityCheck();
          }
        }

        // Update time slot selection when availability slots update
        if (state.availableTimeSlots.isNotEmpty) {
          final isToday = _isSameDay(_selectedDate, DateTime.now());
          final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
          const kBuffer = 5;

          final validSlots = state.availableTimeSlots.where((s) {
            final st = s['startTime']?.toString() ?? '';
            final isPast = isToday && _toMinutes(st) <= nowMinutes + kBuffer;
            final isAvail = s['isAvailable'] != false &&
                (s['remaining'] == null || (s['remaining'] is num && s['remaining'] > 0));
            return isAvail && !isPast;
          }).toList();

          if (validSlots.isNotEmpty) {
            final match = validSlots.firstWhere(
              (s) => s['startTime'] == _selectedStartTime,
              orElse: () => validSlots.first,
            );
            final start = match['startTime']?.toString();
            final end = match['endTime']?.toString();
            if (_selectedStartTime != start || _selectedEndTime != end) {
              setState(() {
                _selectedStartTime = start;
                _selectedEndTime = end;
              });
            }
          } else {
            if (_selectedStartTime != null || _selectedEndTime != null) {
              setState(() {
                _selectedStartTime = null;
                _selectedEndTime = null;
              });
            }
          }
        } else {
          if (_selectedStartTime != null || _selectedEndTime != null) {
            setState(() {
              _selectedStartTime = null;
              _selectedEndTime = null;
            });
          }
        }

        // Success handling for booking creation (guaranteed single trigger)
        if (state.bookingForUserSuccess && !_hasHandledSuccess) {
          _hasHandledSuccess = true;
          final bookingId = state.lastCreatedBookingId;
          final idText = bookingId != null && bookingId > 0 ? ' #$bookingId' : '';
          final assignedGroomerName = _selectedGroomerId != 'any' && _selectedGroomer != null
              ? _selectedGroomer!.name
              : 'Assigned Groomer';

          widget.onBookingCreated();
          ToastUtil.showSuccessToast(
            context,
            'Appointment$idText successfully created & confirmed for ${_selectedCustomer?.name ?? "Customer"} (Assigned to $assignedGroomerName)!',
          );
          _bloc.add(const GroomerHomeResetBookingDialogEvent());
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } else if (state.bookingForUserError != null) {
          if (_isSubmitting) {
            setState(() {
              _isSubmitting = false;
            });
          }
          ToastUtil.showErrorToast(context, state.bookingForUserError!);
        }
      },
      builder: (context, state) {
        final customers = state.searchedCustomers;
        final pets = state.customerPets;
        final groomers = state.salonGroomers;
        final services = state.bookingServices;
        final packages = state.bookingPackages;
        final addOns = state.bookingAddOns;
        final slots = state.availableTimeSlots;

        final baseItem = _isPackageMode ? _selectedPackage : _selectedService;
        final double basePrice = baseItem?.price ?? 0.0;
        final int baseDuration = baseItem?.durationMinutes ?? 0;

        final selectedAddOnsList = addOns.where((ao) => _selectedAddOnIds.contains(ao.id)).toList();
        final double addOnsTotal = selectedAddOnsList.fold(0.0, (sum, ao) => sum + ao.price);
        final int addOnsDuration = selectedAddOnsList.fold(0, (sum, ao) => sum + (ao.durationMinutes > 0 ? ao.durationMinutes : 0));
        final int calculatedTotalDuration = (state.slotDurationMinutes != null && state.slotDurationMinutes! > 0)
            ? state.slotDurationMinutes!
            : (baseDuration + addOnsDuration);
        final double calculatedTotalAmount = (basePrice + addOnsTotal > 0)
            ? (basePrice + addOnsTotal)
            : (state.slotTotalPrice ?? 0.0);

        final bool hasValidGroomer = _selectedGroomerId == 'any' || _selectedGroomer != null;
        final bool isSlotValid = _selectedStartTime != null &&
            !state.isCheckingAvailability &&
            state.availableTimeSlots.any((s) =>
                s['startTime']?.toString() == _selectedStartTime &&
                s['isAvailable'] != false &&
                (s['remaining'] == null || (s['remaining'] is num && s['remaining'] > 0)));

        final bool isFormValid = state.isSlotAvailable &&
            _selectedCustomer != null &&
            _selectedPet != null &&
            hasValidGroomer &&
            (_selectedService != null || _selectedPackage != null) &&
            isSlotValid;

        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final screenHeight = MediaQuery.of(context).size.height;
        final availableHeight = (screenHeight - bottomInset).clamp(320.0, screenHeight);
        final targetHeight = math.min(screenHeight * 0.90, availableHeight);

        return Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedPadding(
            padding: EdgeInsets.only(bottom: bottomInset),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: targetHeight,
                  maxWidth: 640,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 0. Top Drag Handle Bar ───────────────────────────
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 6),
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),

                      // ── 1. Top Fixed Header ───────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF111827).withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.phone_in_talk_rounded,
                                      size: 20,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Main-Line Call Booking',
                                      style: AppFonts.parkinsans(
                                        size: 17,
                                        weight: FontWeight.w700,
                                        color: const Color(0xFF111827),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),

                      // ── 2. Scrollable Form Content ─────────────────────────
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                        // ── Context Badge Banner ────────────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.headset_mic_outlined,
                                size: 18,
                                color: Color(0xFF374151),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Call attended by: $loggedInName (Logged In Staff)\nBook on customer\'s behalf & assign requested groomer.',
                                  style: AppFonts.poppins(
                                    size: 11.5,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ── Section 1: Customer Selection (REAL API) ────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSectionTitle('1. Calling Customer'),
                            ),
                            if (state.isSearchingCustomers)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Search Box
                        TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: AppFonts.poppins(size: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by name, phone, or email...',
                            hintStyle: AppFonts.poppins(size: 12.5, color: const Color(0xFF9CA3AF)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF6B7280)),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFF6B7280)),
                                    onPressed: () {
                                      _searchController.clear();
                                      _bloc.add(const GroomerHomeSearchCustomersEvent());
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Customer Dropdown Picker (Driven by real backend data)
                        if (customers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD1D5DB)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<CustomerSummary>(
                                isExpanded: true,
                                value: (_selectedCustomer != null &&
                                        customers.any((c) => c.id == _selectedCustomer!.id))
                                    ? customers.firstWhere((c) => c.id == _selectedCustomer!.id)
                                    : customers.first,
                                items: customers.map((c) {
                                  final phoneStr =
                                      c.phone != null && c.phone!.isNotEmpty ? ' (${c.phone})' : '';
                                  return DropdownMenuItem<CustomerSummary>(
                                    value: c,
                                    child: Text(
                                      '${c.name}$phoneStr',
                                      style: AppFonts.poppins(size: 13, weight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    _onCustomerSelected(val);
                                  }
                                },
                              ),
                            ),
                          )
                        else if (state.isSearchingCustomers)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Searching registered customers...',
                                  style: AppFonts.poppins(size: 11.5, color: const Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          )
                        else if (state.customerError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.customerError!,
                                    style: AppFonts.poppins(size: 11.5, color: const Color(0xFF991B1B)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFDC2626)),
                                  onPressed: () => _bloc.add(GroomerHomeSearchCustomersEvent(
                                    query: _searchController.text.trim().isNotEmpty
                                        ? _searchController.text.trim()
                                        : null,
                                  )),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_off, size: 18, color: Color(0xFF6B7280)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _searchController.text.trim().isNotEmpty
                                        ? 'No registered customers found matching "${_searchController.text.trim()}"'
                                        : 'No registered customers found in this shop.',
                                    style: AppFonts.poppins(size: 11.5, color: const Color(0xFF6B7280)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // ── Section 2: Customer Pets (REAL API) ────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSectionTitle('2. Customer Pet'),
                            ),
                            if (state.isLoadingCustomerPets)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (pets.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: pets.map((p) {
                              final isSelected = _selectedPet?.id == p.id;
                              final hasBreed = p.breed.isNotEmpty && p.breed.toLowerCase() != 'null';
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() => _selectedPet = p),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF111827).withValues(alpha: 0.15),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white.withValues(alpha: 0.2)
                                                : const Color(0xFF111827).withValues(alpha: 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.pets_rounded,
                                            size: 14,
                                            color: isSelected ? Colors.white : const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          p.name,
                                          style: AppFonts.poppins(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: isSelected ? Colors.white : const Color(0xFF111827),
                                          ),
                                        ),
                                        if (hasBreed) ...[
                                          const SizedBox(width: 5),
                                          Text(
                                            '(${p.breed})',
                                            style: AppFonts.poppins(
                                              size: 11.5,
                                              weight: FontWeight.w400,
                                              color: isSelected
                                                  ? Colors.white.withValues(alpha: 0.85)
                                                  : const Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                        if (isSelected) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: state.petError != null
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: state.petError != null
                                    ? const Color(0xFFFECACA)
                                    : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  state.petError != null ? Icons.error_outline : Icons.pets,
                                  size: 18,
                                  color: state.petError != null
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFD97706),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.petError ??
                                        (_selectedCustomer != null
                                            ? 'Unable to load pets. Please try again.'
                                            : 'Please select a registered customer above to view pets.'),
                                    style: AppFonts.poppins(
                                      size: 11.5,
                                      color: state.petError != null
                                          ? const Color(0xFF991B1B)
                                          : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                                if (_selectedCustomer != null)
                                  IconButton(
                                    icon: Icon(
                                      Icons.refresh,
                                      size: 18,
                                      color: state.petError != null
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFD97706),
                                    ),
                                    onPressed: () {
                                      final userId = _selectedCustomer?.id;
                                      if (userId != null) {
                                        _bloc.add(GroomerHomeGetCustomerPetsEvent(userId));
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 18),

                        // ── Section 3: Requested Groomer (REAL API GET /api/groomers) ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSectionTitle('3. Requested Groomer (Customer Preference)'),
                            ),
                            if (state.isLoadingSalonGroomers)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select the groomer requested by the customer or choose Any Groomer:',
                          style: AppFonts.poppins(size: 11.5, color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 10),
                        if (state.isLoadingSalonGroomers && groomers.isEmpty)
                          const SizedBox(
                            height: 80,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        else if (state.salonGroomersError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.salonGroomersError!,
                                    style: AppFonts.poppins(size: 11.5, color: const Color(0xFF991B1B)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFDC2626)),
                                  onPressed: () => _bloc.add(const GroomerHomeGetSalonGroomersEvent()),
                                ),
                              ],
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                // 1. "Any Groomer" option (identical to Customer Booking flow)
                                () {
                                  final isSelected = _selectedGroomerId == 'any';
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedGroomerId = 'any';
                                          _selectedGroomer = null;
                                        });
                                        _triggerAvailabilityCheck();
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                width: 64,
                                                height: 64,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: isSelected ? const Color(0xFF0F766E) : Colors.black,
                                                  shape: BoxShape.circle,
                                                  border: isSelected
                                                      ? Border.all(
                                                          color: const Color(0xFF0F766E),
                                                          width: 2.5,
                                                        )
                                                      : null,
                                                ),
                                                child: Text(
                                                  'ANY',
                                                  style: AppFonts.poppins(
                                                    size: 13,
                                                    weight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Positioned(
                                                  right: -2,
                                                  bottom: -2,
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF16A34A),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.check,
                                                      size: 13,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                            width: 64,
                                            child: Text(
                                              'Any Groomer',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: AppFonts.poppins(
                                                size: 11,
                                                weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF111827),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }(),

                                // 2. Real groomers from API response
                                ...groomers.map((g) {
                                  final chipId = g.id.toString();
                                  final isSelected = _selectedGroomerId == chipId;
                                  final isAvailable = g.isAvailable;
                                  final initial = g.name.isNotEmpty
                                      ? (g.firstName.isNotEmpty ? g.firstName[0].toUpperCase() : g.name[0].toUpperCase())
                                      : 'G';
                                  final rawPic = g.profilePicture;
                                  String? imgUrl;
                                  if (rawPic != null && rawPic.isNotEmpty) {
                                    if (rawPic.startsWith('http://') || rawPic.startsWith('https://')) {
                                      imgUrl = rawPic;
                                    } else {
                                      final clean = rawPic.startsWith('/') ? rawPic.substring(1) : rawPic;
                                      imgUrl = '${Constants.app.BASE_URL}/$clean';
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: GestureDetector(
                                      onTap: isAvailable
                                          ? () {
                                              setState(() {
                                                _selectedGroomerId = chipId;
                                                _selectedGroomer = g;
                                              });
                                              _triggerAvailabilityCheck();
                                            }
                                          : null,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Opacity(
                                                opacity: isAvailable ? 1.0 : 0.35,
                                                child: Container(
                                                  width: 64,
                                                  height: 64,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? const Color(0xFF0F766E) : Colors.black,
                                                    shape: BoxShape.circle,
                                                    border: isSelected
                                                        ? Border.all(
                                                            color: const Color(0xFF0F766E),
                                                            width: 2.5,
                                                          )
                                                        : null,
                                                  ),
                                                  child: imgUrl != null
                                                      ? ClipOval(
                                                          child: Image.network(
                                                            imgUrl,
                                                            width: 64,
                                                            height: 64,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) => Center(
                                                              child: Text(
                                                                initial,
                                                                style: AppFonts.poppins(
                                                                  size: 22,
                                                                  weight: FontWeight.w600,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      : Text(
                                                          initial,
                                                          style: AppFonts.poppins(
                                                            size: 22,
                                                            weight: FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Positioned(
                                                  right: -2,
                                                  bottom: -2,
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF16A34A),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.check,
                                                      size: 13,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              if (!isAvailable)
                                                Positioned(
                                                  right: -2,
                                                  bottom: -2,
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFE23232),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      size: 13,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                            width: 64,
                                            child: Text(
                                              g.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: AppFonts.poppins(
                                                size: 11,
                                                weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF111827),
                                              ),
                                            ),
                                          ),
                                          if (!isAvailable) ...[
                                            const SizedBox(height: 2),
                                            SizedBox(
                                              width: 68,
                                              child: Text(
                                                g.reason ?? 'Unavailable',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: AppFonts.poppins(
                                                  size: 9,
                                                  weight: FontWeight.w400,
                                                  color: const Color(0xFFE23232),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        const SizedBox(height: 18),

                        // ── Section 4: Services / Packages / Add-ons (REAL API) ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSectionTitle('4. Service / Package & Add-ons'),
                            ),
                            if (state.isLoadingBookingServices)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose an individual service or curated package:',
                          style: AppFonts.poppins(size: 11.5, color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 8),
                        if (services.isNotEmpty || packages.isNotEmpty) ...[
                          Builder(
                            builder: (context) {
                              final selectedItem = _isPackageMode ? _selectedPackage : _selectedService;
                              final selectedTitle = selectedItem?.name ??
                                  (_isPackageMode ? 'Select a package' : 'Select a service');
                              final selectedDur = selectedItem != null && selectedItem.durationMinutes > 0
                                  ? ' (${selectedItem.durationMinutes} min)'
                                  : '';
                              final selectedPrice = selectedItem != null
                                  ? '\$${selectedItem.price.toStringAsFixed(0)}'
                                  : '';

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _isServiceDropdownOpen
                                        ? const Color(0xFF111827)
                                        : const Color(0xFFD1D5DB),
                                    width: _isServiceDropdownOpen ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Collapsed Header / Trigger
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isServiceDropdownOpen = !_isServiceDropdownOpen;
                                        });
                                      },
                                      borderRadius: _isServiceDropdownOpen
                                          ? const BorderRadius.vertical(top: Radius.circular(13))
                                          : BorderRadius.circular(13),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _isPackageMode ? Icons.card_giftcard_rounded : Icons.spa_outlined,
                                              size: 18,
                                              color: selectedItem != null
                                                  ? (_isPackageMode ? const Color(0xFF7C3AED) : const Color(0xFF0F766E))
                                                  : const Color(0xFF9CA3AF),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '$selectedTitle$selectedDur',
                                                style: AppFonts.poppins(
                                                  size: 13,
                                                  weight: selectedItem != null ? FontWeight.w600 : FontWeight.w400,
                                                  color: selectedItem != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            if (selectedPrice.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF3F4F6),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  selectedPrice,
                                                  style: AppFonts.poppins(
                                                    size: 12,
                                                    weight: FontWeight.w700,
                                                    color: _isPackageMode ? const Color(0xFF7C3AED) : const Color(0xFF0F766E),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 6),
                                            AnimatedRotation(
                                              turns: _isServiceDropdownOpen ? 0.5 : 0.0,
                                              duration: const Duration(milliseconds: 200),
                                              child: const Icon(
                                                Icons.keyboard_arrow_down_rounded,
                                                size: 20,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Inline Expandable Content
                                    if (_isServiceDropdownOpen) ...[
                                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                                      // Segment Switcher inside panel if both services and packages exist
                                      if (services.isNotEmpty && packages.isNotEmpty) ...[
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _isPackageMode = false;
                                                        if (_selectedService == null && services.isNotEmpty) {
                                                          _selectedService = services.first;
                                                          _selectedPackage = null;
                                                          _triggerAvailabilityCheck();
                                                        } else if (_selectedPackage != null) {
                                                          _selectedService = services.isNotEmpty ? services.first : null;
                                                          _selectedPackage = null;
                                                          _triggerAvailabilityCheck();
                                                        }
                                                      });
                                                    },
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 150),
                                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: !_isPackageMode ? const Color(0xFF111827) : Colors.transparent,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          'Services (${services.length})',
                                                          style: AppFonts.poppins(
                                                            size: 11.5,
                                                            weight: !_isPackageMode ? FontWeight.w600 : FontWeight.w500,
                                                            color: !_isPackageMode ? Colors.white : const Color(0xFF6B7280),
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _isPackageMode = true;
                                                        if (_selectedPackage == null && packages.isNotEmpty) {
                                                          _selectedPackage = packages.first;
                                                          _selectedService = null;
                                                          _triggerAvailabilityCheck();
                                                        } else if (_selectedService != null) {
                                                          _selectedPackage = packages.isNotEmpty ? packages.first : null;
                                                          _selectedService = null;
                                                          _triggerAvailabilityCheck();
                                                        }
                                                      });
                                                    },
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 150),
                                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: _isPackageMode ? const Color(0xFF111827) : Colors.transparent,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          'Packages (${packages.length})',
                                                          style: AppFonts.poppins(
                                                            size: 11.5,
                                                            weight: _isPackageMode ? FontWeight.w600 : FontWeight.w500,
                                                            color: _isPackageMode ? Colors.white : const Color(0xFF6B7280),
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],

                                      // Scrollable item list
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 220),
                                        child: RawScrollbar(
                                          thumbVisibility: true,
                                          thumbColor: const Color(0xFFD1D5DB),
                                          radius: const Radius.circular(4),
                                          thickness: 4,
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            itemCount: _isPackageMode ? packages.length : services.length,
                                            separatorBuilder: (context, index) => const Divider(
                                              height: 1,
                                              indent: 42,
                                              endIndent: 12,
                                              color: Color(0xFFF3F4F6),
                                            ),
                                            itemBuilder: (context, index) {
                                              final item = _isPackageMode ? packages[index] : services[index];
                                              final isSelected = _isPackageMode
                                                  ? (_selectedPackage?.id == item.id)
                                                  : (_selectedService?.id == item.id);
                                              final durStr = item.durationMinutes > 0 ? '${item.durationMinutes} min' : '';

                                              return InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    if (_isPackageMode) {
                                                      _selectedPackage = item;
                                                      _selectedService = null;
                                                    } else {
                                                      _selectedService = item;
                                                      _selectedPackage = null;
                                                    }
                                                    _isServiceDropdownOpen = false;
                                                  });
                                                  _triggerAvailabilityCheck();
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                  color: isSelected ? const Color(0xFFF9FAFB) : Colors.transparent,
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isSelected
                                                            ? Icons.check_circle_rounded
                                                            : Icons.radio_button_unchecked_rounded,
                                                        size: 18,
                                                        color: isSelected
                                                            ? const Color(0xFF111827)
                                                            : const Color(0xFFD1D5DB),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              item.name,
                                                              style: AppFonts.poppins(
                                                                size: 12.5,
                                                                weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                                color: isSelected
                                                                    ? const Color(0xFF111827)
                                                                    : const Color(0xFF374151),
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                              maxLines: 1,
                                                            ),
                                                            if (durStr.isNotEmpty || item.description.isNotEmpty) ...[
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                [
                                                                  if (item.description.isNotEmpty) item.description,
                                                                  if (durStr.isNotEmpty) durStr,
                                                                ].join(' · '),
                                                                style: AppFonts.poppins(
                                                                  size: 11,
                                                                  color: const Color(0xFF6B7280),
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                                maxLines: 1,
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: isSelected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          '\$${item.price.toStringAsFixed(0)}',
                                                          style: AppFonts.poppins(
                                                            size: 12,
                                                            weight: FontWeight.w700,
                                                            color: isSelected
                                                                ? Colors.white
                                                                : (_isPackageMode ? const Color(0xFF7C3AED) : const Color(0xFF0F766E)),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),

                          // ── Optional Add-ons Section (Real API Driven) ──
                          if (addOns.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 15,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Optional Add-ons',
                                    style: AppFonts.poppins(
                                      size: 12.5,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                  if (_selectedAddOnIds.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${_selectedAddOnIds.length} selected • +${_formatCurrency(addOnsTotal)}',
                                            style: AppFonts.poppins(
                                              size: 11,
                                              weight: FontWeight.w600,
                                              color: const Color(0xFF0F766E),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedAddOnIds.clear();
                                        });
                                        _triggerAvailabilityCheck();
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Text(
                                          'Clear all',
                                          style: AppFonts.poppins(
                                            size: 11.5,
                                            weight: FontWeight.w600,
                                            color: const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else
                                    const Spacer(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: addOns.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final ao = addOns[index];
                                final isSelected = _selectedAddOnIds.contains(ao.id);
                                final safeName = ao.name.isNotEmpty ? ao.name : 'Add-on';
                                final hasDuration = ao.durationMinutes > 0;
                                final hasDesc = ao.description.trim().isNotEmpty;
                                final priceLabel = ao.price > 0 ? '+${_formatCurrency(ao.price)}' : 'Free';

                                return Semantics(
                                  button: true,
                                  checked: isSelected,
                                  label: '$safeName, ${hasDuration ? "${ao.durationMinutes} minutes, " : ""}$priceLabel',
                                  hint: isSelected ? 'Tap to deselect add-on' : 'Tap to select add-on',
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedAddOnIds.remove(ao.id);
                                        } else {
                                          _selectedAddOnIds.add(ao.id);
                                        }
                                      });
                                      _triggerAvailabilityCheck();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(minHeight: 48),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        curve: Curves.easeInOut,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFF0FDFA) : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
                                            width: isSelected ? 1.5 : 1.0,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Checkbox indicator
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              curve: Curves.easeInOut,
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                                                borderRadius: BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFD1D5DB),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: AnimatedScale(
                                                scale: isSelected ? 1.0 : 0.0,
                                                duration: const Duration(milliseconds: 140),
                                                curve: Curves.easeOutBack,
                                                child: const Icon(Icons.check, size: 14, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Name, Description & Duration
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          safeName,
                                                          style: AppFonts.poppins(
                                                            size: 12.5,
                                                            weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                            color: isSelected ? const Color(0xFF111827) : const Color(0xFF374151),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (hasDuration) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF3F4F6),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            '+${ao.durationMinutes} min',
                                                            style: AppFonts.poppins(
                                                              size: 10,
                                                              weight: FontWeight.w500,
                                                              color: const Color(0xFF6B7280),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (hasDesc) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      ao.description.trim(),
                                                      style: AppFonts.poppins(
                                                        size: 11,
                                                        color: const Color(0xFF6B7280),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Price tag
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                              decoration: BoxDecoration(
                                                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                priceLabel,
                                                style: AppFonts.poppins(
                                                  size: 11.5,
                                                  weight: FontWeight.w700,
                                                  color: isSelected ? Colors.white : const Color(0xFF0F766E),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ] else if (state.bookingServicesError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.bookingServicesError!,
                                    style: AppFonts.poppins(size: 11.5, color: const Color(0xFF991B1B)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFDC2626)),
                                  onPressed: () => _bloc.add(const GroomerHomeGetBookingServicesEvent()),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // ── Section 5: Date Selector (Dynamic) ──────────
                        _buildSectionTitle('5. Appointment Date'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                                label: Text(
                                  _formatSelectedDateDisplay(),
                                  style: AppFonts.poppins(size: 13, weight: FontWeight.w500),
                                ),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final today = DateTime(now.year, now.month, now.day);
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: today,
                                    lastDate: today.add(const Duration(days: 14)),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedDate = BookingDateUtils.normalize(picked);
                                    });
                                    _triggerAvailabilityCheck();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ── Section 6: Available Time Slots (REAL API POST /api/availability) ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: _buildSectionTitle(
                                      '6. Time Slot (${_selectedGroomerId != 'any' && _selectedGroomer != null ? _selectedGroomer!.name : 'Any Groomer'})',
                                    ),
                                  ),
                                  if (state.slotDurationMinutes != null && state.slotDurationMinutes! > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '${state.slotDurationMinutes}m${state.slotTotalPrice != null ? " · \$${state.slotTotalPrice!.toStringAsFixed(0)}" : ""}',
                                        style: AppFonts.poppins(
                                          size: 11,
                                          weight: FontWeight.w600,
                                          color: const Color(0xFF0F766E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (state.isCheckingAvailability)
                              const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF6B7280)),
                                tooltip: 'Re-check availability',
                                onPressed: _triggerAvailabilityCheck,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Booked slots info strip
                        if (state.bookedTimeSlots.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFAFAFAF),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Already booked: ${state.bookedTimeSlots.map((b) {
                                      final st = b['startTime']?.toString() ?? '';
                                      final et = b['endTime']?.toString() ?? '';
                                      return st.isNotEmpty && et.isNotEmpty
                                          ? '${_fmt12(st)} – ${_fmt12(et)}'
                                          : (st.isNotEmpty ? _fmt12(st) : '');
                                    }).where((s) => s.isNotEmpty).join('   ')}',
                                    style: AppFonts.poppins(
                                      size: 11,
                                      color: const Color(0xFF6B7280),
                                      weight: FontWeight.w400,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        if (state.isCheckingAvailability)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0F766E)),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Checking real-time slot availability...',
                                  textAlign: TextAlign.center,
                                  style: AppFonts.poppins(size: 12, color: const Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          )
                        else if (slots.isNotEmpty) ...[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isToday = _isSameDay(_selectedDate, DateTime.now());
                              final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
                              const kBuffer = 5;

                              // Responsive column count
                              final crossAxisCount = constraints.maxWidth > 420 ? 4 : 3;

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: slots.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  mainAxisExtent: 36,
                                ),
                                itemBuilder: (context, index) {
                                  final slot = slots[index];
                                  final start = slot['startTime']?.toString() ?? '';
                                  final end = slot['endTime']?.toString() ?? '';
                                  final isPast = isToday && _toMinutes(start) <= nowMinutes + kBuffer;

                                  final isSelected = _selectedStartTime == start;
                                  final isAvailable = slot['isAvailable'] != false;
                                  final remaining = slot['remaining'] is num
                                      ? (slot['remaining'] as num).toInt()
                                      : int.tryParse(slot['remaining']?.toString() ?? '1') ?? 1;
                                  final bookingCount = slot['bookingCount'] is num
                                      ? (slot['bookingCount'] as num).toInt()
                                      : int.tryParse(slot['bookingCount']?.toString() ?? '0') ?? 0;
                                  final maxBookings = slot['maxBookings'] is num
                                      ? (slot['maxBookings'] as num).toInt()
                                      : int.tryParse(slot['maxBookings']?.toString() ?? '1') ?? 1;

                                  final isAtCapacity = (maxBookings > 1 || (slot['multiBookingEnabled'] == true)) &&
                                      (bookingCount >= maxBookings || remaining <= 0);
                                  final isBooked = (!isAvailable || remaining <= 0 || isPast) && !isAtCapacity;
                                  final isSelectable = isAvailable && remaining > 0 && !isPast && !isAtCapacity;

                                  Color bg, fg, borderColor;
                                  if (isSelected) {
                                    bg = const Color(0xFF0F766E); // teal
                                    fg = Colors.white;
                                    borderColor = const Color(0xFF0F766E);
                                  } else if (isAtCapacity) {
                                    bg = const Color(0xFFFFF7ED); // amber light
                                    fg = const Color(0xFFB45309);
                                    borderColor = const Color(0xFFFED7AA);
                                  } else if (isBooked) {
                                    bg = const Color(0xFFF3F4F6); // light gray
                                    fg = const Color(0xFFAFAFAF);
                                    borderColor = const Color(0xFFE5E7EB);
                                  } else {
                                    // Available
                                    bg = const Color(0xFF111827); // charcoal
                                    fg = Colors.white;
                                    borderColor = const Color(0xFF111827);
                                  }

                                  return GestureDetector(
                                    onTap: isSelectable
                                        ? () {
                                            setState(() {
                                              _selectedStartTime = start;
                                              _selectedEndTime = end;
                                            });
                                          }
                                        : () {
                                            if (isPast) {
                                              ToastUtil.showErrorToast(
                                                context,
                                                'This time slot is in the past for today.',
                                              );
                                            } else if (isAtCapacity) {
                                              ToastUtil.showErrorToast(
                                                context,
                                                'This time slot is fully booked ($bookingCount/$maxBookings).',
                                              );
                                            } else {
                                              ToastUtil.showErrorToast(
                                                context,
                                                'This time slot is unavailable. Please select another slot.',
                                              );
                                            }
                                          },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: borderColor, width: 1.2),
                                      ),
                                      child: Text(
                                        _fmt12(start),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: fg,
                                          decoration: (isBooked || isPast) ? TextDecoration.lineThrough : null,
                                          decorationColor: fg,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Legend
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _buildLegendItem(const Color(0xFF111827), Colors.white, 'Available'),
                              _buildLegendItem(const Color(0xFF0F766E), Colors.white, 'Selected'),
                              _buildLegendItem(const Color(0xFFF3F4F6), const Color(0xFFAFAFAF), 'Booked / Unavailable'),
                              _buildLegendItem(
                                const Color(0xFFFFF7ED),
                                const Color(0xFFB45309),
                                'Full',
                                borderColor: const Color(0xFFFED7AA),
                              ),
                            ],
                          ),
                          if (state.availabilityMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: state.isSlotAvailable
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: state.isSlotAvailable
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    state.isSlotAvailable
                                        ? Icons.check_circle_outline
                                        : Icons.warning_amber_rounded,
                                    size: 15,
                                    color: state.isSlotAvailable
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      state.availabilityMessage!,
                                      style: AppFonts.poppins(
                                        size: 11.5,
                                        color: state.isSlotAvailable
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFDC2626),
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_busy, size: 20, color: Color(0xFFD97706)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.availabilityMessage ??
                                        (_selectedGroomerId == 'any'
                                            ? 'No available time slots on this date. Please select another date.'
                                            : 'No available slots for ${_selectedGroomer?.name ?? "this groomer"} on this date.'),
                                    style: AppFonts.poppins(size: 11.5, color: const Color(0xFF92400E)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFD97706)),
                                  tooltip: 'Re-check availability',
                                  onPressed: _triggerAvailabilityCheck,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),

                        // ── Booking Summary Box ─────────────────────────
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              _buildSummaryRow(
                                'Customer',
                                _selectedCustomer != null
                                    ? _selectedCustomer!.name
                                    : 'Not selected',
                              ),
                              const SizedBox(height: 6),
                              _buildSummaryRow(
                                'Pet',
                                _selectedPet != null
                                    ? '${_selectedPet!.name} (${_selectedPet!.breed})'
                                    : 'Not selected',
                              ),
                              const SizedBox(height: 6),
                              _buildSummaryRow(
                                'Requested Groomer',
                                _selectedGroomerId == 'any'
                                    ? 'Any Groomer (No Preference)'
                                    : (_selectedGroomer != null ? _selectedGroomer!.name : 'Not selected'),
                                isHighlight: true,
                              ),
                              const SizedBox(height: 6),
                              _buildSummaryRow(
                                _selectedPackage != null ? 'Package' : 'Service',
                                baseItem != null
                                    ? '${baseItem.name} (${_formatCurrency(basePrice)})'
                                    : 'Not selected',
                              ),
                              const SizedBox(height: 6),
                              _buildSummaryRow(
                                'Optional Add-ons',
                                selectedAddOnsList.isNotEmpty
                                    ? '${selectedAddOnsList.map((a) => a.name).join(', ')} (+${_formatCurrency(addOnsTotal)})'
                                    : 'None (Optional • \$0)',
                              ),
                              const SizedBox(height: 6),
                              _buildSummaryRow(
                                'Schedule',
                                _selectedStartTime != null
                                    ? '${_formatSelectedDateDisplay()}, ${_fmt12(_selectedStartTime!)}${_selectedEndTime != null && _selectedEndTime!.isNotEmpty ? " – ${_fmt12(_selectedEndTime!)}" : ""}${calculatedTotalDuration > 0 ? " ($calculatedTotalDuration min)" : ""}'
                                    : 'No slot selected',
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFE5E7EB)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Total Booking Amount',
                                      style: AppFonts.poppins(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        color: const Color(0xFF111827),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatCurrency(calculatedTotalAmount),
                                    style: AppFonts.poppins(
                                      size: 15,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFF0F766E),
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
                ),

                      const Divider(height: 1, color: Color(0xFFE5E7EB)),

                      // ── 3. Fixed Bottom Action Buttons ─────────────────────
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    foregroundColor: const Color(0xFF6B7280),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'Cancel',
                                    style: AppFonts.poppins(size: 14, weight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFormValid
                                        ? const Color(0xFF111827)
                                        : const Color(0xFFD1D5DB),
                                    foregroundColor: isFormValid
                                        ? Colors.white
                                        : const Color(0xFF6B7280),
                                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                                    disabledForegroundColor: const Color(0xFF6B7280),
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: (_isSubmitting || _hasHandledSuccess || state.isCreatingBookingForUser || !isFormValid)
                                      ? null
                                      : _handleConfirmAndCreate,
                                  child: (_isSubmitting || state.isCreatingBookingForUser)
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _selectedGroomerId != 'any' && _selectedGroomer != null
                                              ? 'Assign to ${_selectedGroomer!.firstName.isNotEmpty ? _selectedGroomer!.firstName : _selectedGroomer!.name.split(' ').first}${calculatedTotalAmount > 0 ? " • ${_formatCurrency(calculatedTotalAmount)}" : ""}'
                                              : 'Confirm Appointment${calculatedTotalAmount > 0 ? " • ${_formatCurrency(calculatedTotalAmount)}" : ""}',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: AppFonts.poppins(
                                            size: 13.5,
                                            weight: FontWeight.w600,
                                            color: isFormValid ? Colors.white : const Color(0xFF6B7280),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppFonts.poppins(
        size: 13.5,
        weight: FontWeight.w700,
        color: const Color(0xFF111827),
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.poppins(
            size: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: AppFonts.poppins(
              size: 12.5,
              weight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              color: isHighlight ? const Color(0xFF0F766E) : const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}
