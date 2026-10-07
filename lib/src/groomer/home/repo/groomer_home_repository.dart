import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class GroomerHomeRepository {
  final Logger log = Logger();

  Future<void> initialize() async {
    log.d('GroomerHomeRepository::initialize::Initialized');
  }

  /// GET /api/groomer-auth/profile
  Future<GroomerUser?> getProfile() async {
    try {
      log.d('GroomerHomeRepository::getProfile::Fetching groomer profile');

      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/profile',
      );

      if (response == null || response['success'] != true || response['data'] == null) {
        log.w('GroomerHomeRepository::getProfile::Failed to fetch profile');
        return getCurrentGroomer();
      }

      final data = response['data'] as Map<String, dynamic>;
      final groomer = GroomerUser.fromJson(data);

      final currentToken = await ServicesLocator.sessionService.getGroomerAccessToken() ?? '';
      final currentRefreshToken = await ServicesLocator.sessionService.getGroomerRefreshToken() ?? '';
      await ServicesLocator.sessionService.saveGroomerSession(
        accessToken: currentToken,
        refreshToken: currentRefreshToken,
        groomerData: groomer.toJson(),
      );

      return groomer;
    } catch (error) {
      log.e('GroomerHomeRepository::getProfile::Error: $error');
      return getCurrentGroomer();
    }
  }

  /// PUT /api/groomer-auth/profile
  Future<GroomerUser?> updateProfile({
    String? firstName,
    String? lastName,
    String? mobile,
    String? highlights,
    bool? multiBookingEnabled,
    int? slotBookingLimit,
  }) async {
    try {
      log.d('GroomerHomeRepository::updateProfile::Updating groomer profile');

      final current = getCurrentGroomer();
      final body = <String, dynamic>{
        'firstName': firstName ?? current?.firstName ?? '',
        'lastName': lastName ?? current?.lastName ?? '',
        'mobile': mobile ?? current?.mobile ?? '',
        'highlights': highlights ?? current?.highlights ?? '',
        'multiBookingEnabled': multiBookingEnabled ?? current?.multiBookingEnabled ?? false,
        'slotBookingLimit': slotBookingLimit ?? current?.slotBookingLimit ?? 1,
      };

      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/profile',
        body,
      );

      bool isPutSuccess = false;
      if (response == null || response['success'] != true) {
        isPutSuccess = await ServicesLocator.apiRepository.put(
          '/api/groomer-auth/profile',
          body,
        );
      }

      if (response != null && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final updated = GroomerUser.fromJson(data);
        final currentToken = await ServicesLocator.sessionService.getGroomerAccessToken() ?? '';
        final currentRefreshToken = await ServicesLocator.sessionService.getGroomerRefreshToken() ?? '';
        await ServicesLocator.sessionService.saveGroomerSession(
          accessToken: currentToken,
          refreshToken: currentRefreshToken,
          groomerData: updated.toJson(),
        );
        return updated;
      }

      if (isPutSuccess) {
        return await getProfile();
      }

      return current;
    } catch (error) {
      log.e('GroomerHomeRepository::updateProfile::Error: $error');
      rethrow;
    }
  }

  /// GET /api/groomer-auth/bookings/upcoming
  Future<List<GroomerBooking>> getUpcomingBookings() async {
    try {
      log.d('GroomerHomeRepository::getUpcomingBookings::Fetching upcoming bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/upcoming',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getUpcomingBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/pending
  Future<List<GroomerBooking>> getPendingBookings() async {
    try {
      log.d('GroomerHomeRepository::getPendingBookings::Fetching pending bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/pending',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getPendingBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/past
  Future<List<GroomerBooking>> getPastBookings() async {
    try {
      log.d('GroomerHomeRepository::getPastBookings::Fetching past bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/past',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getPastBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/cancelled
  Future<List<GroomerBooking>> getCancelledBookings() async {
    try {
      log.d('GroomerHomeRepository::getCancelledBookings::Fetching cancelled bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/cancelled',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getCancelledBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/cancellation-requests
  Future<List<GroomerBooking>> getCancellationRequests() async {
    try {
      log.d('GroomerHomeRepository::getCancellationRequests::Fetching cancellation requests');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/cancellation-requests',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getCancellationRequests::Error: $e');
      return [];
    }
  }

  /// POST /api/groomer-auth/bookings/:id/approve
  Future<({bool success, String message})> approveBookingDetails(int bookingId) async {
    try {
      log.d('GroomerHomeRepository::approveBooking::Approving booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/approve',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Booking #$bookingId approved successfully' : 'Failed to approve booking.');
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::approveBooking::Error: $e');
      return (success: false, message: 'Error approving booking: $e');
    }
  }

  Future<bool> approveBooking(int bookingId) async {
    final res = await approveBookingDetails(bookingId);
    return res.success;
  }

  /// POST /api/groomer-auth/bookings/:id/reject
  Future<({bool success, String message})> rejectBookingDetails(int bookingId) async {
    try {
      log.d('GroomerHomeRepository::rejectBooking::Rejecting booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/reject',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Booking #$bookingId rejected' : 'Failed to reject booking.');
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::rejectBooking::Error: $e');
      return (success: false, message: 'Error rejecting booking: $e');
    }
  }

  Future<bool> rejectBooking(int bookingId) async {
    final res = await rejectBookingDetails(bookingId);
    return res.success;
  }

  /// POST /api/groomer-auth/bookings/:id/start
  Future<({bool success, String message})> startBookingDetails(int bookingId) async {
    try {
      log.d('GroomerHomeRepository::startBooking::Starting booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/start',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Appointment #$bookingId is now In Progress' : 'Failed to start appointment.');
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::startBooking::Error: $e');
      return (success: false, message: 'Error starting appointment: $e');
    }
  }

  Future<bool> startBooking(int bookingId) async {
    final res = await startBookingDetails(bookingId);
    return res.success;
  }

  /// POST /api/groomer-auth/bookings/:id/complete
  Future<({bool success, String message})> completeBookingDetails(int bookingId) async {
    try {
      log.d('GroomerHomeRepository::completeBooking::Completing booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/complete',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Appointment #$bookingId marked as completed' : 'Failed to complete appointment.');
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::completeBooking::Error: $e');
      return (success: false, message: 'Error completing appointment: $e');
    }
  }

  Future<bool> completeBooking(int bookingId) async {
    final res = await completeBookingDetails(bookingId);
    return res.success;
  }

  /// POST /api/groomer-auth/bookings/:id/approve-cancellation
  Future<({bool success, String message})> approveCancellationDetails(int bookingId) async {
    try {
      log.d('GroomerHomeRepository::approveCancellation::Approving cancellation #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/approve-cancellation',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Cancellation for Booking #$bookingId approved' : 'Failed to approve cancellation.');
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::approveCancellation::Error: $e');
      return (success: false, message: 'Error approving cancellation: $e');
    }
  }

  Future<bool> approveCancellation(int bookingId) async {
    final res = await approveCancellationDetails(bookingId);
    return res.success;
  }

  /// POST /api/groomer-auth/bookings/:id/reject-cancellation
  Future<({bool success, String message})> rejectCancellationDetails(int bookingId) async {
    try {
      log.d('GroomerHomeRepository::rejectCancellation::Rejecting cancellation #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/reject-cancellation',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Cancellation for Booking #$bookingId rejected' : 'Failed to reject cancellation.');
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::rejectCancellation::Error: $e');
      return (success: false, message: 'Error rejecting cancellation: $e');
    }
  }

  Future<bool> rejectCancellation(int bookingId) async {
    final res = await rejectCancellationDetails(bookingId);
    return res.success;
  }

  /// GET /api/groomer-auth/customers?search=&limit=50&offset=0
  ///
  /// Searches registered customers by name, phone, or email using the staff's session.
  Future<List<CustomerSummary>> searchCustomers({
    String? query,
    int page = 1,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final actualOffset = offset > 0 ? offset : (page > 1 ? (page - 1) * limit : 0);
      log.d('GroomerHomeRepository::searchCustomers::Searching customers (search: $query, limit: $limit, offset: $actualOffset)');
      final queryParams = <String, dynamic>{
        'search': query?.trim() ?? '',
        'limit': limit,
        'offset': actualOffset,
      };

      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/customers',
        query: queryParams,
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        final data = response['data'];
        List<dynamic> list = [];
        if (data is Map && data['customers'] is List) {
          list = data['customers'] as List;
        } else if (data is Map && data['users'] is List) {
          list = data['users'] as List;
        } else if (data is List) {
          list = data;
        }

        return list
            .whereType<Map<String, dynamic>>()
            .map((c) => CustomerSummary.fromJson(c))
            .toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::searchCustomers::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/customers/:userId/pets
  ///
  /// Fetches pets for a specific customer userId using the staff's session.
  Future<List<CustomerPetSummary>> getCustomerPets(int userId) async {
    try {
      log.d('GroomerHomeRepository::getCustomerPets::Fetching pets for customer userId: $userId');

      // Primary endpoint from Postman: /api/groomer-auth/customers/:userId/pets
      var response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/customers/$userId/pets',
      );

      // Fallback endpoint if primary returns null / false
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.get(
          '/api/groomer-auth/users/$userId/pets',
        );
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.get(
          '/api/pets',
          query: {'userId': userId},
        );
      }

      if (response != null && response['data'] != null) {
        final data = response['data'];
        List<dynamic> list = [];
        if (data is Map && data['pets'] is List) {
          list = data['pets'] as List;
        } else if (data is List) {
          list = data;
        }

        return list
            .whereType<Map<String, dynamic>>()
            .map((p) => CustomerPetSummary.fromJson(p))
            .toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getCustomerPets::Error: $e');
      return [];
    }
  }

  /// POST /api/groomer-auth/bookings/create-for-user
  Future<Map<String, dynamic>?> createBookingForUser({
    required int userId,
    required int petId,
    required int serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
    required String bookingDate,
    required String startTime,
    required String endTime,
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final body = <String, dynamic>{
        'userId': userId,
        'petId': petId,
        'serviceId': serviceId,
        if (packageId != null && packageId > 0) 'packageId': packageId,
        'addOnIds': addOnIds ?? [],
        if (groomerId != null && groomerId > 0) 'groomerId': groomerId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        'endTime': endTime,
        'clientId': clientId ?? groomer?.clientId ?? 'SHEAR-001',
        'regionId': regionId ?? groomer?.regionId ?? 'DWG-001',
        'storeId': storeId ?? groomer?.storeId ?? 'SHEAR-001',
      };

      log.d('GroomerHomeRepository::createBookingForUser::Creating booking for user $userId (groomerId: ${groomerId ?? groomer?.id})');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/create-for-user',
        body,
      );

      if (response != null && response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      log.e('GroomerHomeRepository::createBookingForUser::Error: $e');
      return null;
    }
  }

  /// GET /api/groomer-availability
  Future<Map<String, dynamic>?> getGroomerAvailability({
    String? date,
    int? groomerId,
    List<int>? groomerIds,
    String? clientId,
    String? regionId,
    String? storeId,
    int durationMinutes = 60,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final targetDate = date ?? DateTime.now().toIso8601String().split('T').first;
      final cid = clientId ?? groomer?.clientId ?? 'SHEAR-001';
      final rid = regionId ?? groomer?.regionId ?? 'DWG-001';
      final sid = storeId ?? groomer?.storeId ?? 'SHEAR-001';
      final gid = groomerId ?? groomer?.id;

      final queryParams = <String, dynamic>{
        'date': targetDate,
        'ClientID': cid,
        'RegionId': rid,
        'StoreId': sid,
        'durationMinutes': durationMinutes,
      };

      if (gid != null && gid > 0) {
        queryParams['groomerId'] = gid;
      } else if (groomerIds != null && groomerIds.isNotEmpty) {
        queryParams['groomerIds'] = groomerIds.join(',');
      }

      log.d('GroomerHomeRepository::getAvailability::Fetching availability for $targetDate');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-availability',
        query: queryParams,
      );

      if (response != null && response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      log.e('GroomerHomeRepository::getAvailability::Error: $e');
      return null;
    }
  }

  /// GET /api/admin/store-hours or /api/service-hours
  Future<List<StoreServiceHour>> getServiceHours({
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final cId = clientId ?? groomer?.clientId;
      final rId = regionId ?? groomer?.regionId;
      final sId = storeId ?? groomer?.storeId;

      final queryParams = <String, dynamic>{
        if (cId != null && cId.isNotEmpty) 'ClientID': cId,
        if (rId != null && rId.isNotEmpty) 'RegionId': rId,
        if (sId != null && sId.isNotEmpty) 'StoreId': sId,
      };

      log.d('GroomerHomeRepository::getServiceHours::Fetching store operating hours');
      final adminRes = await ServicesLocator.apiRepository.get(
        '/api/admin/store-hours',
        query: queryParams,
      );

      if (adminRes != null && adminRes['data'] is List) {
        final list = adminRes['data'] as List;
        return list
            .map((item) => StoreServiceHour.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // Secondary fallback to /api/service-hours
      final response = await ServicesLocator.apiRepository.get(
        '/api/service-hours',
        query: queryParams,
      );

      if (response != null) {
        final data = response['data'];
        if (data is List) {
          return data
              .map((item) => StoreServiceHour.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (data is Map<String, dynamic> && data['HolidayList'] is List) {
          final list = data['HolidayList'] as List;
          return list
              .map((item) => StoreServiceHour.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getServiceHours::Error: $e');
      return [];
    }
  }

  /// PUT /api/admin/store-hours/:id or POST /api/admin/store-hours
  Future<bool> updateServiceHours(List<StoreServiceHour> hours) async {
    try {
      final groomer = getCurrentGroomer();
      final cId = groomer?.clientId ?? '';
      final rId = groomer?.regionId ?? '';
      final sId = groomer?.storeId ?? '';

      log.d('GroomerHomeRepository::updateServiceHours::Saving ${hours.length} store hours');
      bool allOk = true;

      for (final h in hours) {
        final payload = {
          'dayOfWeek': h.dayOfWeek,
          'isOpen': h.isOpen,
          'startTime': h.startTime,
          'endTime': h.endTime,
          if (cId.isNotEmpty) 'clientId': cId,
          if (rId.isNotEmpty) 'regionId': rId,
          if (sId.isNotEmpty) 'storeId': sId,
        };

        if (h.id != null && h.id! > 0) {
          final res = await ServicesLocator.apiRepository.put(
            '/api/admin/store-hours/${h.id}',
            payload,
          );
          if (!res) allOk = false;
        } else {
          final res = await ServicesLocator.apiRepository.post(
            '/api/admin/store-hours',
            payload,
          );
          if (res == null || res['success'] != true) allOk = false;
        }
      }

      return allOk;
    } catch (e) {
      log.e('GroomerHomeRepository::updateServiceHours::Error: $e');
      return false;
    }
  }

  /// GET /api/admin/groomer-hours
  Future<List<GroomerWorkingHour>> getGroomerHours({
    String? groomerCode,
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final code = groomerCode ?? groomer?.groomerCode ?? '';
      if (code.isEmpty) {
        log.w('GroomerHomeRepository::getGroomerHours::No groomer code available');
        return [];
      }

      final cId = clientId ?? groomer?.clientId;
      final rId = regionId ?? groomer?.regionId;
      final sId = storeId ?? groomer?.storeId;

      final queryParams = <String, dynamic>{
        'groomerCode': code,
        if (cId != null && cId.isNotEmpty) 'ClientID': cId,
        if (rId != null && rId.isNotEmpty) 'RegionId': rId,
        if (sId != null && sId.isNotEmpty) 'StoreId': sId,
      };

      log.d('GroomerHomeRepository::getGroomerHours::Fetching groomer hours for $code');
      final response = await ServicesLocator.apiRepository.get(
        '/api/admin/groomer-hours',
        query: queryParams,
      );

      final breaks = await getGroomerUnavailability(
        groomerCode: code,
        clientId: cId,
        regionId: rId,
        storeId: sId,
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) {
          final hour = GroomerWorkingHour.fromJson(Map<String, dynamic>.from(item as Map));
          final matchingBreaks = breaks.where((b) =>
              b.dayOfWeek.toLowerCase() == hour.dayOfWeek.toLowerCase()).toList();
          return hour.copyWith(breaks: matchingBreaks);
        }).toList();
      }

      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getGroomerHours::Error: $e');
      return [];
    }
  }

  /// PUT /api/admin/groomer-hours/:id or POST /api/admin/groomer-hours
  Future<bool> saveGroomerHours(List<GroomerWorkingHour> hours) async {
    try {
      final groomer = getCurrentGroomer();
      final code = groomer?.groomerCode ?? '';
      final cId = groomer?.clientId ?? '';
      final rId = groomer?.regionId ?? '';
      final sId = groomer?.storeId ?? '';

      log.d('GroomerHomeRepository::saveGroomerHours::Saving ${hours.length} working hours');
      bool allOk = true;

      for (final h in hours) {
        final payload = {
          'groomerCode': h.groomerCode.isNotEmpty ? h.groomerCode : code,
          'dayOfWeek': h.dayOfWeek,
          'isWorking': h.isWorking,
          'startTime': h.startTime,
          'endTime': h.endTime,
          if (cId.isNotEmpty) 'clientId': cId,
          if (rId.isNotEmpty) 'regionId': rId,
          if (sId.isNotEmpty) 'storeId': sId,
        };

        if (h.id != null && h.id! > 0) {
          final res = await ServicesLocator.apiRepository.put(
            '/api/admin/groomer-hours/${h.id}',
            payload,
          );
          if (!res) allOk = false;
        } else {
          final res = await ServicesLocator.apiRepository.post(
            '/api/admin/groomer-hours',
            payload,
          );
          if (res == null || res['success'] != true) allOk = false;
        }

        // Also persist any newly added breaks for this day
        for (final b in h.breaks) {
          if (b.id == null || b.id! <= 0) {
            await createGroomerBreak(b.copyWith(
              groomerCode: code,
              clientId: cId,
              regionId: rId,
              storeId: sId,
            ));
          }
        }
      }

      return allOk;
    } catch (e) {
      log.e('GroomerHomeRepository::saveGroomerHours::Error: $e');
      return false;
    }
  }

  /// GET /api/admin/groomer-unavailability
  Future<List<GroomerBreak>> getGroomerUnavailability({
    String? groomerCode,
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final code = groomerCode ?? groomer?.groomerCode ?? 'G001';
      final queryParams = <String, dynamic>{
        'groomerCode': code,
        'ClientID': clientId ?? groomer?.clientId ?? 'SHEAR-001',
        'RegionId': regionId ?? groomer?.regionId ?? 'DWG-001',
        'StoreId': storeId ?? groomer?.storeId ?? 'SHEAR-001',
      };

      log.d('GroomerHomeRepository::getGroomerUnavailability::Fetching unavailability for $code');
      final response = await ServicesLocator.apiRepository.get(
        '/api/admin/groomer-unavailability',
        query: queryParams,
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list
            .map((item) => GroomerBreak.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getGroomerUnavailability::Error: $e');
      return [];
    }
  }

  /// POST /api/admin/groomer-unavailability
  Future<GroomerBreak?> createGroomerBreak(GroomerBreak groomerBreak) async {
    try {
      final groomer = getCurrentGroomer();
      final payload = {
        'groomerCode': groomerBreak.groomerCode.isNotEmpty
            ? groomerBreak.groomerCode
            : (groomer?.groomerCode ?? 'G001'),
        'dayOfWeek': groomerBreak.dayOfWeek,
        'startTime': groomerBreak.startTime,
        'endTime': groomerBreak.endTime,
        'reason': groomerBreak.reason,
        'leaveType': groomerBreak.leaveType,
        'clientId': groomerBreak.clientId ?? groomer?.clientId ?? 'SHEAR-001',
        'regionId': groomerBreak.regionId ?? groomer?.regionId ?? 'DWG-001',
        'storeId': groomerBreak.storeId ?? groomer?.storeId ?? 'SHEAR-001',
      };

      log.d('GroomerHomeRepository::createGroomerBreak::Creating break for ${groomerBreak.dayOfWeek}');
      final response = await ServicesLocator.apiRepository.post(
        '/api/admin/groomer-unavailability',
        payload,
      );

      if (response != null && response['data'] != null) {
        return GroomerBreak.fromJson(Map<String, dynamic>.from(response['data'] as Map));
      }
      return groomerBreak;
    } catch (e) {
      log.e('GroomerHomeRepository::createGroomerBreak::Error: $e');
      return null;
    }
  }

  /// DELETE /api/admin/groomer-unavailability/:id
  Future<bool> deleteGroomerBreak(int scheduleRecordId) async {
    try {
      log.d('GroomerHomeRepository::deleteGroomerBreak::Deleting break $scheduleRecordId');
      final response = await ServicesLocator.apiRepository.delete(
        '/api/admin/groomer-unavailability/$scheduleRecordId',
      );
      return response;
    } catch (e) {
      log.e('GroomerHomeRepository::deleteGroomerBreak::Error: $e');
      return false;
    }
  }

  /// GET /api/holidays
  Future<List<StoreHoliday>> getHolidays({
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final queryParams = <String, dynamic>{
        'ClientID': clientId ?? groomer?.clientId ?? 'SHEAR-001',
        'RegionId': regionId ?? groomer?.regionId ?? 'DWG-001',
        'StoreId': storeId ?? groomer?.storeId ?? 'SHEAR-001',
      };

      log.d('GroomerHomeRepository::getHolidays::Fetching store holidays');
      final response = await ServicesLocator.apiRepository.get(
        '/api/holidays',
        query: queryParams,
      );

      if (response != null) {
        final data = response['data'];
        if (data is List) {
          return data
              .map((item) => StoreHoliday.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (data is Map<String, dynamic> && data['HolidayList'] is List) {
          final list = data['HolidayList'] as List;
          return list
              .map((item) => StoreHoliday.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getHolidays::Error: $e');
      return [];
    }
  }

  /// GET /api/notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      log.d('GroomerHomeRepository::getNotifications::Fetching notifications');
      final response = await ServicesLocator.apiRepository.get(
        '/api/notifications',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getNotifications::Error: $e');
      return [];
    }
  }

  /// PUT /api/notifications/:id/read
  Future<bool> markNotificationRead(int notificationId) async {
    try {
      log.d('GroomerHomeRepository::markNotificationRead::Marking notification #$notificationId as read');
      final response = await ServicesLocator.apiRepository.putData(
        '/api/notifications/$notificationId/read',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerHomeRepository::markNotificationRead::Error: $e');
      return false;
    }
  }

  /// PUT /api/notifications/read-all
  Future<bool> markAllNotificationsRead() async {
    try {
      log.d('GroomerHomeRepository::markAllNotificationsRead::Marking all notifications as read');
      final response = await ServicesLocator.apiRepository.putData(
        '/api/notifications/read-all',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerHomeRepository::markAllNotificationsRead::Error: $e');
      return false;
    }
  }

  /// POST /api/notifications/device-token
  Future<bool> registerDeviceToken({
    required String pushToken,
    String? platform,
  }) async {
    try {
      final deviceId = await ServicesLocator.deviceIdService.getDeviceId();
      final resolvedPlatform = platform ?? PushNotificationService.currentPlatform;
      log.i('[FCM] Firebase Project: ${PushNotificationService.firebaseProjectId}');
      log.i('[FCM] Device ID: ${PushNotificationService.maskDeviceId(deviceId)}');
      log.i('[FCM] FCM Token: ${PushNotificationService.maskToken(pushToken)}');
      log.i('[FCM] Platform: $resolvedPlatform');
      log.i('[FCM] Registering device token...');
      final response = await ServicesLocator.apiRepository.post(
        '/api/notifications/device-token',
        {
          'deviceId': deviceId,
          'pushToken': pushToken,
          'platform': resolvedPlatform,
        },
      );
      final success = response != null && response['success'] == true;
      if (success) {
        log.i('[FCM] Device token registration successful');
      } else {
        final statusCode = response?['statusCode'] ?? response?['code'] ?? 400;
        final message = response?['message'] ?? 'Unknown error';
        log.e('[FCM] Device token registration failed: Status $statusCode - $message');
      }
      return success;
    } catch (e) {
      log.e('[FCM] Device token registration failed with error: $e');
      return false;
    }
  }

  /// Connects to the Socket.IO real-time notification service.
  Future<void> connectRealtimeNotifications({
    String? token,
    String? serverUrl,
  }) async {
    try {
      log.d('GroomerHomeRepository::connectRealtimeNotifications::Connecting socket');
      await ServicesLocator.groomerSocketService.connect(
        token: token,
        serverUrl: serverUrl,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::connectRealtimeNotifications::Error: $e');
    }
  }

  /// Disconnects from the Socket.IO real-time notification service.
  void disconnectRealtimeNotifications() {
    try {
      log.d('GroomerHomeRepository::disconnectRealtimeNotifications::Disconnecting socket');
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        ServicesLocator.groomerSocketService.disconnect();
      }
    } catch (e) {
      log.e('GroomerHomeRepository::disconnectRealtimeNotifications::Error: $e');
    }
  }

  /// Stream of incoming real-time notifications.
  Stream<AppNotification> get realtimeNotificationStream =>
      ServicesLocator.groomerSocketService.onNotification;

  /// Stream of real-time socket connection state changes.
  Stream<bool> get realtimeConnectionStatusStream =>
      ServicesLocator.groomerSocketService.onConnectionStatus;

  GroomerUser? getCurrentGroomer() {
    try {
      final data = ServicesLocator.sessionService.getGroomerUser();
      if (data == null) return null;
      return GroomerUser.fromJson(data);
    } catch (e) {
      log.e('GroomerHomeRepository::getCurrentGroomer::Error: $e');
      return null;
    }
  }

  /// GET /api/groomer-auth/groomers (Dynamically loads salon groomers strictly from backend API)
  Future<List<SalonGroomer>> getSalonGroomers() async {
    try {
      log.d('GroomerHomeRepository::getSalonGroomers::Loading from /api/groomer-auth/groomers');
      var response = await ServicesLocator.apiRepository.get('/api/groomer-auth/groomers');

      // Fallback to /api/groomers if /api/groomer-auth/groomers returns null or missing data
      if (response == null || !response.containsKey('data')) {
        response = await ServicesLocator.apiRepository.get('/api/groomers');
      }

      if (response == null || !response.containsKey('data')) {
        throw Exception('Failed to fetch groomers from /api/groomer-auth/groomers');
      }

      final raw = response['data'];
      final List<SalonGroomer> list = [];

      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(SalonGroomer.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } else if (raw is Map) {
        final rawMap = Map<String, dynamic>.from(raw);
        // Check Groomers array (case-insensitive keys)
        final groomersList = rawMap['Groomers'] ?? rawMap['groomers'] ?? rawMap['data'];
        if (groomersList is List) {
          for (final item in groomersList) {
            if (item is Map) {
              list.add(SalonGroomer.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        // Check Bathers array if present
        final bathersList = rawMap['Bathers'] ?? rawMap['bathers'];
        if (bathersList is List) {
          for (final item in bathersList) {
            if (item is Map) {
              list.add(SalonGroomer.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }

      log.d('GroomerHomeRepository::getSalonGroomers::Loaded ${list.length} groomers');
      return list;
    } catch (error) {
      log.e('GroomerHomeRepository::getSalonGroomers::Error: $error');
      rethrow;
    }
  }

  /// GET /api/service-packages
  Future<BookingServicesResult> getBookingServices() async {
    try {
      log.d('GroomerHomeRepository::getBookingServices::Loading from /api/service-packages');
      return await ServicesLocator.serviceRepository.getBookingServices();
    } catch (error) {
      log.e('GroomerHomeRepository::getBookingServices::Error: $error');
      rethrow;
    }
  }

  /// GET /api/groomer-auth/groomers/{groomerId}/availability
  /// Query params: date, serviceId, packageId, addOnIds (comma-separated)
  /// Fallback: POST /api/availability
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) async {
    try {
      final currentGroomer = getCurrentGroomer();
      int gid = 1;
      if (groomerId != null && groomerId > 0) {
        gid = groomerId;
      } else if (currentGroomer != null) {
        final code = currentGroomer.groomerCode.toUpperCase();
        if (code.startsWith('B')) {
          final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
          gid = (int.tryParse(digits) ?? 1) + 3;
        } else {
          final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
          gid = int.tryParse(digits) ?? 1;
        }
        if (gid < 1) {
          gid = 1;
        }
      }
      log.d('GroomerHomeRepository::getAvailability::Checking availability for groomer $gid on $date');

      final queryParams = <String, dynamic>{
        'date': date,
        if (serviceId != null && serviceId > 0) 'serviceId': serviceId,
        if (packageId != null && packageId > 0) 'packageId': packageId,
        if (addOnIds != null && addOnIds.isNotEmpty) 'addOnIds': addOnIds.join(','),
      };

      // Call GET /api/groomer-auth/groomers/{groomerId}/availability
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/groomers/$gid/availability',
        query: queryParams,
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        return response;
      }

      // Secondary fallback to POST /api/availability
      return await ServicesLocator.bookingRepository.getAvailability(
        date: date,
        serviceId: serviceId,
        packageId: packageId,
        addOnIds: addOnIds,
        groomerId: groomerId,
      );
    } catch (error) {
      log.w('GroomerHomeRepository::getAvailability::Primary availability check failed, attempting fallback: $error');
      try {
        return await ServicesLocator.bookingRepository.getAvailability(
          date: date,
          serviceId: serviceId,
          packageId: packageId,
          addOnIds: addOnIds,
          groomerId: groomerId,
        );
      } catch (fallbackError) {
        log.e('GroomerHomeRepository::getAvailability fallback error: $fallbackError');
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    try {
      log.d('GroomerHomeRepository::logout::Logging out groomer');
      disconnectRealtimeNotifications();
      await ServicesLocator.sessionService.clearGroomerSession();
    } catch (e) {
      log.e('GroomerHomeRepository::logout::Error: $e');
    }
  }
}
