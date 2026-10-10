import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design constants — project theme
// ─────────────────────────────────────────────────────────────────────────────
const _kBlack = Color(0xFF111827);
const _kSubText = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kPageBg = Color(0xFFFAFAFA);
const _kCardBg = Color(0xFFFFFFFF);

// ─────────────────────────────────────────────────────────────────────────────
// Tab definition
// ─────────────────────────────────────────────────────────────────────────────
enum _BookingTab { upcoming, past, cancelled }

extension _BookingTabExt on _BookingTab {
  String get label {
    switch (this) {
      case _BookingTab.upcoming:
        return 'Upcoming';
      case _BookingTab.past:
        return 'Past';
      case _BookingTab.cancelled:
        return 'Cancelled';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MyBookingsPageMobile
// ─────────────────────────────────────────────────────────────────────────────
class MyBookingsPageMobile extends StatefulWidget {
  const MyBookingsPageMobile({super.key});

  @override
  State<MyBookingsPageMobile> createState() => _MyBookingsPageMobileState();
}

class _MyBookingsPageMobileState extends State<MyBookingsPageMobile> {
  final Logger _log = Logger();

  _BookingTab _activeTab = _BookingTab.upcoming;

  // Per-tab state
  final Map<_BookingTab, List<Map<String, dynamic>>> _bookings = {
    _BookingTab.upcoming: [],
    _BookingTab.past: [],
    _BookingTab.cancelled: [],
  };
  final Map<_BookingTab, bool> _loading = {
    _BookingTab.upcoming: false,
    _BookingTab.past: false,
    _BookingTab.cancelled: false,
  };
  final Map<_BookingTab, String?> _error = {
    _BookingTab.upcoming: null,
    _BookingTab.past: null,
    _BookingTab.cancelled: null,
  };
  final Map<_BookingTab, bool> _loaded = {
    _BookingTab.upcoming: false,
    _BookingTab.past: false,
    _BookingTab.cancelled: false,
  };

  // Track which bookingIds are currently being cancelled (shows spinner on card)
  final Set<int> _cancelling = {};
  StreamSubscription<AppNotification>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _loadTab(_BookingTab.upcoming);
    _initRealtimeNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<PetBloc>().add(const GetAllPets());
        } catch (_) {}
      }
    });
  }

  void _initRealtimeNotifications() {
    ServicesLocator.notificationRepository.connectRealtimeNotifications();
    _notificationSub?.cancel();
    _notificationSub = ServicesLocator
        .notificationRepository
        .realtimeNotificationStream
        .listen(_handleIncomingRealtimeNotification);
  }

  void _handleIncomingRealtimeNotification(AppNotification notif) {
    if (!mounted) return;
    final type = notif.type.toLowerCase();
    final isBooking =
        type.contains('booking') ||
        type.contains('appointment') ||
        type.contains('cancellation') ||
        (notif.metadata != null &&
            (notif.metadata!.containsKey('bookingId') ||
                notif.metadata!.containsKey('booking_id')));
    if (isBooking) {
      _loadTab(_activeTab, forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadTab(_BookingTab tab, {bool forceRefresh = false}) async {
    if (_loading[tab] == true) return;
    if (_loaded[tab] == true && !forceRefresh) return;

    setState(() {
      _loading[tab] = true;
      _error[tab] = null;
    });

    try {
      final repo = ServicesLocator.bookingRepository;
      List<Map<String, dynamic>> result;

      switch (tab) {
        case _BookingTab.upcoming:
          result = await repo.getUpcomingBookingsApi();
          _log.d('MyBookingsPage::_loadTab::upcoming ${result.length} items');
          break;
        case _BookingTab.past:
          result = await repo.getPastBookingsApi();
          _log.d('MyBookingsPage::_loadTab::past ${result.length} items');
          break;
        case _BookingTab.cancelled:
          result = await repo.getCancelledBookingsApi();
          _log.d('MyBookingsPage::_loadTab::cancelled ${result.length} items');
          break;
      }

      if (!mounted) return;

      // ── Post-process results ────────────────────────────────────────────
      List<Map<String, dynamic>> processed = result;

      if (tab == _BookingTab.upcoming) {
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);

        // 1. Filter out bookings whose appointment date is in the past.
        //    Appointments scheduled for today (even if earlier today) or future dates
        //    are kept so today's bookings are always visible.
        processed = processed.where((b) {
          final date = _bookingDateOf(b);
          final startTime = _startTimeOf(b);
          if (date.isEmpty) return true; // keep if unknown

          final dt = _parseBookingDateTime(date, startTime);
          if (dt == null) return true;

          final appointmentDate = DateTime(dt.year, dt.month, dt.day);
          // Keep if appointment date is today or in the future
          if (appointmentDate.isAtSameMomentAs(startOfToday) ||
              appointmentDate.isAfter(startOfToday)) {
            return true;
          }

          // Also keep if status is pending, confirmed, or in_progress
          final status = (b['status']?.toString() ?? '').toUpperCase();
          return status == 'PENDING' ||
              status == 'CONFIRMED' ||
              status == 'IN_PROGRESS' ||
              status == 'ACCEPTED';
        }).toList();

        // 2. Sort ascending — soonest upcoming (today first) appointment shown at top
        processed.sort((a, b) {
          final da = _parseBookingDateTime(_bookingDateOf(a), _startTimeOf(a));
          final db = _parseBookingDateTime(_bookingDateOf(b), _startTimeOf(b));
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db); // ascending — soonest first
        });
      } else {
        // Past & cancelled — most recent (latest date) first
        processed.sort((a, b) {
          final da = _parseBookingDateTime(_bookingDateOf(a), _startTimeOf(a));
          final db = _parseBookingDateTime(_bookingDateOf(b), _startTimeOf(b));
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da); // descending — most recent first
        });
      }

      setState(() {
        _bookings[tab] = processed;
        _loading[tab] = false;
        _loaded[tab] = true;
        _error[tab] = null;
      });
    } catch (e) {
      _log.e('MyBookingsPage::_loadTab::$tab::Error: $e');
      if (!mounted) return;
      setState(() {
        _loading[tab] = false;
        _error[tab] = 'Unable to load bookings. Please try again.';
      });
    }
  }

  // ── Helpers for date/time extraction (used in sort + filter) ─────────────

  static String _bookingDateOf(Map<String, dynamic> b) =>
      b['bookingDate']?.toString() ?? b['booking_date']?.toString() ?? '';

  static String _startTimeOf(Map<String, dynamic> b) =>
      b['startTime']?.toString() ?? b['start_time']?.toString() ?? '';

  static DateTime? _parseBookingDateTime(String dateStr, String timeStr) {
    if (dateStr.isEmpty) return null;

    final parsedDate = BookingDateUtils.parseCalendarDate(dateStr);
    if (parsedDate == null) return null;

    if (timeStr.isNotEmpty) {
      final cleanTime = timeStr.trim().toUpperCase();
      // Case 1: 12-hour format "10:30 AM" or "02:00 PM"
      if (cleanTime.contains('AM') || cleanTime.contains('PM')) {
        try {
          final t = DateFormat('h:mm a').parse(cleanTime);
          return DateTime(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
            t.hour,
            t.minute,
          );
        } catch (_) {
          try {
            final t = DateFormat('hh:mm a').parse(cleanTime);
            return DateTime(
              parsedDate.year,
              parsedDate.month,
              parsedDate.day,
              t.hour,
              t.minute,
            );
          } catch (_) {}
        }
      }

      // Case 2: 24-hour format "14:30" or "14:30:00"
      final timeParts = cleanTime.split(':');
      if (timeParts.isNotEmpty) {
        final h = int.tryParse(timeParts[0]);
        final m = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;
        final s = timeParts.length > 2 ? int.tryParse(timeParts[2]) : 0;
        if (h != null && m != null) {
          return DateTime(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
            h,
            m,
            s ?? 0,
          );
        }
      }
    }

    return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _switchTab(_BookingTab tab) {
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);
    _loadTab(tab);
  }

  // ── Cancel booking ────────────────────────────────────────────────────────

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final rawId =
        booking['bookingId'] ?? booking['id'] ?? booking['booking_id'];
    final bookingId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '');
    if (bookingId == null || bookingId <= 0) return;

    final rawStatus = (booking['status']?.toString() ?? 'pending')
        .toUpperCase();
    final isPending = rawStatus == 'PENDING';

    // ── Status-aware confirm dialog ───────────────────────────────────────
    final String dialogTitle;
    final String dialogBody;
    final String confirmLabel;

    if (isPending) {
      dialogTitle = 'Cancel Booking';
      dialogBody =
          'This booking is awaiting groomer approval.\n'
          'Cancelling now will remove it immediately.';
      confirmLabel = 'Yes, Cancel';
    } else {
      // CONFIRMED — needs groomer approval
      dialogTitle = 'Request Cancellation';
      dialogBody =
          'This booking is confirmed by your groomer.\n'
          'A cancellation request will be sent to the groomer for approval.';
      confirmLabel = 'Send Request';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          dialogTitle,
          style: AppFonts.parkinsans(size: 18, weight: FontWeight.w600),
        ),
        content: Text(
          dialogBody,
          style: AppFonts.poppins(size: 14, color: _kSubText),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: _kSubText),
            child: Text(
              'Keep It',
              style: AppFonts.poppins(size: 14, weight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlack,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              confirmLabel,
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

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling.add(bookingId));

    try {
      final resp = await ServicesLocator.bookingRepository.cancelBookingApi(
        bookingId,
      );
      if (!mounted) return;

      if (resp != null && resp['success'] == true) {
        final apiMsg = resp['message']?.toString();
        final msg = (apiMsg != null && apiMsg.isNotEmpty)
            ? apiMsg
            : (isPending
                ? 'Booking cancelled successfully.'
                : 'Cancellation request sent. Awaiting groomer approval.');

        ToastUtil.showSuccessToast(context, msg);

        setState(() {
          // Remove from upcoming list locally
          _bookings[_BookingTab.upcoming]?.removeWhere(
            (b) => (b['bookingId'] ?? b['id']) == bookingId,
          );
          // Force reload other tabs on next open
          _loaded[_BookingTab.cancelled] = false;
        });
      } else {
        final msg =
            resp?['message']?.toString() ?? 'Could not process request.';
        ToastUtil.showErrorToast(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      ToastUtil.showErrorToast(context, 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _cancelling.remove(bookingId));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ServicesLocator.sessionService.isLoggedIn;
    if (!isLoggedIn) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.goNamed(RouteNames.home);
          }
        },
        child: Scaffold(
          backgroundColor: _kPageBg,
          appBar: AppBar(
            backgroundColor: _kCardBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.goNamed(RouteNames.home),
            ),
            centerTitle: false,
            title: Text(
              'My Bookings',
              style: AppFonts.parkinsans(size: 20, weight: FontWeight.w600),
            ),
          ),
          body: _buildGuestState(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed(RouteNames.home);
        }
      },
      child: Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kCardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.home),
        ),
        centerTitle: false,
        title: Text(
          'My Bookings',
          style: AppFonts.parkinsans(size: 20, weight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Tab selector ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 0),
              child: Container(
                height: 50,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _kBlack,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: _BookingTab.values.map((tab) {
                    final isActive = tab == _activeTab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _switchTab(tab),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isActive ? _kCardBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tab.label,
                            style: AppFonts.parkinsans(
                              size: 15.5,
                              weight: FontWeight.w600,
                              color: isActive ? _kBlack : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Count label ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _loadingCurrent
                      ? 'Loading…'
                      : '${_currentBookings.length} ${_activeTab.label.toLowerCase()} appointment${_currentBookings.length == 1 ? "" : "s"}',
                  style: AppFonts.poppins(
                    size: 14,
                    weight: FontWeight.w500,
                    color: _kSubText,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Content ───────────────────────────────────────────────────
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    ),
  );
}

  bool get _loadingCurrent => _loading[_activeTab] == true;
  List<Map<String, dynamic>> get _currentBookings =>
      _bookings[_activeTab] ?? [];
  String? get _currentError => _error[_activeTab];

  Widget _buildGuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                size: 46,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign In to View Bookings',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Keep track of your upcoming spa sessions, appointment history, and reschedule with ease.',
              style: AppFonts.poppins(
                size: 14,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(60),
                  ),
                ),
                onPressed: () => context.pushNamed(RouteNames.login),
                child: Text(
                  'Sign In / Register',
                  style: AppFonts.parkinsans(
                    size: 16,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loadingCurrent) {
      // ── Skeleton loading ────────────────────────────────────────────────
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(17, 0, 17, 130),
        child: Column(
          children: const [
            BookingCardSkeleton(),
            SizedBox(height: 16),
            BookingCardSkeleton(),
            SizedBox(height: 16),
            BookingCardSkeleton(),
          ],
        ),
      );
    }

    if (_currentError != null) {
      return _ErrorView(
        message: _currentError!,
        onRetry: () => _loadTab(_activeTab, forceRefresh: true),
      );
    }

    if (_currentBookings.isEmpty) {
      return _EmptyView(
        tab: _activeTab,
        onBook: () => context.goNamed(RouteNames.petSelect),
      );
    }

    List<Map<String, dynamic>> pets = const [];
    try {
      pets = context.watch<PetBloc>().state.pets;
    } catch (_) {}

    return RefreshIndicator(
      color: _kBlack,
      onRefresh: () => _loadTab(_activeTab, forceRefresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(17, 0, 17, 130),
        itemCount: _currentBookings.length,
        itemBuilder: (ctx, i) {
          final booking = _currentBookings[i];
          final rawId =
              booking['bookingId'] ?? booking['id'] ?? booking['booking_id'];
          final bookingId = rawId is int
              ? rawId
              : int.tryParse(rawId?.toString() ?? '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _BookingCard(
              booking: booking,
              tab: _activeTab,
              index: i,
              userPets: pets,
              cancelling: bookingId != null && _cancelling.contains(bookingId),
              onCancel: _activeTab == _BookingTab.upcoming
                  ? () => _cancelBooking(booking)
                  : null,
              onBookAgain: _activeTab != _BookingTab.upcoming
                  ? () => context.goNamed(RouteNames.petSelect)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking card
// ─────────────────────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final _BookingTab tab;
  final int index;
  final List<Map<String, dynamic>> userPets;
  final bool cancelling;
  final VoidCallback? onCancel;
  final VoidCallback? onBookAgain;

  const _BookingCard({
    required this.booking,
    required this.tab,
    this.index = 0,
    this.userPets = const [],
    required this.cancelling,
    this.onCancel,
    this.onBookAgain,
  });

  // ── field extraction — handles both flat and nested pet object ─────────────

  // Some API responses embed pet data under a 'pet' key:
  //   { bookingId, petId, pet: { petName, breed, profilePictureUrl }, ... }
  // Others return fields flat:
  //   { bookingId, petName, petBreed, petPhotoUrl, ... }
  Map<String, dynamic> get _petData {
    final nested = booking['pet'] ??
        booking['Pet'] ??
        booking['petData'] ??
        booking['pet_data'] ??
        booking['petProfile'] ??
        booking['pet_profile'] ??
        booking['PetProfile'] ??
        booking['petInfo'] ??
        booking['pet_info'] ??
        booking['PetInfo'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return booking;
  }

  int? get _petId {
    final d = _petData;
    final raw = d['id'] ??
        d['petId'] ??
        d['pet_id'] ??
        d['PetId'] ??
        booking['petId'] ??
        booking['pet_id'] ??
        booking['PetId'] ??
        booking['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String get _petName {
    final d = _petData;
    final name = d['petName']?.toString() ??
        d['pet_name']?.toString() ??
        d['name']?.toString() ??
        d['PetName']?.toString() ??
        booking['petName']?.toString() ??
        booking['pet_name']?.toString() ??
        booking['name']?.toString() ??
        booking['PetName']?.toString() ??
        '';
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && trimmed != 'null') return trimmed;

    // Fallback: lookup pet name by petId in userPets
    final id = _petId;
    if (id != null && id > 0 && userPets.isNotEmpty) {
      for (final p in userPets) {
        final pId = p[Constants.database.COLUMN_ID] ?? p['id'] ?? p['petId'];
        if (pId == id || pId.toString() == id.toString()) {
          final pName = (p[Constants.database.COLUMN_PET_NAME] ?? p['name'] ?? p['petName'])?.toString();
          if (pName != null && pName.isNotEmpty && pName != 'null') return pName.trim();
        }
      }
    }
    return '';
  }

  String get _petBreed {
    final d = _petData;
    final breed = d['breed']?.toString() ??
        d['petBreed']?.toString() ??
        d['pet_breed']?.toString() ??
        d['Breed']?.toString() ??
        booking['breed']?.toString() ??
        booking['petBreed']?.toString() ??
        booking['pet_breed']?.toString() ??
        booking['Breed']?.toString() ??
        '';
    final trimmed = breed.trim();
    if (trimmed.isNotEmpty && trimmed != 'null') return trimmed;

    // Fallback: lookup pet breed by petId in userPets
    final id = _petId;
    if (id != null && id > 0 && userPets.isNotEmpty) {
      for (final p in userPets) {
        final pId = p[Constants.database.COLUMN_ID] ?? p['id'] ?? p['petId'];
        if (pId == id || pId.toString() == id.toString()) {
          final pBreed = (p[Constants.database.COLUMN_BREED] ?? p['breed'] ?? p['petBreed'])?.toString();
          if (pBreed != null && pBreed.isNotEmpty && pBreed != 'null') return pBreed.trim();
        }
      }
    }
    return '';
  }

  String? get _rawPetPhoto {
    final d = _petData;
    final photo = d['profilePictureUrl']?.toString() ??
        d['profilePicture']?.toString() ??
        d['profile_picture_url']?.toString() ??
        d['profile_picture']?.toString() ??
        d['ProfilePictureUrl']?.toString() ??
        d['ProfilePicture']?.toString() ??
        d['petProfilePicture']?.toString() ??
        d['pet_profile_picture']?.toString() ??
        d['PetProfilePicture']?.toString() ??
        d['petPhotoUrl']?.toString() ??
        d['pet_photo_url']?.toString() ??
        d['PetPhotoUrl']?.toString() ??
        d['petPhoto']?.toString() ??
        d['pet_photo']?.toString() ??
        d['PetPhoto']?.toString() ??
        d['photoUrl']?.toString() ??
        d['photo_url']?.toString() ??
        d['PhotoUrl']?.toString() ??
        d['photo']?.toString() ??
        d['image']?.toString() ??
        d['imageUrl']?.toString() ??
        d['image_url']?.toString() ??
        d['petImage']?.toString() ??
        d['pet_image']?.toString() ??
        d['avatar']?.toString() ??
        d['Avatar']?.toString() ??
        booking['profilePictureUrl']?.toString() ??
        booking['profilePicture']?.toString() ??
        booking['profile_picture_url']?.toString() ??
        booking['profile_picture']?.toString() ??
        booking['ProfilePictureUrl']?.toString() ??
        booking['ProfilePicture']?.toString() ??
        booking['petProfilePicture']?.toString() ??
        booking['pet_profile_picture']?.toString() ??
        booking['petPhotoUrl']?.toString() ??
        booking['pet_photo_url']?.toString() ??
        booking['petPhoto']?.toString() ??
        booking['pet_photo']?.toString() ??
        booking['petImage']?.toString() ??
        booking['photoUrl']?.toString() ??
        booking['photo_url']?.toString() ??
        booking['photo']?.toString() ??
        booking['image']?.toString() ??
        booking['imageUrl']?.toString() ??
        booking['image_url']?.toString() ??
        booking['avatar']?.toString();
    if (photo == null ||
        photo.trim().isEmpty ||
        photo == 'null' ||
        photo == 'undefined') {
      return null;
    }
    return photo.trim();
  }

  String? get _resolvedPetPhoto {
    final direct = _rawPetPhoto;
    if (direct != null && direct.isNotEmpty) return direct;

    final id = _petId;
    final name = _petName;

    if (id != null && id > 0 && userPets.isNotEmpty) {
      for (final p in userPets) {
        final pId = p[Constants.database.COLUMN_ID] ?? p['id'] ?? p['petId'];
        if (pId == id || pId.toString() == id.toString()) {
          final photo = p[Constants.database.COLUMN_PHOTO_URL]?.toString() ??
              p['profilePictureUrl']?.toString() ??
              p['profilePicture']?.toString() ??
              p['photoUrl']?.toString() ??
              p['petPhotoUrl']?.toString() ??
              p['image']?.toString();
          if (photo != null &&
              photo.trim().isNotEmpty &&
              photo != 'null' &&
              photo != 'undefined') {
            return photo.trim();
          }
        }
      }
    }

    if (name.isNotEmpty && name != 'Pet' && userPets.isNotEmpty) {
      for (final p in userPets) {
        final pName = (p[Constants.database.COLUMN_PET_NAME] ??
                p['name'] ??
                p['petName'])
            ?.toString();
        if (pName != null && pName.toLowerCase() == name.toLowerCase()) {
          final photo = p[Constants.database.COLUMN_PHOTO_URL]?.toString() ??
              p['profilePictureUrl']?.toString() ??
              p['profilePicture']?.toString() ??
              p['photoUrl']?.toString() ??
              p['petPhotoUrl']?.toString() ??
              p['image']?.toString();
          if (photo != null &&
              photo.trim().isNotEmpty &&
              photo != 'null' &&
              photo != 'undefined') {
            return photo.trim();
          }
        }
      }
    }

    return null;
  }

  String get _serviceName =>
      booking['serviceName']?.toString() ??
      booking['service_name']?.toString() ??
      '';

  String get _groomerName =>
      booking['groomerName']?.toString() ??
      booking['groomer_name']?.toString() ??
      '';

  String get _bookingDate =>
      booking['bookingDate']?.toString() ??
      booking['booking_date']?.toString() ??
      '';

  String get _startTime =>
      booking['startTime']?.toString() ??
      booking['start_time']?.toString() ??
      '';

  String get _endTime =>
      booking['endTime']?.toString() ?? booking['end_time']?.toString() ?? '';

  String get _status =>
      (booking['status']?.toString() ?? 'pending').toUpperCase();

  dynamic get _totalPrice => booking['totalPrice'] ?? booking['total_price'];

  dynamic get _totalDuration =>
      booking['totalDurationMinutes'] ?? booking['total_duration_minutes'];

  // ── helpers ───────────────────────────────────────────────────────────────

  static const _kBaseUrl = 'https://devapi.shearheavenpetspa.com';

  String _fmt12(String hhmm) {
    if (hhmm.isEmpty) return '';
    final clean = hhmm.trim().toUpperCase();
    if (clean.contains('AM') || clean.contains('PM')) return clean;
    final parts = clean.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h < 12 ? 'AM' : 'PM';
    final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$dh:${m.toString().padLeft(2, '0')} $period';
  }

  String _formatDate(String raw) =>
      BookingDateUtils.formatBookingDateDisplay(raw);

  Widget _buildPetImage() {
    final photo = _resolvedPetPhoto;
    final fallbackAsset = (index % 2 == 0)
        ? 'assets/images/common/pet_1.png'
        : 'assets/images/common/pet_2.png';

    Widget fallbackWidget() {
      return Image.asset(
        fallbackAsset,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) =>
            const Icon(Icons.pets, size: 28, color: _kSubText),
      );
    }

    if (photo != null && photo.isNotEmpty) {
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        return Image.network(
          photo,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => fallbackWidget(),
        );
      }
      if (photo.startsWith('assets/')) {
        return Image.asset(
          photo,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => fallbackWidget(),
        );
      }
      try {
        final file = File(photo);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => fallbackWidget(),
          );
        }
      } catch (_) {}
      final clean = photo.startsWith('/') ? photo.substring(1) : photo;
      final fullUrl = '$_kBaseUrl/$clean';
      return Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => fallbackWidget(),
      );
    }
    return fallbackWidget();
  }

  // ── Status chip ───────────────────────────────────────────────────────────
  Widget _statusChip() {
    Color bg;
    Color fg;
    String label;
    switch (_status) {
      case 'IN_PROGRESS':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'In Progress';
        break;
      case 'CONFIRMED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'Confirmed';
        break;
      case 'PENDING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Pending Approval';
        break;
      case 'CANCELLATION_REQUESTED':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFF9A3412);
        label = 'Cancel Requested';
        break;
      case 'COMPLETED':
      case 'PAST':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF374151);
        label = 'Completed';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'Cancelled';
        break;
      case 'UPCOMING':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'Upcoming';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        label = _status.isEmpty ? 'Unknown' : _status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppFonts.poppins(size: 11, weight: FontWeight.w600, color: fg),
      ),
    );
  }

  /// Returns true if cancellation is allowed per the 3h threshold rule.
  /// PENDING → cancels directly (immediate).
  /// CONFIRMED → sends cancellation_requested (groomer approves).
  /// Both are blocked if within the cancellation threshold window.
  bool get _canCancel {
    if (_status != 'PENDING' && _status != 'CONFIRMED') return false;
    if (_bookingDate.isEmpty || _startTime.isEmpty) return true;
    final dateTime = _MyBookingsPageMobileState._parseBookingDateTime(
      _bookingDate,
      _startTime,
    );
    if (dateTime == null) return true;
    return dateTime.difference(DateTime.now()).inMinutes >= 180; // 3 hours
  }

  /// Label for the cancel button — differs by status.
  String get _cancelLabel => _status == 'PENDING' ? 'Cancel' : 'Request Cancel';

  /// Returns a user-friendly message explaining why cancel is blocked.
  String? get _cancelBlockedReason {
    if (_status == 'CANCELLATION_REQUESTED') {
      return 'Cancellation already sent — awaiting groomer approval.';
    }
    if (_status != 'PENDING' && _status != 'CONFIRMED') return null;
    if (_bookingDate.isEmpty || _startTime.isEmpty) return null;
    final dateTime = _MyBookingsPageMobileState._parseBookingDateTime(
      _bookingDate,
      _startTime,
    );
    if (dateTime == null) return null;
    final minsLeft = dateTime.difference(DateTime.now()).inMinutes;
    if (minsLeft < 180) {
      final hLeft = (minsLeft / 60).ceil();
      return 'Cancellation window closed — less than $hLeft hour${hLeft == 1 ? "" : "s"} until appointment.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _bookingDate.isNotEmpty ? _formatDate(_bookingDate) : '—';
    final timeLabel = _startTime.isNotEmpty && _endTime.isNotEmpty
        ? '${_fmt12(_startTime)} – ${_fmt12(_endTime)}'
        : _startTime.isNotEmpty
        ? _fmt12(_startTime)
        : '—';
    final priceLabel = _totalPrice != null
        ? '\$${(double.tryParse(_totalPrice.toString())?.toStringAsFixed(2) ?? _totalPrice.toString())}'
        : null;
    final durationLabel = _totalDuration != null ? '$_totalDuration min' : null;

    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.bookingDetails, extra: booking),
      child: Container(
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pet row ─────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pet photo
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildPetImage(),
              ),
              const SizedBox(width: 14),

              // Pet name + breed
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _petName.isNotEmpty ? _petName : 'Pet',
                      style: AppFonts.poppins(
                        size: 17,
                        weight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_petBreed.isNotEmpty) ...[
                      const SizedBox(height: 1.5),
                      Text(
                        _petBreed,
                        style: AppFonts.poppins(size: 13, color: _kSubText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _statusChip(),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 14),

          // ── Service ──────────────────────────────────────────────────────
          if (_serviceName.isNotEmpty)
            _InfoRow(icon: Icons.content_cut, text: _serviceName),

          // ── Date ─────────────────────────────────────────────────────────
          _InfoRow(icon: Icons.calendar_today_outlined, text: dateLabel),

          // ── Time ─────────────────────────────────────────────────────────
          _InfoRow(icon: Icons.access_time, text: timeLabel),

          // ── Groomer ──────────────────────────────────────────────────────
          if (_groomerName.isNotEmpty)
            _InfoRow(
              icon: Icons.person_outline,
              text: 'Groomer: $_groomerName',
            ),

          // ── Price + Duration ─────────────────────────────────────────────
          if (priceLabel != null || durationLabel != null)
            Row(
              children: [
                if (priceLabel != null)
                  _BadgeChip(
                    icon: Icons.attach_money,
                    label: priceLabel,
                    color: _kBlack,
                    bg: Colors.white,
                  ),
                if (priceLabel != null && durationLabel != null)
                  const SizedBox(width: 8),
                if (durationLabel != null)
                  _BadgeChip(
                    icon: Icons.schedule_outlined,
                    label: durationLabel,
                    color: _kBlack,
                    bg: Colors.white,
                  ),
              ],
            ),

          // ── Actions ───────────────────────────────────────────────────────
          if (onCancel != null ||
              onBookAgain != null ||
              _cancelBlockedReason != null) ...[
            const SizedBox(height: 14),
            // Show "why cancel is blocked" info when status is cancellation_requested
            // or within the 3-hour window
            if (_cancelBlockedReason != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFF9A3412),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _cancelBlockedReason!,
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w400,
                          color: const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (onBookAgain != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onBookAgain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlack,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text(
                        'Book Again',
                        style: AppFonts.poppins(
                          size: 14,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Cancel button — only shown when tab is upcoming AND
                // status allows cancellation
                if (onCancel != null && _canCancel)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cancelling ? null : onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlack,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: cancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _cancelLabel,
                              style: AppFonts.poppins(
                                size: 14,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row — icon + text
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _kBlack),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w500,
                color: _kBlack,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge chip (price / duration)
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  const _BadgeChip({
    required this.icon,
    required this.label,
    this.color = _kBlack,
    this.bg = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppFonts.poppins(
              size: 12,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final _BookingTab tab;
  final VoidCallback onBook;
  const _EmptyView({required this.tab, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final IconData iconData;
    final String title;
    final String message;

    switch (tab) {
      case _BookingTab.upcoming:
        iconData  = Icons.calendar_month_rounded;
        title     = 'No Upcoming Appointments';
        message   =
            'No appointments scheduled for today (${DateFormat('MMM d, yyyy').format(now)}) or upcoming dates.\nBook an appointment for your pet!';
        break;
      case _BookingTab.past:
        iconData  = Icons.history_rounded;
        title     = 'No Past Appointments';
        message   = 'Your completed appointments will appear here.';
        break;
      case _BookingTab.cancelled:
        iconData  = Icons.event_busy_rounded;
        title     = 'No Cancelled Bookings';
        message   = 'You have not cancelled any bookings.';
        break;
    }

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 130),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(iconData, size: 34, color: _kBlack),
            ),
            const SizedBox(height: 16),
            if (tab == _BookingTab.upcoming) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: _kBlack,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Today: ${DateFormat('EEE, MMM d, yyyy').format(now)}',
                      style: AppFonts.poppins(
                        size: 12,
                        weight: FontWeight.w600,
                        color: _kBlack,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: AppFonts.parkinsans(
                size: 17,
                weight: FontWeight.w600,
                color: _kBlack,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppFonts.poppins(size: 13, color: _kSubText),
              textAlign: TextAlign.center,
            ),
            if (tab == _BookingTab.upcoming) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Book Appointment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  textStyle: AppFonts.poppins(
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 130),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 34,
                color: _kBlack,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Bookings',
              style: AppFonts.parkinsans(
                size: 16,
                weight: FontWeight.w600,
                color: _kBlack,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppFonts.poppins(size: 13, color: _kSubText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlack,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: AppFonts.poppins(size: 14, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
