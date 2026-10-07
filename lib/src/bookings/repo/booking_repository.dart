import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/database_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

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

      final payload = <String, dynamic>{
        'ClientId' : clientId,
        'RegionId' : regionId,
        'StoreId'  : storeId,
        'date'     : date,
        if (effectiveServiceId != null) 'serviceId': effectiveServiceId, // ignore: use_null_aware_elements
        if (effectivePackageId != null && effectivePackageId != effectiveServiceId)
          'packageId': effectivePackageId, // ignore: use_null_aware_elements
        if (addOnIds != null && addOnIds.isNotEmpty) 'addOnIds': addOnIds,
        if (groomerId != null && groomerId > 0) 'groomerId': groomerId,
      };

      final response = await ServicesLocator.apiRepository
          .post('/api/availability', payload);

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

      log.d('BookingRepository::createBookingApi::Calling POST /api/bookings');

      final response =
          await ServicesLocator.apiRepository.post('/api/bookings', payload);

      log.d('BookingRepository::createBookingApi::Booking created successfully');
      invalidateUpcomingBookingsCache();

      return response;
    } catch (error) {
      log.e('BookingRepository::createBookingApi::Booking creation failed: $error');
      rethrow;
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
      _cachedUpcomingBookings = list;
      _lastUpcomingBookingsFetch = DateTime.now();
      return list;
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
      return response;
    } catch (error) {
      log.e('BookingRepository::cancelBookingApi::Error: $error');
      rethrow;
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
}
