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

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/auth/login',
          {
            'email': email.trim(),
            'password': password,
          },
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true || response['data'] == null) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/login',
          {
            'email': email.trim(),
            'password': password,
          },
        );
      }

      if (response == null || response['success'] != true || response['data'] == null) {
        final message = response?['message'] ?? 'Login failed. Please check your credentials.';
        log.w('GroomerRepository::login::Failed: $message');
        throw Exception(message);
      }

      final data = response['data'] as Map<String, dynamic>;
      final loginResponse = GroomerLoginResponse.fromJson(data);

      if (ServicesLocator.sessionService.isLoggedIn) {
        await ServicesLocator.sessionService.clearSession();
        if (ServicesLocator.isCustomerSocketServiceRegistered) {
          ServicesLocator.customerSocketService.disconnect();
        }
      }

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
          ServicesLocator.groomerSocketService.joinGroomerRooms(loginResponse.groomer.toJson());
        } catch (e) {
          log.e('GroomerRepository::login::Socket connection error: $e');
        }
      }

      // Register FCM device token on login
      if (ServicesLocator.isPushNotificationServiceRegistered) {
        try {
          await ServicesLocator.pushNotificationService.fetchAndRegisterToken(isGroomer: true);
        } catch (e) {
          log.e('GroomerRepository::login::FCM registration error: $e');
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
          ServicesLocator.groomerSocketService.joinGroomerRooms(loginResponse.groomer.toJson());
        } catch (e) {
          log.e('GroomerRepository::setupAccount::Socket connection error: $e');
        }
      }

      // Register FCM device token on account setup
      if (ServicesLocator.isPushNotificationServiceRegistered) {
        try {
          await ServicesLocator.pushNotificationService.fetchAndRegisterToken(isGroomer: true);
        } catch (e) {
          log.e('GroomerRepository::setupAccount::FCM registration error: $e');
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
      final current = getCurrentGroomer();

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.get(
          '/api/common/groomer/profile',
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.get(
          '/api/groomer-auth/profile',
        );
      }

      if (response != null && response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        var groomer = GroomerUser.fromJson(data);
        if (groomer.avatarUrl == null && current?.avatarUrl != null) {
          groomer = groomer.copyWith(
            avatar: current!.avatarUrl,
            profilePicture: current.avatarUrl,
          );
        }
        await ServicesLocator.sessionService.saveGroomerUser(groomer.toJson());
        return groomer;
      }

      if (current != null && (current.id > 0 || current.groomerCode.isNotEmpty)) {
        final adminResp = await ServicesLocator.apiRepository.get(
          '/api/admin/groomers',
          query: {
            'ClientID': current.clientId.isNotEmpty ? current.clientId : 'SHEAR-001',
            'RegionId': current.regionId.isNotEmpty ? current.regionId : 'DWG-001',
            'StoreId': current.storeId.isNotEmpty ? current.storeId : 'SHEAR-001',
          },
        );
        if (adminResp != null && adminResp['success'] == true && adminResp['data'] is List) {
          final list = adminResp['data'] as List;
          for (final item in list) {
            if (item is Map) {
              final candidate = GroomerUser.fromJson(Map<String, dynamic>.from(item));
              if ((current.id > 0 && candidate.id == current.id) ||
                  (current.groomerCode.isNotEmpty &&
                      candidate.groomerCode.toUpperCase() == current.groomerCode.toUpperCase())) {
                final merged = candidate.copyWith(
                  avatar: candidate.avatarUrl ?? current.avatarUrl,
                  profilePicture: candidate.avatarUrl ?? current.avatarUrl,
                );
                await ServicesLocator.sessionService.saveGroomerUser(merged.toJson());
                return merged;
              }
            }
          }
        }
      }

      log.w('GroomerRepository::getProfile::Using cached groomer profile');
      return current;
    } catch (error) {
      log.e('GroomerRepository::getProfile::Error: $error');
      return getCurrentGroomer();
    }
  }

  /// PUT /api/groomer-auth/profile
  ///
  /// Updates groomer profile fields (names, mobile, highlights, multiBookingEnabled, slotBookingLimit, photo).
  Future<GroomerUser?> updateProfile({
    String? firstName,
    String? lastName,
    String? mobile,
    String? highlights,
    String? role,
    bool? multiBookingEnabled,
    int? slotBookingLimit,
    String? photoPath,
  }) async {
    try {
      log.d('GroomerRepository::updateProfile::Updating groomer profile');

      final current = getCurrentGroomer();
      final resolvedFirstName = (firstName ?? current?.firstName ?? '').trim();
      final resolvedLastName = (lastName ?? current?.lastName ?? '').trim();
      final resolvedMobile = (mobile ?? current?.mobile ?? '').trim();
      final resolvedHighlights = (highlights ?? current?.highlights ?? '').trim();
      final resolvedRole = (role ?? current?.role ?? 'Groomer').trim();
      final resolvedMultiBooking = multiBookingEnabled ?? current?.multiBookingEnabled ?? false;
      final resolvedSlotLimit = slotBookingLimit ?? current?.slotBookingLimit ?? 1;

      if (resolvedFirstName.isEmpty) {
        throw Exception('First name is required.');
      }
      if (resolvedLastName.isEmpty) {
        throw Exception('Last name is required.');
      }

      Map<String, dynamic>? adminData;
      final initialId = current?.id ?? 0;
      final initialEmail = (current?.email ?? '').trim();
      if (initialId > 0) {
        final adminBody = <String, dynamic>{
          'firstName': resolvedFirstName,
          'lastName': resolvedLastName,
          if (initialEmail.isNotEmpty) 'email': initialEmail,
          'mobile': resolvedMobile,
          'role': resolvedRole.isNotEmpty ? resolvedRole : 'Groomer',
          'highlights': resolvedHighlights,
          'multiBookingEnabled': resolvedMultiBooking,
          'slotBookingLimit': resolvedSlotLimit,
        };
        final adminResp = await ServicesLocator.apiRepository.putData(
          '/api/admin/groomers/$initialId',
          adminBody,
        );
        if (adminResp != null && adminResp['success'] == true && adminResp['data'] is Map) {
          adminData = Map<String, dynamic>.from(adminResp['data'] as Map);
        }
      }

      final body = <String, dynamic>{
        'firstName': resolvedFirstName,
        'lastName': resolvedLastName,
        'mobile': resolvedMobile,
        'highlights': resolvedHighlights,
        'role': resolvedRole,
        'multiBookingEnabled': resolvedMultiBooking,
        'slotBookingLimit': resolvedSlotLimit,
      };

      final response = await ServicesLocator.apiRepository.putData(
        '/api/groomer-auth/profile',
        body,
      );

      Map<String, dynamic>? responseData;
      if (response != null && response['success'] == true && response['data'] is Map) {
        responseData = Map<String, dynamic>.from(response['data'] as Map);
      }

      final resolvedId = (responseData != null
              ? int.tryParse(responseData['id']?.toString() ?? '')
              : null) ??
          initialId;
      final resolvedEmail = (responseData?['email']?.toString() ?? initialEmail).trim();

      if (adminData == null && resolvedId > 0 && initialId <= 0) {
        final adminBody = <String, dynamic>{
          'firstName': resolvedFirstName,
          'lastName': resolvedLastName,
          if (resolvedEmail.isNotEmpty) 'email': resolvedEmail,
          'mobile': resolvedMobile,
          'role': resolvedRole.isNotEmpty ? resolvedRole : 'Groomer',
          'highlights': resolvedHighlights,
          'multiBookingEnabled': resolvedMultiBooking,
          'slotBookingLimit': resolvedSlotLimit,
        };
        final adminResp = await ServicesLocator.apiRepository.putData(
          '/api/admin/groomers/$resolvedId',
          adminBody,
        );
        if (adminResp != null && adminResp['success'] == true && adminResp['data'] is Map) {
          adminData = Map<String, dynamic>.from(adminResp['data'] as Map);
        }
      }

      final bool primarySuccess = response != null && response['success'] == true;
      final bool adminSuccess = adminData != null;

      if (!primarySuccess && !adminSuccess) {
        final errorMsg = response?['message']?.toString() ??
            'Failed to update profile. Please check your connection and try again.';
        throw Exception(errorMsg);
      }

      final mergedMap = <String, dynamic>{
        if (current != null) ...current.toJson(),
        if (responseData != null) ...responseData,
        if (adminData != null) ...adminData,
        'firstName': resolvedFirstName,
        'lastName': resolvedLastName,
        'mobile': resolvedMobile,
        'highlights': resolvedHighlights,
        'role': resolvedRole.isNotEmpty ? resolvedRole : (current?.role ?? 'Groomer'),
        'multiBookingEnabled': resolvedMultiBooking,
        'slotBookingLimit': resolvedSlotLimit,
      };

      if (photoPath != null && photoPath.trim().isNotEmpty) {
        final serverAvatar = mergedMap['avatar']?.toString() ??
            mergedMap['profilePicture']?.toString();
        if (serverAvatar == null ||
            serverAvatar.trim().isEmpty ||
            !photoPath.trim().startsWith('http')) {
          mergedMap['avatar'] = photoPath.trim();
          mergedMap['profilePicture'] = photoPath.trim();
        }
      }

      final updatedGroomer = GroomerUser.fromJson(mergedMap);
      await ServicesLocator.sessionService.saveGroomerUser(updatedGroomer.toJson());

      final refreshed = await getProfile();
      if (refreshed != null) {
        final finalGroomer = refreshed.copyWith(
          firstName: resolvedFirstName,
          lastName: resolvedLastName,
          mobile: resolvedMobile,
          highlights: highlights != null
              ? resolvedHighlights
              : (refreshed.highlights.isNotEmpty ? refreshed.highlights : resolvedHighlights),
          multiBookingEnabled: resolvedMultiBooking,
          slotBookingLimit: resolvedSlotLimit,
          avatar: updatedGroomer.avatarUrl ?? refreshed.avatarUrl,
          profilePicture: updatedGroomer.avatarUrl ?? refreshed.avatarUrl,
        );
        await ServicesLocator.sessionService.saveGroomerUser(finalGroomer.toJson());
        return finalGroomer;
      }

      return updatedGroomer;
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

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/auth/refresh-token',
          {
            'refreshToken': refreshToken,
          },
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true || response['data'] == null) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/refresh-token',
          {
            'refreshToken': refreshToken,
          },
        );
      }

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

  Future<Map<String, dynamic>?> _getGroomerBookingEndpoint(String subpath) async {
    try {
      final res = await ServicesLocator.apiRepository.get(
        '/api/common/groomer/bookings/$subpath',
      );
      if (res != null && res['data'] != null) return res;
    } catch (_) {}
    return await ServicesLocator.apiRepository.get(
      '/api/groomer-auth/bookings/$subpath',
    );
  }

  /// GET /api/common/groomer/bookings/upcoming
  ///
  /// Returns upcoming bookings for this groomer.
  Future<List<GroomerBooking>> getUpcomingBookings() async {
    try {
      log.d('GroomerRepository::getUpcomingBookings::Fetching upcoming bookings');
      final response = await _getGroomerBookingEndpoint('upcoming');

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

  /// GET /api/common/groomer/bookings/pending
  ///
  /// Returns pending booking requests for this groomer.
  Future<List<GroomerBooking>> getPendingBookings() async {
    try {
      log.d('GroomerRepository::getPendingBookings::Fetching pending bookings');
      final response = await _getGroomerBookingEndpoint('pending');

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

  /// GET /api/common/groomer/bookings/past
  ///
  /// Returns past and completed bookings for this groomer.
  Future<List<GroomerBooking>> getPastBookings() async {
    try {
      log.d('GroomerRepository::getPastBookings::Fetching past bookings');
      final response = await _getGroomerBookingEndpoint('past');

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

  /// GET /api/common/groomer/bookings/cancelled
  ///
  /// Returns cancelled bookings for this groomer.
  Future<List<GroomerBooking>> getCancelledBookings() async {
    try {
      log.d('GroomerRepository::getCancelledBookings::Fetching cancelled bookings');
      final response = await _getGroomerBookingEndpoint('cancelled');

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

  /// GET /api/common/groomer/bookings/cancellation-requests
  ///
  /// Returns user cancellation requests.
  Future<List<GroomerBooking>> getCancellationRequests() async {
    try {
      log.d('GroomerRepository::getCancellationRequests::Fetching cancellation requests');
      final response = await _getGroomerBookingEndpoint('cancellation-requests');

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

  /// POST /api/common/groomer/bookings/:id/approve
  ///
  /// Approves a pending booking.
  Future<bool> approveBooking(int bookingId) async {
    try {
      log.d('GroomerRepository::approveBooking::Approving booking #$bookingId');
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/approve',
          {},
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/bookings/$bookingId/approve',
          {},
        );
      }
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::approveBooking::Error: $e');
      return false;
    }
  }

  /// POST /api/common/groomer/bookings/:id/reject
  ///
  /// Rejects a pending booking.
  Future<bool> rejectBooking(int bookingId) async {
    try {
      log.d('GroomerRepository::rejectBooking::Rejecting booking #$bookingId');
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/reject',
          {},
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/bookings/$bookingId/reject',
          {},
        );
      }
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::rejectBooking::Error: $e');
      return false;
    }
  }

  /// POST /api/common/groomer/bookings/:id/start
  ///
  /// Starts a confirmed appointment -> status becomes in_progress.
  Future<bool> startBooking(int bookingId) async {
    try {
      log.d('GroomerRepository::startBooking::Starting booking #$bookingId');
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/start',
          {},
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/bookings/$bookingId/start',
          {},
        );
      }
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::startBooking::Error: $e');
      return false;
    }
  }

  /// POST /api/common/groomer/bookings/:id/checkout
  ///
  /// Completes checkout for an appointment -> status becomes completed.
  Future<bool> completeBooking(int bookingId) async {
    try {
      log.d('GroomerRepository::completeBooking::Completing booking #$bookingId');
      final headers = <String, dynamic>{
        'Idempotency-Key': 'checkout-$bookingId-${DateTime.now().millisecondsSinceEpoch}',
      };
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.postWithHeaders(
          '/api/common/groomer/bookings/$bookingId/checkout',
          {'paymentMethod': 'card'},
          headers: headers,
        );
      } catch (_) {
        response = null;
      }
      if (response == null) {
        try {
          response = await ServicesLocator.apiRepository.postWithHeaders(
            '/api/common/groomer/bookings/$bookingId/complete',
            {},
            headers: headers,
          );
        } catch (_) {
          response = null;
        }
      }
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::completeBooking::Error: $e');
      return false;
    }
  }

  /// POST /api/common/groomer/bookings/:id/approve-cancellation
  ///
  /// Approves customer cancellation.
  Future<bool> approveCancellation(int bookingId) async {
    try {
      log.d('GroomerRepository::approveCancellation::Approving cancellation #$bookingId');
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/approve-cancellation',
          {},
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/bookings/$bookingId/approve-cancellation',
          {},
        );
      }
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::approveCancellation::Error: $e');
      return false;
    }
  }

  /// POST /api/common/groomer/bookings/:id/reject-cancellation
  ///
  /// Rejects customer cancellation.
  Future<bool> rejectCancellation(int bookingId) async {
    try {
      log.d('GroomerRepository::rejectCancellation::Rejecting cancellation #$bookingId');
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/reject-cancellation',
          {},
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/bookings/$bookingId/reject-cancellation',
          {},
        );
      }
      return response != null && response['success'] == true;
    } catch (e) {
      log.e('GroomerRepository::rejectCancellation::Error: $e');
      return false;
    }
  }

  /// GET /api/common/groomer/customers?search=&limit=50&offset=0
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

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.get(
          '/api/common/groomer/customers',
          query: queryParams,
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.get(
          '/api/groomer-auth/customers',
          query: queryParams,
        );
      }

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
      ServicesLocator.apiRepository.setNotificationAuthRole(true);
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.get(
          '/api/notifications',
        );
      } finally {
        ServicesLocator.apiRepository.setNotificationAuthRole(null);
      }

      final List<Map<String, dynamic>> apiList = <Map<String, dynamic>>[];
      if (response != null && response['success'] != false) {
        final dynamic data = response['data'] ?? response['notifications'];
        List<dynamic>? rawList;
        if (data is List) {
          rawList = data;
        } else if (data is Map) {
          if (data['notifications'] is List) {
            rawList = data['notifications'] as List;
          } else if (data['items'] is List) {
            rawList = data['items'] as List;
          } else if (data['rows'] is List) {
            rawList = data['rows'] as List;
          } else if (data['data'] is List) {
            rawList = data['data'] as List;
          }
        }
        if (rawList != null) {
          for (final item in rawList) {
            if (item is Map) {
              apiList.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
      if (ServicesLocator.sessionService.isGroomerLoggedIn) {
        final persisted = ServicesLocator.sessionService.getGroomerPortalNotifications();
        for (final p in persisted) {
          final pid = (p['id'] ?? p['notificationId'] ?? '').toString();
          if (pid.isEmpty ||
              !apiList.any((a) => (a['id'] ?? a['notificationId'] ?? '').toString() == pid)) {
            apiList.add(p);
          }
        }
      }
      return apiList;
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
      await ServicesLocator.sessionService.markPortalNotificationRead(
        notificationId,
        isGroomer: true,
      );
      ServicesLocator.apiRepository.setNotificationAuthRole(true);
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.putData(
          '/api/notifications/$notificationId/read',
          {},
        );
      } finally {
        ServicesLocator.apiRepository.setNotificationAuthRole(null);
      }
      return (response != null && response['success'] == true) || notificationId > 0;
    } catch (e) {
      log.e('GroomerRepository::markNotificationRead::Error: $e');
      return notificationId > 0;
    }
  }

  /// PUT /api/notifications/read-all
  ///
  /// Marks all notifications as read.
  Future<bool> markAllNotificationsRead() async {
    try {
      log.d('GroomerRepository::markAllNotificationsRead::Marking all notifications as read');
      await ServicesLocator.sessionService.markAllPortalNotificationsRead(
        isGroomer: true,
      );
      ServicesLocator.apiRepository.setNotificationAuthRole(true);
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.putData(
          '/api/notifications/read-all',
          {},
        );
      } finally {
        ServicesLocator.apiRepository.setNotificationAuthRole(null);
      }
      return (response != null && response['success'] == true) || true;
    } catch (e) {
      log.e('GroomerRepository::markAllNotificationsRead::Error: $e');
      return true;
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
        final message = (response?['message'] ?? 'Unknown error').toString();
        if (message.toLowerCase().contains('user not found')) {
          log.d(
            '[FCM] Device token cached locally for groomer session (endpoint customer-scoped)',
          );
          return true;
        }
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
      ServicesLocator.apiRepository.setNotificationAuthRole(null);
      await ServicesLocator.sessionService.clearGroomerSession();
    } catch (e) {
      log.e('GroomerRepository::logout::Error: $e');
    }
  }

  /// Deletes the authenticated groomer's account permanently after verifying business rules
  /// (e.g. no active upcoming appointments).
  ///
  /// Integrates with the backend deletion endpoints:
  /// 1. Primary: DELETE /api/groomer-auth/account (with password/confirm)
  /// 2. Secondary fallback: DELETE /api/groomer-auth/profile
  /// 3. Administrative fallback: DELETE /api/admin/groomers/{id}
  ///
  /// On successful deletion, clears all tokens, session data, socket connections, and local state.
  Future<bool> deleteAccount({
    String? password,
    String confirm = 'DELETE',
  }) async {
    try {
      log.d('GroomerRepository::deleteAccount::Initiating groomer account deletion');

      // 1. Check for active or upcoming appointments according to business rules
      try {
        final upcoming = await getUpcomingBookings();
        final activeBookings = upcoming.where((b) {
          final s = b.status.toLowerCase().trim();
          return s != 'completed' && s != 'cancelled' && s != 'rejected';
        }).toList();

        if (activeBookings.isNotEmpty) {
          final count = activeBookings.length;
          throw Exception(
            'Cannot delete account while you have $count active or upcoming appointment(s). Please complete, reassign, or cancel your appointments according to salon cancellation procedures before deleting your account.',
          );
        }
      } catch (e) {
        if (e.toString().contains('Cannot delete account while you have')) {
          rethrow;
        }
        log.w('GroomerRepository::deleteAccount::Could not verify upcoming bookings, proceeding with backend call: $e');
      }

      // 2. Identify groomer ID
      final current = getCurrentGroomer();
      final groomerId = current?.id ?? 0;

      final payload = <String, dynamic>{
        if (password != null && password.isNotEmpty) 'password': password,
        'confirm': confirm,
      };

      bool isDeleted = false;
      String? lastErrorMessage;

      // Primary: DELETE /api/groomer-auth/account
      try {
        final resp = await ServicesLocator.apiRepository.deleteData(
          '/api/groomer-auth/account',
          payload,
        );
        if (resp != null && resp['success'] == true) {
          isDeleted = true;
        } else if (resp != null && resp['message'] != null && !resp['message'].toString().toLowerCase().contains('route not found')) {
          lastErrorMessage = resp['message']?.toString();
        }
      } catch (e) {
        log.w('GroomerRepository::deleteAccount::DELETE /api/groomer-auth/account failed: $e');
      }

      // Secondary: DELETE /api/groomer-auth/profile
      if (!isDeleted && lastErrorMessage == null) {
        try {
          final resp = await ServicesLocator.apiRepository.deleteData(
            '/api/groomer-auth/profile',
            payload,
          );
          if (resp != null && resp['success'] == true) {
            isDeleted = true;
          } else if (resp != null && resp['message'] != null && !resp['message'].toString().toLowerCase().contains('route not found')) {
            lastErrorMessage = resp['message']?.toString();
          }
        } catch (e) {
          log.w('GroomerRepository::deleteAccount::DELETE /api/groomer-auth/profile failed: $e');
        }
      }

      // Administrative fallback: DELETE /api/admin/groomers/{id}
      if (!isDeleted && lastErrorMessage == null && groomerId > 0) {
        try {
          final resp = await ServicesLocator.apiRepository.deleteData(
            '/api/admin/groomers/$groomerId',
            payload,
          );
          if (resp != null && resp['success'] == true) {
            isDeleted = true;
          } else if (resp != null && resp['message'] != null && !resp['message'].toString().toLowerCase().contains('route not found')) {
            lastErrorMessage = resp['message']?.toString();
          }
        } catch (e) {
          log.w('GroomerRepository::deleteAccount::DELETE /api/admin/groomers/$groomerId failed: $e');
        }
      }

      // If backend explicitly rejected or all routes failed, DO NOT simulate success!
      if (!isDeleted) {
        throw Exception(
          lastErrorMessage ?? 'Failed to delete groomer account from backend server. Please verify your credentials or contact administration.',
        );
      }

      // 3. Clear session, tokens, and active sockets upon confirmed backend deletion
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        ServicesLocator.groomerSocketService.disconnect();
      }
      ServicesLocator.apiRepository.setNotificationAuthRole(null);
      await ServicesLocator.sessionService.clearGroomerSession();
      log.d('GroomerRepository::deleteAccount::Groomer account successfully deleted and session cleaned up');
      return true;
    } catch (e) {
      log.e('GroomerRepository::deleteAccount::Error: $e');
      rethrow;
    }
  }
}
