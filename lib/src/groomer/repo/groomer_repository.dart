import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_login_response.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_user.dart';
typedef GroomerAuthRepository = GroomerRepository;

class GroomerRepository {
  final Logger log = Logger();

  Future<void> initialize() async {
    log.d('GroomerRepository::initialize::Initialized');
  }

  /// POST /api/groomer-auth/login
  ///
  /// Logs in a groomer staff member.
  /// Request body: {"email": email, "password": password}
  Future<GroomerLoginResponse?> login({
    required String email,
    required String password,
  }) async {
    try {
      log.d('GroomerRepository::login::Logging in groomer: $email');

      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/login',
        {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response == null || response['success'] != true || response['data'] == null) {
        final message = response?['message'] ?? 'Login failed. Please check your credentials.';
        log.w('GroomerRepository::login::Failed: $message');
        throw Exception(message);
      }

      final data = response['data'] as Map<String, dynamic>;
      final loginResponse = GroomerLoginResponse.fromJson(data);

      await ServicesLocator.sessionService.saveGroomerSession(
        accessToken: loginResponse.accessToken,
        refreshToken: loginResponse.refreshToken,
        groomerData: loginResponse.groomer.toJson(),
      );

      // If must change password, store temporary credentials for setup-account flow
      if (loginResponse.mustChangePassword) {
        final resolvedTempLoginId = (loginResponse.tempLoginId != null && loginResponse.tempLoginId!.trim().isNotEmpty)
            ? loginResponse.tempLoginId!.trim()
            : (email.trim().isNotEmpty ? email.trim() : loginResponse.groomer.email);
        final resolvedTempPassword = (loginResponse.tempPassword != null && loginResponse.tempPassword!.isNotEmpty)
            ? loginResponse.tempPassword!
            : password;

        await ServicesLocator.sessionService.saveTempGroomerCredentials(
          tempLoginId: resolvedTempLoginId,
          tempPassword: resolvedTempPassword,
        );
      }

      // Connect real-time notifications on login
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        try {
          await ServicesLocator.groomerSocketService.connect(token: loginResponse.accessToken);
        } catch (e) {
          log.e('GroomerRepository::login::Socket connection error: $e');
        }
      }

      log.d('GroomerRepository::login::Login successful for ${loginResponse.groomer.fullName} (mustChangePassword: ${loginResponse.mustChangePassword})');
      return loginResponse;
    } catch (error) {
      log.e('GroomerRepository::login::Error: $error');
      rethrow;
    }
  }

  /// POST /api/groomer-auth/setup-account
  ///
  /// One-time account setup when mustChangePassword == true.
  Future<GroomerLoginResponse?> setupAccount({
    required String tempLoginId,
    required String tempPassword,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      log.d('GroomerRepository::setupAccount::Setting up groomer account for $email');

      if (tempPassword.trim().isEmpty) {
        const errorMsg = 'tempPassword is required and cannot be empty.';
        log.e('GroomerRepository::setupAccount::Validation Error: $errorMsg');
        throw Exception(errorMsg);
      }
      if (tempLoginId.trim().isEmpty) {
        const errorMsg = 'tempLoginId is required and cannot be empty.';
        log.e('GroomerRepository::setupAccount::Validation Error: $errorMsg');
        throw Exception(errorMsg);
      }

      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/setup-account',
        {
          'tempLoginId': tempLoginId.trim(),
          'tempPassword': tempPassword,
          'email': email.trim(),
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );

      if (response == null || response['success'] != true || response['data'] == null) {
        final message = response?['message'] ?? 'Account setup failed. Please try again.';
        log.w('GroomerRepository::setupAccount::Failed: $message');
        throw Exception(message);
      }

      final data = response['data'] as Map<String, dynamic>;
      final loginResponse = GroomerLoginResponse.fromJson(data);

      await ServicesLocator.sessionService.saveGroomerSession(
        accessToken: loginResponse.accessToken,
        refreshToken: loginResponse.refreshToken,
        groomerData: loginResponse.groomer.toJson(),
      );

      // Connect real-time notifications on account setup
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        try {
          await ServicesLocator.groomerSocketService.connect(token: loginResponse.accessToken);
        } catch (e) {
          log.e('GroomerRepository::setupAccount::Socket connection error: $e');
        }
      }

      log.d('GroomerRepository::setupAccount::Setup successful for ${loginResponse.groomer.fullName}');
      return loginResponse;
    } catch (error) {
      log.e('GroomerRepository::setupAccount::Error: $error');
      rethrow;
    }
  }

  /// GET /api/groomer-auth/profile
  ///
  /// Returns the current groomer profile.
  Future<GroomerUser?> getProfile() async {
    try {
      log.d('GroomerRepository::getProfile::Fetching groomer profile');

      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/profile',
      );

      if (response == null || response['success'] != true || response['data'] == null) {
        log.w('GroomerRepository::getProfile::Failed to fetch profile');
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
      log.e('GroomerRepository::getProfile::Error: $error');
      return getCurrentGroomer();
    }
  }

  /// PUT /api/groomer-auth/profile
  ///
  /// Updates groomer profile fields (names, mobile, multiBookingEnabled, slotBookingLimit, photo).
  Future<GroomerUser?> updateProfile({
    String? firstName,
    String? lastName,
    String? mobile,
    bool? multiBookingEnabled,
    int? slotBookingLimit,
    String? photoPath,
  }) async {
    try {
      log.d('GroomerRepository::updateProfile::Updating groomer profile');

      final current = getCurrentGroomer();
      final body = <String, dynamic>{
        'firstName': firstName ?? current?.firstName ?? '',
        'lastName': lastName ?? current?.lastName ?? '',
        'mobile': mobile ?? current?.mobile ?? '',
        'multiBookingEnabled': multiBookingEnabled ?? current?.multiBookingEnabled ?? false,
        'slotBookingLimit': slotBookingLimit ?? current?.slotBookingLimit ?? 1,
      };

      Map<String, dynamic>? response;
      if (photoPath != null && photoPath.isNotEmpty && !photoPath.startsWith('http')) {
        try {
          final fileName = photoPath.split(RegExp(r'[/\\]')).last;
          final formData = FormData.fromMap({
            ...body,
            'avatar': await MultipartFile.fromFile(photoPath, filename: fileName),
            'profilePicture': await MultipartFile.fromFile(photoPath, filename: fileName),
          });
          response = await ServicesLocator.apiRepository.postMultipart(
            '/api/groomer-auth/profile',
            formData,
          );
          if (response == null || response['success'] != true) {
            await ServicesLocator.apiRepository.putMultipart(
              '/api/groomer-auth/profile',
              formData,
            );
          }
        } catch (e) {
          log.w('GroomerRepository::updateProfile::Multipart upload error: $e');
        }
      }

      if (response == null) {
        response = await ServicesLocator.apiRepository.post(
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
      } else if (response['data'] != null) {
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

      return current;
    } catch (error) {
      log.e('GroomerRepository::updateProfile::Error: $error');
      rethrow;
    }
  }

  /// POST /api/groomer-auth/refresh-token
  ///
  /// Refreshes the groomer access token.
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await ServicesLocator.sessionService.getGroomerRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      log.d('GroomerRepository::refreshToken::Refreshing groomer token');

      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/refresh-token',
        {
          'refreshToken': refreshToken,
        },
      );

      if (response == null || response['success'] != true || response['data'] == null) {
        return false;
      }

      final data = response['data'] as Map<String, dynamic>;
      final newAccessToken = data['accessToken']?.toString();
      final newRefreshToken = data['refreshToken']?.toString() ?? refreshToken;

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        final currentGroomer = ServicesLocator.sessionService.getGroomerUser() ?? {};
        await ServicesLocator.sessionService.saveGroomerSession(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          groomerData: currentGroomer,
        );

        // Reconnect socket with refreshed token
        if (ServicesLocator.isGroomerSocketServiceRegistered) {
          try {
            await ServicesLocator.groomerSocketService.connect(
              token: newAccessToken,
            );
          } catch (e) {
            log.e(
              'GroomerRepository::refreshToken::Socket reconnection error: $e',
            );
          }
        }

        return true;
      }
      return false;
    } catch (error) {
      log.e('GroomerRepository::refreshToken::Error: $error');
      return false;
    }
  }

  /// GET /api/groomer-auth/bookings/upcoming
  ///
  /// Returns upcoming bookings for this groomer.
  Future<List<GroomerBooking>> getUpcomingBookings() async {
    try {
      log.d('GroomerRepository::getUpcomingBookings::Fetching upcoming bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/upcoming',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerRepository::getUpcomingBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/pending
  ///
  /// Returns pending booking requests for this groomer.
  Future<List<GroomerBooking>> getPendingBookings() async {
    try {
      log.d('GroomerRepository::getPendingBookings::Fetching pending bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/pending',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerRepository::getPendingBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/past
  ///
  /// Returns past and completed bookings for this groomer.
  Future<List<GroomerBooking>> getPastBookings() async {
    try {
      log.d('GroomerRepository::getPastBookings::Fetching past bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/past',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerRepository::getPastBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/cancelled
  ///
  /// Returns cancelled bookings for this groomer.
  Future<List<GroomerBooking>> getCancelledBookings() async {
    try {
      log.d('GroomerRepository::getCancelledBookings::Fetching cancelled bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/cancelled',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerRepository::getCancelledBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/cancellation-requests
  ///
  /// Returns user cancellation requests.
  Future<List<GroomerBooking>> getCancellationRequests() async {
    try {
      log.d('GroomerRepository::getCancellationRequests::Fetching cancellation requests');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/cancellation-requests',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerRepository::getCancellationRequests::Error: $e');
      return [];
    }
  }

  /// POST /api/groomer-auth/bookings/:id/approve
  ///
  /// Approves a pending booking.
  Future<bool> approveBooking(int bookingId) async {
    try {
      log.d('GroomerRepository::approveBooking::Approving booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/approve',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::approveBooking::Error: $e');
      return false;
    }
  }

  /// POST /api/groomer-auth/bookings/:id/reject
  ///
  /// Rejects a pending booking.
  Future<bool> rejectBooking(int bookingId) async {
    try {
      log.d('GroomerRepository::rejectBooking::Rejecting booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/reject',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::rejectBooking::Error: $e');
      return false;
    }
  }

  /// POST /api/groomer-auth/bookings/:id/start
  ///
  /// Starts a confirmed appointment -> status becomes in_progress.
  Future<bool> startBooking(int bookingId) async {
    try {
      log.d('GroomerRepository::startBooking::Starting booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/start',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::startBooking::Error: $e');
      return false;
    }
  }

  /// POST /api/groomer-auth/bookings/:id/complete
  ///
  /// Completes an in-progress appointment -> status becomes completed.
  Future<bool> completeBooking(int bookingId) async {
    try {
      log.d('GroomerRepository::completeBooking::Completing booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/complete',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::completeBooking::Error: $e');
      return false;
    }
  }

  /// POST /api/groomer-auth/bookings/:id/approve-cancellation
  ///
  /// Approves customer cancellation.
  Future<bool> approveCancellation(int bookingId) async {
    try {
      log.d('GroomerRepository::approveCancellation::Approving cancellation #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/approve-cancellation',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::approveCancellation::Error: $e');
      return false;
    }
  }

  /// POST /api/groomer-auth/bookings/:id/reject-cancellation
  ///
  /// Rejects customer cancellation.
  Future<bool> rejectCancellation(int bookingId) async {
    try {
      log.d('GroomerRepository::rejectCancellation::Rejecting cancellation #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/reject-cancellation',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::rejectCancellation::Error: $e');
      return false;
    }
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
      log.d('GroomerRepository::searchCustomers::Searching customers (search: $query, limit: $limit, offset: $actualOffset)');
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
      log.e('GroomerRepository::searchCustomers::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/customers/:userId/pets
  ///
  /// Fetches pets for a specific customer userId using the staff's session.
  Future<List<CustomerPetSummary>> getCustomerPets(int userId) async {
    try {
      log.d('GroomerRepository::getCustomerPets::Fetching pets for customer userId: $userId');

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
      log.e('GroomerRepository::getCustomerPets::Error: $e');
      return [];
    }
  }

  /// POST /api/groomer-auth/bookings/create-for-user
  ///
  /// Groomer creates a confirmed booking on behalf of a user.
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

      log.d('GroomerRepository::createBookingForUser::Creating booking for user $userId (groomerId: ${groomerId ?? groomer?.id})');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/create-for-user',
        body,
      );

      if (response != null && response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      log.e('GroomerRepository::createBookingForUser::Error: $e');
      return null;
    }
  }

  /// GET /api/groomer-availability
  ///
  /// Returns availability slots for one or multiple groomers.
  Future<Map<String, dynamic>?> getAvailability({
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

      log.d('GroomerRepository::getAvailability::Fetching availability for $targetDate');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-availability',
        query: queryParams,
      );

      if (response != null && response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      log.e('GroomerRepository::getAvailability::Error: $e');
      return null;
    }
  }

  /// GET /api/service-hours
  ///
  /// Returns store service operating hours.
  Future<List<StoreServiceHour>> getServiceHours({
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

      log.d('GroomerRepository::getServiceHours::Fetching store service hours');
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
      log.e('GroomerRepository::getServiceHours::Error: $e');
      return [];
    }
  }

  /// GET /api/holidays
  ///
  /// Returns store holiday calendar.
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

      log.d('GroomerRepository::getHolidays::Fetching store holidays');
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
      log.e('GroomerRepository::getHolidays::Error: $e');
      return [];
    }
  }

  /// GET /api/notifications
  ///
  /// Fetches real-time notification list for the authenticated groomer.
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      log.d('GroomerRepository::getNotifications::Fetching notifications');
      final response = await ServicesLocator.apiRepository.get(
        '/api/notifications',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerRepository::getNotifications::Error: $e');
      return [];
    }
  }

  /// PUT /api/notifications/:id/read
  ///
  /// Marks a specific notification as read.
  Future<bool> markNotificationRead(int notificationId) async {
    try {
      log.d('GroomerRepository::markNotificationRead::Marking notification #$notificationId as read');
      final response = await ServicesLocator.apiRepository.putData(
        '/api/notifications/$notificationId/read',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::markNotificationRead::Error: $e');
      return false;
    }
  }

  /// PUT /api/notifications/read-all
  ///
  /// Marks all notifications as read.
  Future<bool> markAllNotificationsRead() async {
    try {
      log.d('GroomerRepository::markAllNotificationsRead::Marking all notifications as read');
      final response = await ServicesLocator.apiRepository.putData(
        '/api/notifications/read-all',
        {},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::markAllNotificationsRead::Error: $e');
      return false;
    }
  }

  /// POST /api/notifications/device-token
  ///
  /// Registers the Groomer's device push token.
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

  GroomerUser? getCurrentGroomer() {
    try {
      final data = ServicesLocator.sessionService.getGroomerUser();
      if (data == null) return null;
      return GroomerUser.fromJson(data);
    } catch (e) {
      log.e('GroomerRepository::getCurrentGroomer::Error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      log.d('GroomerRepository::logout::Logging out groomer');
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        ServicesLocator.groomerSocketService.disconnect();
      }
      await ServicesLocator.sessionService.clearGroomerSession();
    } catch (e) {
      log.e('GroomerRepository::logout::Error: $e');
    }
  }
}
