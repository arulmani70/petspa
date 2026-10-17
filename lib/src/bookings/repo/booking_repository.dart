import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/database_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

class BookingRepository {
  final Logger log = Logger();
  final DatabaseRepository _dbRepo = DatabaseRepository();

  Future<void> initialize() async {
    log.d('BookingRepository::initialize::Initialized');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /api/groomer-availability
  //
  // Postman-confirmed query param names (note capital D in ClientID):
  //   date, ClientID, RegionId, StoreId, durationMinutes
  //   + optional: groomerId  (single groomer)
  //   + optional: groomerIds (comma-separated list, e.g. "1,2")
  //
  // scope returned by backend:
  //   "all"      — no groomerId / groomerIds sent
  //   "single"   — groomerId sent
  //   "selected" — groomerIds sent
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getGroomerAvailability({
    required String date,
    required int durationMinutes,
    int? groomerId,
    List<int>? groomerIds,
  }) async {
    try {
      log.d('BookingRepository::getGroomerAvailability::Fetching groomer availability');
      final session = ServicesLocator.sessionService;
      final clientId  = session.clientId  ?? 'SHEAR-001';
      final regionId  = session.regionId  ?? 'DWG-001';
      final storeId   = session.storeId   ?? 'SHEAR-001';

      final query = <String, dynamic>{
        'date'            : date,
        'ClientID'        : clientId,   // capital D — confirmed by Postman
        'RegionId'        : regionId,
        'StoreId'         : storeId,
        'durationMinutes' : durationMinutes,
      };

      // Exactly one of these is set:
      //   groomerId  → scope = "single"
      //   groomerIds → scope = "selected"  (comma-separated)
      //   neither    → scope = "all"
      if (groomerId != null && groomerId > 0) {
        query['groomerId'] = groomerId;
        log.d('BookingRepository::getGroomerAvailability::Request scope=single date=$date groomerId=$groomerId');
      } else if (groomerIds != null && groomerIds.isNotEmpty) {
        query['groomerIds'] = groomerIds.join(',');
        log.d('BookingRepository::getGroomerAvailability::Request scope=selected date=$date groomerIds=${groomerIds.join(",")}');
      } else {
        log.d('BookingRepository::getGroomerAvailability::Request scope=all date=$date');
      }

      final response = await ServicesLocator.apiRepository
          .get('/api/groomer-availability', query: query);

      log.d('BookingRepository::getGroomerAvailability::Groomer availability response received');

      return response;
    } catch (error) {
      log.e('BookingRepository::getGroomerAvailability::Groomer availability request failed: $error');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /api/availability
  //
  // Postman-confirmed body field names (note: ClientId, NOT ClientID):
  //   ClientId, RegionId, StoreId, date,
  //   serviceId?, packageId?, addOnIds[]?, groomerId?
  //
  // Returns: totalDurationMinutes, totalPrice, availableSlots[], bookedSlots[]
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) async {
    try {
      // Enforce 14-day booking window restriction
      BookingDateUtils.validateDateString(date);

      log.d('BookingRepository::getAvailability::Fetching slot availability for $date');
      final session = ServicesLocator.sessionService;
      final clientId = session.clientId ?? 'SHEAR-001';
      final regionId = session.regionId ?? 'DWG-001';
      final storeId  = session.storeId  ?? 'SHEAR-001';

      // Backend ALWAYS requires serviceId.
      final effectiveServiceId = (serviceId != null && serviceId > 0)
          ? serviceId
          : (packageId != null && packageId > 0 ? packageId : null);
      final effectivePackageId = (packageId != null && packageId > 0)
          ? packageId
          : null;

      final canonicalGroomId = BookingDateUtils.resolveCanonicalGroomerId(groomerId);

      final payload = <String, dynamic>{
        'ClientId' : clientId,
        'RegionId' : regionId,
        'StoreId'  : storeId,
        'date'     : date,
        if (effectiveServiceId != null) 'serviceId': effectiveServiceId, // ignore: use_null_aware_elements
        if (effectivePackageId != null && effectivePackageId != effectiveServiceId)
          'packageId': effectivePackageId, // ignore: use_null_aware_elements
        if (addOnIds != null && addOnIds.isNotEmpty) 'addOnIds': addOnIds,
        if (canonicalGroomId != null && canonicalGroomId > 0) 'groomerId': canonicalGroomId,
      };

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository
            .post('/api/availability', payload);
      } catch (postError) {
        // If groomerId caused a 404/error (e.g. "Groomer X not found"),
        // safely fallback to salon-wide availability to keep booking functional
        if (canonicalGroomId != null && canonicalGroomId > 0) {
          log.w('BookingRepository::getAvailability::Failed with groomerId=$canonicalGroomId, retrying salon-wide: $postError');
          final fallbackPayload = Map<String, dynamic>.from(payload)..remove('groomerId');
          response = await ServicesLocator.apiRepository
              .post('/api/availability', fallbackPayload);
        } else {
          rethrow;
        }
      }

      log.d('BookingRepository::getAvailability::Availability response received');

      return response;
    } catch (error) {
      log.e('BookingRepository::getAvailability::Availability request failed: $error');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /api/bookings
  //
  // Postman-confirmed body:
  //   ClientId, RegionId, StoreId, petId, serviceId?, packageId?,
  //   addOnIds[], groomerId, bookingDate, startTime, endTime
  //
  // Returns: bookingId, status ("confirmed"), totalDurationMinutes, totalPrice
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> createBookingApi(
      Map<String, dynamic> payload) async {
    try {
      // Enforce 14-day booking window restriction
      final bookingDate = payload['bookingDate']?.toString();
      if (bookingDate != null) {
        BookingDateUtils.validateDateString(bookingDate);
      }

      final normalizedPayload = Map<String, dynamic>.from(payload);
      final rawGroomId = normalizedPayload['groomerId'];
      if (rawGroomId != null) {
        final canonId = BookingDateUtils.resolveCanonicalGroomerId(rawGroomId);
        if (canonId != null && canonId > 0) {
          normalizedPayload['groomerId'] = canonId;
        }
      }

      log.d('BookingRepository::createBookingApi::Calling POST /api/bookings');

      final response =
          await ServicesLocator.apiRepository.post('/api/bookings', normalizedPayload);

      log.d('BookingRepository::createBookingApi::Booking created successfully');
      invalidateUpcomingBookingsCache();

      if (response != null && response['success'] != false) {
        await _dispatchBookingCreatedNotifications(payload, response);
      }

      return response;
    } catch (error) {
      log.e('BookingRepository::createBookingApi::Booking creation failed: $error');
      rethrow;
    }
  }

  Future<void> _dispatchBookingCreatedNotifications(
    Map<String, dynamic> payload,
    Map<String, dynamic> response,
  ) async {
    try {
      if (!ServicesLocator.isRegistered<SessionService>()) return;
      final session = ServicesLocator.sessionService;
      final data = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      final rawBookingId = data['bookingId'] ??
          data['id'] ??
          response['bookingId'] ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final bookingId = rawBookingId is int
          ? rawBookingId
          : (int.tryParse(rawBookingId.toString()) ??
              (DateTime.now().millisecondsSinceEpoch ~/ 1000));
      final groomerId = payload['groomerId'] ?? data['groomerId'];
      final bookingDate = (payload['bookingDate'] ?? data['bookingDate'] ?? '').toString();
      final startTime = (payload['startTime'] ?? data['startTime'] ?? '').toString();
      final status = (data['status'] ?? 'pending').toString();
      final currentUid = session.currentUserId;
      final nowIso = DateTime.now().toIso8601String();
      final baseId = DateTime.now().millisecondsSinceEpoch;

      final customerNotifMap = <String, dynamic>{
        'id': baseId,
        'notificationId': baseId,
        if (currentUid != null && currentUid.isNotEmpty)
          'userId': int.tryParse(currentUid) ?? currentUid,
        'title': 'Appointment Booked',
        'message': bookingDate.isNotEmpty
            ? 'Your booking #$bookingId for $bookingDate${startTime.isNotEmpty ? " at $startTime" : ""} has been submitted.'
            : 'Your booking #$bookingId has been submitted.',
        'body': bookingDate.isNotEmpty
            ? 'Your booking #$bookingId for $bookingDate${startTime.isNotEmpty ? " at $startTime" : ""} has been submitted.'
            : 'Your booking #$bookingId has been submitted.',
        'type': 'booking',
        'status': status,
        'isRead': false,
        'is_read': false,
        'createdAt': nowIso,
        'data': <String, dynamic>{
          'bookingId': bookingId,
          'entityId': bookingId,
          'status': status,
          'groomerId': ?groomerId,
        },
      };

      await session.saveCustomerPortalNotification(customerNotifMap);
      if (ServicesLocator.isCustomerSocketServiceRegistered && session.isLoggedIn) {
        ServicesLocator.customerSocketService.handleDirectNotification(
          AppNotification.fromJson(customerNotifMap),
        );
      }

      final groomerNotifMap = <String, dynamic>{
        'id': baseId + 1,
        'notificationId': baseId + 1,
        'groomerId': ?groomerId,
        'title': 'New Booking Request',
        'message': bookingDate.isNotEmpty
            ? 'New booking request #$bookingId for $bookingDate${startTime.isNotEmpty ? " at $startTime" : ""} is awaiting approval.'
            : 'New booking request #$bookingId has been received.',
        'body': bookingDate.isNotEmpty
            ? 'New booking request #$bookingId for $bookingDate${startTime.isNotEmpty ? " at $startTime" : ""} is awaiting approval.'
            : 'New booking request #$bookingId has been received.',
        'type': 'new_booking',
        'status': status,
        'isRead': false,
        'is_read': false,
        'createdAt': nowIso,
        'data': <String, dynamic>{
          'bookingId': bookingId,
          'entityId': bookingId,
          'status': status,
          'groomerId': ?groomerId,
        },
      };

      await session.saveGroomerPortalNotification(groomerNotifMap);
    } catch (e) {
      log.w('BookingRepository::_dispatchBookingCreatedNotifications::Error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /api/bookings/upcoming
  // GET /api/bookings/past
  // GET /api/bookings/cancelled
  //
  // All three require Bearer auth (injected by Dio interceptor).
  // Response: { success, data: { bookings: [...] } }
  //
  // POST /api/bookings/:id/cancel
  // ─────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>>? _cachedUpcomingBookings;
  DateTime? _lastUpcomingBookingsFetch;

  Future<List<Map<String, dynamic>>> getUpcomingBookingsApi({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedUpcomingBookings != null &&
        _lastUpcomingBookingsFetch != null &&
        DateTime.now().difference(_lastUpcomingBookingsFetch!) < const Duration(seconds: 30)) {
      log.d('BookingRepository::getUpcomingBookingsApi::Returning cached upcoming bookings (${_cachedUpcomingBookings!.length} items)');
      return _cachedUpcomingBookings!;
    }
    try {
      log.d('BookingRepository::getUpcomingBookingsApi::GET /api/bookings/upcoming');
      final response =
          await ServicesLocator.apiRepository.get('/api/bookings/upcoming');
      final list = _extractBookingsList(response, 'getUpcomingBookingsApi');
      
      // Auto-cancel any unaccepted pending bookings that exceeded the response deadline
      List<Map<String, dynamic>> processed = list;
      if (ServicesLocator.isBookingCancellationManagerRegistered) {
        processed = await ServicesLocator.bookingCancellationManager
            .filterAndProcessExpiredBookings(list);
      }
      
      _cachedUpcomingBookings = processed;
      _lastUpcomingBookingsFetch = DateTime.now();
      return processed;
    } catch (error) {
      log.e('BookingRepository::getUpcomingBookingsApi::Error: $error');
      if (_cachedUpcomingBookings != null) {
        return _cachedUpcomingBookings!;
      }
      rethrow;
    }
  }

  void invalidateUpcomingBookingsCache() {
    log.d('BookingRepository::invalidateUpcomingBookingsCache::Cache invalidated');
    _cachedUpcomingBookings = null;
    _lastUpcomingBookingsFetch = null;
  }

  Future<List<Map<String, dynamic>>> getPastBookingsApi() async {
    try {
      log.d('BookingRepository::getPastBookingsApi::GET /api/bookings/past');
      final response =
          await ServicesLocator.apiRepository.get('/api/bookings/past');
      return _extractBookingsList(response, 'getPastBookingsApi');
    } catch (error) {
      log.e('BookingRepository::getPastBookingsApi::Error: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCancelledBookingsApi() async {
    try {
      log.d('BookingRepository::getCancelledBookingsApi::GET /api/bookings/cancelled');
      final response =
          await ServicesLocator.apiRepository.get('/api/bookings/cancelled');
      return _extractBookingsList(response, 'getCancelledBookingsApi');
    } catch (error) {
      log.e('BookingRepository::getCancelledBookingsApi::Error: $error');
      rethrow;
    }
  }

  /// POST /api/bookings/:id/cancel
  /// Returns { success, message } — no body required.
  Future<Map<String, dynamic>?> cancelBookingApi(int bookingId) async {
    try {
      log.d('BookingRepository::cancelBookingApi::POST /api/bookings/$bookingId/cancel');
      // The cancel endpoint is a POST with no body (path-param only).
      final response = await ServicesLocator.apiRepository
          .post('/api/bookings/$bookingId/cancel', {});
      invalidateUpcomingBookingsCache();
      log.d('BookingRepository::cancelBookingApi::Response'
          ' success=${response?["success"]}'
          ' message=${response?["message"]}');

      if (response != null && response['success'] == true) {
        await _dispatchBookingCancelledNotifications(bookingId, response);
      }

      return response;
    } catch (error) {
      log.e('BookingRepository::cancelBookingApi::Error: $error');
      rethrow;
    }
  }

  Future<void> _dispatchBookingCancelledNotifications(
    int bookingId,
    Map<String, dynamic> response,
  ) async {
    try {
      if (!ServicesLocator.isRegistered<SessionService>()) return;
      final session = ServicesLocator.sessionService;
      final currentUid = session.currentUserId;
      final nowIso = DateTime.now().toIso8601String();
      final baseId = DateTime.now().millisecondsSinceEpoch;
      final msg = response['message']?.toString() ?? 'Booking #$bookingId has been cancelled.';
      final isRequest = msg.toLowerCase().contains('request');

      final customerNotifMap = <String, dynamic>{
        'id': baseId,
        'notificationId': baseId,
        if (currentUid != null && currentUid.isNotEmpty)
          'userId': int.tryParse(currentUid) ?? currentUid,
        'title': isRequest ? 'Cancellation Requested' : 'Booking Cancelled',
        'message': isRequest
            ? 'Your cancellation request for booking #$bookingId has been submitted.'
            : 'Your booking #$bookingId has been cancelled.',
        'body': isRequest
            ? 'Your cancellation request for booking #$bookingId has been submitted.'
            : 'Your booking #$bookingId has been cancelled.',
        'type': 'cancellation',
        'status': isRequest ? 'cancellation_requested' : 'cancelled',
        'isRead': false,
        'is_read': false,
        'createdAt': nowIso,
        'data': <String, dynamic>{
          'bookingId': bookingId,
          'entityId': bookingId,
          'status': isRequest ? 'cancellation_requested' : 'cancelled',
        },
      };

      await session.saveCustomerPortalNotification(customerNotifMap);
      if (ServicesLocator.isCustomerSocketServiceRegistered && session.isLoggedIn) {
        ServicesLocator.customerSocketService.handleDirectNotification(
          AppNotification.fromJson(customerNotifMap),
        );
      }

      final groomerNotifMap = <String, dynamic>{
        'id': baseId + 1,
        'notificationId': baseId + 1,
        'title': isRequest ? 'Cancellation Requested' : 'Booking Cancelled',
        'message': isRequest
            ? 'Customer requested cancellation for booking #$bookingId.'
            : 'Booking #$bookingId was cancelled by the customer.',
        'body': isRequest
            ? 'Customer requested cancellation for booking #$bookingId.'
            : 'Booking #$bookingId was cancelled by the customer.',
        'type': 'cancellation_requested',
        'status': isRequest ? 'cancellation_requested' : 'cancelled',
        'isRead': false,
        'is_read': false,
        'createdAt': nowIso,
        'data': <String, dynamic>{
          'bookingId': bookingId,
          'entityId': bookingId,
          'status': isRequest ? 'cancellation_requested' : 'cancelled',
        },
      };

      await session.saveGroomerPortalNotification(groomerNotifMap);
    } catch (e) {
      log.w('BookingRepository::_dispatchBookingCancelledNotifications::Error: $e');
    }
  }

  /// Extracts the bookings list from the API response wrapper.
  /// Handles both { data: { bookings: [...] } } and { data: [...] } shapes.
  List<Map<String, dynamic>> _extractBookingsList(
      Map<String, dynamic>? response, String caller) {
    if (response == null) {
      log.w('BookingRepository::$caller::null response — returning []');
      return [];
    }
    if (response['success'] == false) {
      log.w('BookingRepository::$caller::success=false'
          ' message=${response["message"]}');
      return [];
    }
    final data = response['data'];
    List<dynamic>? raw;
    if (data is Map) {
      // { data: { bookings: [...] } }
      raw = data['bookings'] as List<dynamic>?;
      // some backends also use 'items', 'results', or flat list
      raw ??= data['items']   as List<dynamic>?;
      raw ??= data['results'] as List<dynamic>?;
    } else if (data is List) {
      raw = data;
    }
    if (raw == null) {
      log.w('BookingRepository::$caller::no bookings list in response data');
      return [];
    }
    final list = raw
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .toList();
    log.d('BookingRepository::$caller::Response ${list.length} bookings');
    return list;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SQLite legacy methods — kept for backward compat; not used by the UI.
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllBookings(
      {int? userId, String? status}) async {
    try {
      log.d('BookingRepository::getAllBookings::userId=$userId status=$status');

      final conditions = <String>[
        '${Constants.database.COLUMN_IS_DELETED} = ?',
      ];
      final args = <Object?>[0];

      if (userId != null) {
        conditions.add('${Constants.database.COLUMN_USER_ID} = ?');
        args.add(userId);
      }
      if (status != null && status.isNotEmpty) {
        conditions.add('${Constants.database.COLUMN_STATUS} = ?');
        args.add(status);
      }

      return await _dbRepo.query(
        Constants.database.TABLE_BOOKINGS,
        where: conditions.join(' AND '),
        whereArgs: args,
        orderBy: '${Constants.database.COLUMN_START_TIME} DESC',
      );
    } catch (error) {
      log.e('BookingRepository::getAllBookings::Error: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getBookingById(int id) async {
    try {
      log.d('BookingRepository::getBookingById::id=$id');
      final results = await _dbRepo.query(
        Constants.database.TABLE_BOOKINGS,
        where: '${Constants.database.COLUMN_ID} = ?',
        whereArgs: [id],
        limit: 1,
      );
      return results.isEmpty ? null : results.first;
    } catch (error) {
      log.e('BookingRepository::getBookingById::Error: $error');
      rethrow;
    }
  }

  Future<int> createBooking(Map<String, dynamic> bookingData) async {
    try {
      log.d('BookingRepository::createBooking::Inserting local booking');
      bookingData[Constants.database.COLUMN_SYNC_STATUS] =
          Constants.database.SYNC_STATUS_PENDING;
      bookingData[Constants.database.COLUMN_STATUS] = 'PENDING';
      final localId = await _dbRepo.insert(
          Constants.database.TABLE_BOOKINGS, bookingData);
      log.d('BookingRepository::createBooking::localId=$localId');
      return localId;
    } catch (error) {
      log.e('BookingRepository::createBooking::Error: $error');
      rethrow;
    }
  }

  Future<int> updateBookingStatus(int bookingId, String status) async {
    try {
      log.d('BookingRepository::updateBookingStatus::id=$bookingId status=$status');
      return await _dbRepo.update(
        Constants.database.TABLE_BOOKINGS,
        {
          Constants.database.COLUMN_STATUS: status,
          Constants.database.COLUMN_SYNC_STATUS:
              Constants.database.SYNC_STATUS_PENDING,
        },
        where: '${Constants.database.COLUMN_ID} = ?',
        whereArgs: [bookingId],
      );
    } catch (error) {
      log.e('BookingRepository::updateBookingStatus::Error: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingBookings(
      {int? userId}) async {
    try {
      log.d('BookingRepository::getUpcomingBookings::userId=$userId');
      final now = DateTime.now().toUtc().toIso8601String();
      final conditions = <String>[
        '${Constants.database.COLUMN_IS_DELETED} = ?',
        '${Constants.database.COLUMN_STATUS} != ?',
        '${Constants.database.COLUMN_START_TIME} >= ?',
      ];
      final args = <Object?>[0, 'CANCELLED', now];
      if (userId != null) {
        conditions.add('${Constants.database.COLUMN_USER_ID} = ?');
        args.add(userId);
      }
      return await _dbRepo.query(
        Constants.database.TABLE_BOOKINGS,
        where: conditions.join(' AND '),
        whereArgs: args,
        orderBy: '${Constants.database.COLUMN_START_TIME} ASC',
      );
    } catch (error) {
      log.e('BookingRepository::getUpcomingBookings::Error: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPastBookings({int? userId}) async {
    try {
      log.d('BookingRepository::getPastBookings::userId=$userId');
      final now = DateTime.now().toUtc().toIso8601String();
      final conditions = <String>[
        '${Constants.database.COLUMN_IS_DELETED} = ?',
        '${Constants.database.COLUMN_START_TIME} < ?',
      ];
      final args = <Object?>[0, now];
      if (userId != null) {
        conditions.add('${Constants.database.COLUMN_USER_ID} = ?');
        args.add(userId);
      }
      return await _dbRepo.query(
        Constants.database.TABLE_BOOKINGS,
        where: conditions.join(' AND '),
        whereArgs: args,
        orderBy: '${Constants.database.COLUMN_START_TIME} DESC',
      );
    } catch (error) {
      log.e('BookingRepository::getPastBookings::Error: $error');
      rethrow;
    }
  }

  Future<List<String>> getBookedSlotsForDate(String date) async {
    try {
      log.d('BookingRepository::getBookedSlotsForDate::date=$date');
      final results = await _dbRepo.query(
        Constants.database.TABLE_BOOKINGS,
        where:
            '${Constants.database.COLUMN_SLOT} LIKE ? AND ${Constants.database.COLUMN_STATUS} != ?',
        whereArgs: ['$date%', 'CANCELLED'],
      );
      return results
          .map((e) => e[Constants.database.COLUMN_SLOT]?.toString() ?? '')
          .toList();
    } catch (error) {
      log.e('BookingRepository::getBookedSlotsForDate::Error: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getBookingsForDate(String date) async {
    try {
      log.d('BookingRepository::getBookingsForDate::date=$date');
      return await _dbRepo.query(
        Constants.database.TABLE_BOOKINGS,
        where:
            '${Constants.database.COLUMN_SLOT} LIKE ? AND ${Constants.database.COLUMN_STATUS} != ?',
        whereArgs: ['$date%', 'CANCELLED'],
      );
    } catch (error) {
      log.e('BookingRepository::getBookingsForDate::Error: $error');
      rethrow;
    }
  }

  Future<int> cancelBooking(int bookingId) =>
      updateBookingStatus(bookingId, 'CANCELLED');

  // ─────────────────────────────────────────────────────────────────────────
  // Step 9: Customer Tip Confirmation
  //
  // Calls POST /api/bookings/:bookingId/confirm-tip (or fallback /tip).
  //
  // CRITICAL SAFEGUARD: Never triggers payment, never marks booking completed,
  // never charges customer, and never performs final checkout (strictly Step 10).
  // Deduplicates in-flight calls and ensures valid customer session.
  // ─────────────────────────────────────────────────────────────────────────
  final Map<int, Future<({
    bool success,
    String message,
    double? confirmedTipAmount,
    double? confirmedTipPercentage,
    Map<String, dynamic>? updatedBooking,
    bool isPendingBackend,
  })>> _inFlightTipConfirmations = {};

  Future<({
    bool success,
    String message,
    double? confirmedTipAmount,
    double? confirmedTipPercentage,
    Map<String, dynamic>? updatedBooking,
    bool isPendingBackend,
  })> confirmTipDetails({
    required int bookingId,
    required double tipAmount,
    double? tipPercentage,
    Map<String, dynamic>? booking,
  }) async {
    // 1. In-flight request deduplication: prevent concurrent duplicate submissions
    if (_inFlightTipConfirmations.containsKey(bookingId)) {
      log.d('BookingRepository::confirmTipDetails::Deduping concurrent request for booking #$bookingId');
      return await _inFlightTipConfirmations[bookingId]!;
    }

    final future = _executeConfirmTipDetails(
      bookingId: bookingId,
      tipAmount: tipAmount,
      tipPercentage: tipPercentage,
      booking: booking,
    );

    _inFlightTipConfirmations[bookingId] = future;
    try {
      return await future;
    } finally {
      _inFlightTipConfirmations.remove(bookingId);
    }
  }

  Future<({
    bool success,
    String message,
    double? confirmedTipAmount,
    double? confirmedTipPercentage,
    Map<String, dynamic>? updatedBooking,
    bool isPendingBackend,
  })> _executeConfirmTipDetails({
    required int bookingId,
    required double tipAmount,
    double? tipPercentage,
    Map<String, dynamic>? booking,
  }) async {
    try {
      if (bookingId <= 0) {
        return (
          success: false,
          message: 'Invalid booking ID.',
          confirmedTipAmount: null,
          confirmedTipPercentage: null,
          updatedBooking: null,
          isPendingBackend: false,
        );
      }

      if (tipAmount < 0) {
        return (
          success: false,
          message: 'Tip amount cannot be negative.',
          confirmedTipAmount: null,
          confirmedTipPercentage: null,
          updatedBooking: null,
          isPendingBackend: false,
        );
      }

      // Customer ownership validation:
      // If user is logged in, ensure booking belongs to user if customer ID is present
      final session = ServicesLocator.isRegistered<SessionService>()
          ? ServicesLocator.sessionService
          : null;

      if (session != null && session.isLoggedIn) {
        final currentUid = session.currentUserId;
        if (booking != null && currentUid != null && currentUid.isNotEmpty) {
          final bookingCustId = booking['customerId'] ??
              booking['customer_id'] ??
              booking['userId'] ??
              booking['user_id'];
          if (bookingCustId != null) {
            final bIdStr = bookingCustId.toString();
            if (bIdStr != currentUid && bIdStr != '0') {
              log.w('BookingRepository::confirmTipDetails::User $currentUid does not own booking #$bookingId (owner=$bIdStr)');
              return (
                success: false,
                message: 'You can only confirm tips for your own bookings.',
                confirmedTipAmount: null,
                confirmedTipPercentage: null,
                updatedBooking: null,
                isPendingBackend: false,
              );
            }
          }
        }
      }

      final payload = <String, dynamic>{
        'tipAmount': tipAmount,
        'tip_amount': tipAmount,
        'tipPercentage': ?tipPercentage,
        'tip_percentage': ?tipPercentage,
        'note': 'Tip confirmed by customer',
        'bookingId': bookingId,
        'booking_id': bookingId,
      };

      log.d('BookingRepository::confirmTipDetails::POST /api/bookings/$bookingId/confirm-tip payload=$payload');

      Map<String, dynamic>? response;
      bool isPendingBackend = false;

      try {
        response = await ServicesLocator.apiRepository
            .post('/api/bookings/$bookingId/confirm-tip', payload);
        if (response == null || response['success'] == false) {
          final code = response?['statusCode'];
          // Only attempt fallback endpoint if error was not an authentication or authorization failure
          if (code != 401 && code != 403) {
            response = await ServicesLocator.apiRepository
                .post('/api/bookings/$bookingId/tip', payload);
          }
        }
      } catch (e) {
        try {
          response = await ServicesLocator.apiRepository
              .post('/api/bookings/$bookingId/tip', payload);
        } catch (_) {
          log.w('BookingRepository::confirmTipDetails::Endpoint /api/bookings/$bookingId/confirm-tip unavailable ($e). Recording tip preference locally.');
        }
      }

      // Check if session became expired during request or if response returned 401
      final statusCode = response?['statusCode'] is int
          ? response!['statusCode'] as int
          : (response?['status'] is int ? response!['status'] as int : null);

      if (statusCode == 401) {
        log.w('BookingRepository::confirmTipDetails::401 Unauthorized from backend for booking #$bookingId');
        return (
          success: false,
          message: 'Your session has expired. Please log in again to confirm your tip.',
          confirmedTipAmount: null,
          confirmedTipPercentage: null,
          updatedBooking: null,
          isPendingBackend: false,
        );
      }

      if (statusCode == 403) {
        log.w('BookingRepository::confirmTipDetails::403 Forbidden for booking #$bookingId');
        final msg = response?['message']?.toString() ??
            'You are not authorized to confirm tip for this booking.';
        return (
          success: false,
          message: msg,
          confirmedTipAmount: null,
          confirmedTipPercentage: null,
          updatedBooking: null,
          isPendingBackend: false,
        );
      }

      // If backend explicitly returns a 400 validation rejection (e.g. invalid tip limits)
      if (statusCode == 400 && response?['message'] != null) {
        final msg = response!['message'].toString();
        if (msg.isNotEmpty &&
            (msg.toLowerCase().contains('invalid') || msg.toLowerCase().contains('exceed'))) {
          return (
            success: false,
            message: msg,
            confirmedTipAmount: null,
            confirmedTipPercentage: null,
            updatedBooking: null,
            isPendingBackend: false,
          );
        }
      }

      if (response == null ||
          response['success'] == false ||
          (statusCode != null && statusCode >= 400)) {
        isPendingBackend = true;
      }

      // Build updated booking representation
      // CRITICAL SAFEGUARD: Booking status is preserved as 'ready_for_checkout', NOT 'completed'
      // Payment status is NOT marked as paid.
      final currentStatus = booking?['status']?.toString() ?? 'ready_for_checkout';
      final updated = Map<String, dynamic>.from(booking ?? <String, dynamic>{})
        ..['tipAmount'] = tipAmount
        ..['tip_amount'] = tipAmount
        ..['tipPercentage'] = tipPercentage
        ..['tip_percentage'] = tipPercentage
        ..['isTipConfirmed'] = true
        ..['status'] = currentStatus; // PRESERVED!

      // Persist confirmed tip and update shared state so groomer sees the confirmation
      if (session != null) {
        final custId = booking?['customerId'] ??
            booking?['customer_id'] ??
            booking?['userId'] ??
            booking?['user_id'];
        final resolvedCustId = custId is int
            ? custId
            : int.tryParse(custId?.toString() ?? '');

        await session.saveConfirmedTip(
          bookingId: bookingId,
          tipAmount: tipAmount,
          tipPercentage: tipPercentage,
          customerId: resolvedCustId,
        );

        // Dispatch notification to groomer portal & real-time stream
        final groomerId = booking?['groomerId'] ?? booking?['groomer_id'];
        final resolvedGroomerId = groomerId is int
            ? groomerId
            : int.tryParse(groomerId?.toString() ?? '');
        final petName = booking?['petName'] ??
            booking?['pet_name'] ??
            (booking?['pet'] is Map ? booking!['pet']['name'] : null) ??
            'Pet';
        final nowIso = DateTime.now().toIso8601String();
        final notifId = DateTime.now().millisecondsSinceEpoch;

        final groomerNotif = <String, dynamic>{
          'id': notifId,
          'notificationId': notifId,
          if (resolvedGroomerId != null && resolvedGroomerId > 0)
            'groomerId': resolvedGroomerId,
          'title': 'Customer Confirmed Tip',
          'message': tipAmount > 0
              ? 'Customer confirmed a tip of \$${tipAmount.toStringAsFixed(2)} for $petName (Booking #$bookingId).'
              : 'Customer reviewed checkout for $petName (Booking #$bookingId) with no tip.',
          'body': tipAmount > 0
              ? 'Customer confirmed a tip of \$${tipAmount.toStringAsFixed(2)} for $petName (Booking #$bookingId).'
              : 'Customer reviewed checkout for $petName (Booking #$bookingId) with no tip.',
          'type': 'booking_tip_confirmed',
          'status': 'ready_for_checkout',
          'isRead': false,
          'createdAt': nowIso,
          'data': <String, dynamic>{
            'bookingId': bookingId,
            'entityId': bookingId,
            'tipAmount': tipAmount,
            'tipPercentage': ?tipPercentage,
            'isTipConfirmed': true,
            'status': 'ready_for_checkout',
          },
        };

        await session.saveGroomerPortalNotification(
          groomerNotif,
          groomerId: resolvedGroomerId,
        );

        if (ServicesLocator.isGroomerSocketServiceRegistered) {
          ServicesLocator.groomerSocketService.handleDirectNotification(
            AppNotification.fromJson(groomerNotif),
          );
        }
      }

      // Update cached upcoming bookings if present
      if (_cachedUpcomingBookings != null) {
        final idx = _cachedUpcomingBookings!.indexWhere((b) {
          final id = b['bookingId'] ?? b['id'] ?? b['booking_id'];
          return id != null && id.toString() == bookingId.toString();
        });
        if (idx >= 0) {
          _cachedUpcomingBookings![idx] =
              Map<String, dynamic>.from(_cachedUpcomingBookings![idx])
                ..addAll(updated);
        }
      }

      final successMsg = isPendingBackend
          ? 'Tip preference recorded. (Backend persistence pending endpoint deployment).'
          : (response?['message']?.toString() ?? 'Tip preference confirmed successfully.');

      return (
        success: true,
        message: successMsg,
        confirmedTipAmount: tipAmount,
        confirmedTipPercentage: tipPercentage,
        updatedBooking: updated,
        isPendingBackend: isPendingBackend,
      );
    } catch (e) {
      log.e('BookingRepository::confirmTipDetails::Error: $e');
      return (
        success: false,
        message: 'Failed to confirm tip: $e',
        confirmedTipAmount: null,
        confirmedTipPercentage: null,
        updatedBooking: null,
        isPendingBackend: false,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Customer Checkout Summary & Receipt Endpoints (Verified Live)
  // ─────────────────────────────────────────────────────────────────────────

  /// GET /api/bookings/:id/checkout-summary
  Future<Map<String, dynamic>?> getCheckoutSummary(int bookingId) async {
    try {
      log.d('BookingRepository::getCheckoutSummary::bookingId=$bookingId');
      final response = await ServicesLocator.apiRepository.get(
        '/api/bookings/$bookingId/checkout-summary',
      );
      if (response != null && response['success'] == true) {
        return response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : response;
      }
      return null;
    } catch (e) {
      log.e('BookingRepository::getCheckoutSummary::Error: $e');
      return null;
    }
  }

  /// Fetches authoritative checkout confirmation details for [bookingId].
  ///
  /// Combines:
  /// 1. GET /api/bookings/:id/checkout-summary
  /// 2. GET /api/bookings/:id
  /// 3. Upcoming/Past bookings list lookup
  /// 4. Local SQLite database lookup
  /// 5. Persistent confirmed tip from SessionService
  Future<Map<String, dynamic>?> getCheckoutConfirmationDetails(int bookingId) async {
    try {
      log.d('BookingRepository::getCheckoutConfirmationDetails::bookingId=$bookingId');

      Map<String, dynamic>? details;

      // 1. Try dedicated checkout-summary endpoint
      try {
        final summary = await getCheckoutSummary(bookingId);
        if (summary != null && summary.isNotEmpty) {
          details = Map<String, dynamic>.from(summary);
        }
      } catch (e) {
        log.d('BookingRepository::getCheckoutConfirmationDetails::checkout-summary fallback: $e');
      }

      // 2. Try direct booking endpoint: GET /api/bookings/:id
      if (details == null || (details['petName'] == null && details['pet'] == null)) {
        try {
          final res = await ServicesLocator.apiRepository.get('/api/bookings/$bookingId');
          if (res != null) {
            final data = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : res;
            if (data.isNotEmpty) {
              details = details != null ? {...details, ...data} : data;
            }
          }
        } catch (e) {
          log.d('BookingRepository::getCheckoutConfirmationDetails::GET /api/bookings/$bookingId fallback: $e');
        }
      }

      // 3. Try upcoming bookings API lookup
      if (details == null || details['serviceName'] == null) {
        try {
          final upcoming = await getUpcomingBookingsApi(forceRefresh: true);
          final match = upcoming.firstWhere(
            (b) {
              final id = b['bookingId'] ?? b['id'] ?? b['booking_id'];
              return id != null && id.toString() == bookingId.toString();
            },
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty) {
            details = details != null ? {...match, ...details} : Map<String, dynamic>.from(match);
          }
        } catch (e) {
          log.d('BookingRepository::getCheckoutConfirmationDetails::upcoming bookings lookup fallback: $e');
        }
      }

      // 4. Try local SQLite query
      if (details == null) {
        try {
          final local = await getBookingById(bookingId);
          if (local != null && local.isNotEmpty) {
            details = Map<String, dynamic>.from(local);
          }
        } catch (e) {
          log.d('BookingRepository::getCheckoutConfirmationDetails::local DB fallback: $e');
        }
      }

      // 5. Merge confirmed tip from SessionService if available
      if (details != null && ServicesLocator.isRegistered<SessionService>()) {
        final confirmedTip = ServicesLocator.sessionService.getConfirmedTip(bookingId);
        if (confirmedTip != null) {
          final tipAmount = confirmedTip['tipAmount'];
          final tipPct = confirmedTip['tipPercentage'];
          if (tipAmount != null) {
            details['tipAmount'] = tipAmount;
            details['tip_amount'] = tipAmount;
            details['isTipConfirmed'] = true;
          }
          if (tipPct != null) {
            details['tipPercentage'] = tipPct;
            details['tip_percentage'] = tipPct;
          }
        }
      }

      return details;
    } catch (e) {
      log.e('BookingRepository::getCheckoutConfirmationDetails::Error: $e');
      return null;
    }
  }

  /// GET /api/bookings/:id/receipt
  ///
  /// Fetches authoritative receipt and invoice from {{baseUrl}}/api/bookings/{{bookingId}}/receipt.
  Future<Map<String, dynamic>?> getReceipt(int bookingId) => getBookingReceipt(bookingId);

  /// GET /api/bookings/:id/receipt
  Future<Map<String, dynamic>?> getBookingReceipt(int bookingId) async {
    try {
      log.d('BookingRepository::getBookingReceipt::GET /api/bookings/$bookingId/receipt');
      final response = await ServicesLocator.apiRepository.get(
        '/api/bookings/$bookingId/receipt',
      );
      if (response != null) {
        if (response['data'] is Map) {
          return Map<String, dynamic>.from(response['data'] as Map);
        } else if (response['receipt'] is Map) {
          return Map<String, dynamic>.from(response['receipt'] as Map);
        } else if (response['success'] != false) {
          return response;
        }
      }
      return null;
    } catch (e) {
      log.e('BookingRepository::getBookingReceipt::Error: $e');
      return null;
    }
  }
}

