import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/repos/notification_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class AuthRepository {
  final Logger log = Logger();

  ApiRepository get _api => ServicesLocator.apiRepository;
  SessionService get _session => ServicesLocator.sessionService;

  Future<void> initialize() async {
    log.d("AuthRepository::initialize::Initializing auth repository");
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      log.d("AuthRepository::register::Registering user: $email");

      final deviceId = await ServicesLocator.deviceIdService.getDeviceId();

      final payload = {
        'name': name,
        'email': email.toLowerCase(),
        'mobile': phone.replaceAll(RegExp(r'[^0-9]'), ''),
        'password': password,
        'confirmPassword':
            password, // Assuming confirmPassword is the same as password for this flow
        'deviceId': deviceId,
        'clientId': _session.clientId ?? '',
        'regionId': _session.regionId ?? '',
        'storeId': _session.storeId ?? '',
      };

      log.d(
        "AuthRepository::register::Outgoing payload: ${payload.map((k, v) => MapEntry(k, k.toLowerCase().contains('password') ? '***' : v))}",
      );

      final response = await _api.post('/api/auth/signup', payload);

      if (response == null || response['success'] == false) {
        String errorMessage = response?['message'] ?? 'Failed to register';
        if (response != null &&
            response['errors'] != null &&
            response['errors'] is List) {
          final errors = (response['errors'] as List)
              .whereType<String>()
              .toList();
          if (errors.isNotEmpty) {
            errorMessage = errors.join('\n');
          }
        }
        throw Exception(errorMessage);
      }

      // Signup API sends the OTP. We store the email to verify later.
      await _session.savePendingEmail(email.toLowerCase());
      log.d(
        "AuthRepository::register::Stored pending email after signup: ${email.toLowerCase()}",
      );

      // Return dummy user for the bloc's pendingUser state if needed
      return {'email': email.toLowerCase(), 'name': name};
    } catch (error) {
      log.e("AuthRepository::register::Error: $error");
      rethrow;
    }
  }

  Future<String> sendOtp(String email) async {
    try {
      log.d("AuthRepository::sendOtp::Generating OTP for: $email");

      final deviceId = await ServicesLocator.deviceIdService.getDeviceId();

      final response = await _api.post('/api/auth/send-otp', {
        'email': email.toLowerCase(),
        'deviceId': deviceId,
        'clientId': _session.clientId ?? '',
        'regionId': _session.regionId ?? '',
        'storeId': _session.storeId ?? '',
      });

      if (response == null || response['success'] == false) {
        throw Exception(response?['message'] ?? 'Failed to send OTP');
      }

      await _session.savePendingEmail(email.toLowerCase());
      log.d(
        "AuthRepository::sendOtp::Stored pending email: ${email.toLowerCase()}",
      );
      return "sent"; // We don't return the actual OTP from the backend for security, the API sends it via email.
    } catch (error) {
      log.e("AuthRepository::sendOtp::Error: $error");
      rethrow;
    }
  }

  Future<bool> verifyOtp(String code) async {
    try {
      log.d("AuthRepository::verifyOtp::Verifying OTP");

      final pendingEmail = _session.getPendingEmail();
      if (pendingEmail == null) {
        throw Exception("No pending email to verify");
      }

      log.d(
        "AuthRepository::verifyOtp::Retrieved pending email: $pendingEmail",
      );

      final response = await _api.post('/api/auth/verify-otp', {
        'email': pendingEmail,
        'otp': code,
      });

      if (response == null || response['success'] == false) {
        return false;
      }

      final data = response['data'];
      if (data != null) {
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final user = data['user'] ?? data; // Depending on API structure

        if (accessToken != null && refreshToken != null) {
          await _session.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          await _session.saveSession(user as Map<String, dynamic>);
          await _session.clearPendingEmail();
          await registerDeviceTokenSafely();

          // Connect Customer real-time notifications on OTP verification
          if (ServicesLocator.isCustomerSocketServiceRegistered) {
            try {
              await ServicesLocator.customerSocketService.connect(
                token: accessToken.toString(),
              );
            } catch (e) {
              log.e("AuthRepository::verifyOtp::Socket connection error: $e");
            }
          }

          log.d(
            "AuthRepository::verifyOtp::Session saved and pending email cleared",
          );
          return true;
        }
      }

      return true;
    } catch (error) {
      log.e("AuthRepository::verifyOtp::Error: $error");
      return false;
    }
  }

  String? get pendingOtpEmail => _session.getPendingEmail();

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      log.d("AuthRepository::login::Logging in user: $email");

      final deviceId = await ServicesLocator.deviceIdService.getDeviceId();

      final payload = {
        'email': email.toLowerCase().trim(),
        'password': password,
        'deviceId': deviceId,
      };

      final response = await _api.post('/api/auth/login', payload);

      if (response == null || response['success'] == false) {
        String errMsg = response?['message'] ?? 'Invalid email or password.';
        if (response?['code'] == 'DEVICE_LIMIT_REACHED' ||
            (errMsg.toLowerCase().contains('device') &&
                errMsg.toLowerCase().contains('limit'))) {
          errMsg =
              'Maximum registered device limit reached (5 devices). Please log out from another device.';
        }
        throw Exception(errMsg);
      }

      final data = response['data'];
      if (data == null) {
        throw Exception('Invalid response format');
      }

      final userType = (data['userType'] ??
              (data['groomer'] != null ? 'groomer' : 'customer'))
          .toString()
          .toLowerCase();
      final accessToken = data['accessToken']?.toString();
      final refreshToken = data['refreshToken']?.toString();

      if (userType == 'groomer') {
        final groomerJson = data['groomer'] is Map<String, dynamic>
            ? data['groomer'] as Map<String, dynamic>
            : <String, dynamic>{};
        final mustChangePassword = data['mustChangePassword'] == true ||
            groomerJson['mustChangePassword'] == true;

        if (accessToken != null && refreshToken != null) {
          await _session.saveGroomerSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            groomerData: groomerJson,
          );
        }

        if (mustChangePassword) {
          final tempLoginId = data['tempLoginId']?.toString() ??
              groomerJson['email']?.toString() ??
              email.trim();
          final tempPassword =
              data['tempPassword']?.toString() ?? password;
          await _session.saveTempGroomerCredentials(
            tempLoginId: tempLoginId,
            tempPassword: tempPassword,
          );
        }

        // Connect Groomer real-time notifications on login
        if (accessToken != null &&
            ServicesLocator.isGroomerSocketServiceRegistered) {
          try {
            await ServicesLocator.groomerSocketService.connect(
              token: accessToken,
            );
          } catch (e) {
            log.e(
              'AuthRepository::login::Groomer socket connection error: $e',
            );
          }
        }

        // Register Groomer FCM device token on login
        if (ServicesLocator.isPushNotificationServiceRegistered) {
          try {
            await ServicesLocator.pushNotificationService.fetchAndRegisterToken(
              isGroomer: true,
            );
          } catch (e) {
            log.e(
              'AuthRepository::login::Groomer FCM registration error: $e',
            );
          }
        }

        log.d(
          "AuthRepository::login::Groomer login successful with deviceId=$deviceId",
        );
        return {
          'userType': 'groomer',
          'mustChangePassword': mustChangePassword,
          'groomer': groomerJson,
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        };
      } else {
        // Customer
        final user = data['user'] is Map<String, dynamic>
            ? data['user'] as Map<String, dynamic>
            : data;

        if (accessToken != null && refreshToken != null) {
          await _session.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
        }

        await _session.saveSession(user as Map<String, dynamic>);
        await registerDeviceTokenSafely();

        // Connect Customer real-time notifications on login
        if (accessToken != null &&
            ServicesLocator.isCustomerSocketServiceRegistered) {
          try {
            await ServicesLocator.customerSocketService.connect(
              token: accessToken,
            );
          } catch (e) {
            log.e(
              "AuthRepository::login::Customer socket connection error: $e",
            );
          }
        }

        log.d(
          "AuthRepository::login::Customer login successful with deviceId=$deviceId",
        );
        return {
          'userType': 'customer',
          'user': user,
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        };
      }
    } catch (error) {
      log.e("AuthRepository::login::Error: $error");
      rethrow;
    }
  }

  Future<void> registerDeviceTokenSafely({String? pushToken}) async {
    try {
      if (GetIt.I.isRegistered<PushNotificationService>()) {
        if (pushToken != null && pushToken.trim().isNotEmpty) {
          await ServicesLocator.pushNotificationService.registerDeviceToken(
            token: pushToken,
            isGroomer: false,
          );
        } else {
          await ServicesLocator.pushNotificationService.fetchAndRegisterToken(
            isGroomer: false,
          );
        }
      } else if (GetIt.I.isRegistered<NotificationRepository>() &&
          GetIt.I.isRegistered<DeviceIdService>()) {
        final deviceId = await ServicesLocator.deviceIdService.getDeviceId();
        final tokenToRegister =
            pushToken ?? ServicesLocator.sessionService.getPushToken();
        if (tokenToRegister != null && tokenToRegister.isNotEmpty) {
          await ServicesLocator.notificationRepository.registerDeviceToken(
            deviceId: deviceId,
            pushToken: tokenToRegister,
            platform: PushNotificationService.currentPlatform,
          );
        }
      }
    } catch (e) {
      log.e(
        'AuthRepository::registerDeviceTokenSafely::Error registering push token: $e',
      );
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      log.d('AuthRepository::resetPassword::Resetting password for $email');
      final response = await _api.post('/api/auth/reset-password', {
        'email': email.toLowerCase(),
        'password': password,
        'confirmPassword': confirmPassword,
      });
      if (response == null || response['success'] == false) {
        throw Exception(response?['message'] ?? 'Failed to reset password');
      }
      log.d('AuthRepository::resetPassword::Success');
      return response;
    } catch (error) {
      log.e('AuthRepository::resetPassword::Error: $error');
      rethrow;
    }
  }

  /// POST /api/auth/forgot-password
  /// Checks whether an email is registered and triggers OTP dispatch.
  Future<bool> forgotPasswordCheck(String email) async {
    try {
      log.d(
        'AuthRepository::forgotPasswordCheck::Calling /api/auth/forgot-password with email: $email',
      );
      final payload = {
        'email': email.toLowerCase().trim(),
        if (_session.clientId != null && _session.clientId!.isNotEmpty)
          'clientId': _session.clientId,
        if (_session.regionId != null && _session.regionId!.isNotEmpty)
          'regionId': _session.regionId,
        if (_session.storeId != null && _session.storeId!.isNotEmpty)
          'storeId': _session.storeId,
      };

      final response = await _api.post('/api/auth/forgot-password', payload);
      if (response == null || response['success'] == false) {
        String errorMessage =
            response?['message'] ?? 'Failed to process forgot password';
        if (response != null &&
            response['errors'] != null &&
            response['errors'] is List) {
          final errors = (response['errors'] as List)
              .whereType<String>()
              .toList();
          if (errors.isNotEmpty) {
            errorMessage = errors.join('\n');
          }
        }
        throw Exception(errorMessage);
      }

      await _session.savePendingEmail(email.toLowerCase().trim());
      log.d(
        'AuthRepository::forgotPasswordCheck::Saved pending email: ${email.toLowerCase().trim()}',
      );

      if (response['data'] != null && response['data']['exists'] is bool) {
        return response['data']['exists'] as bool;
      }
      return true;
    } catch (error) {
      log.e('AuthRepository::forgotPasswordCheck::Error: $error');
      rethrow;
    }
  }

  /// GET /api/auth/profile
  /// Returns authenticated user profile: name, email, mobile, emailVerified,
  /// clientId, regionId, storeId.
  Future<Map<String, dynamic>> getProfile() async {
    try {
      log.d('AuthRepository::getProfile::GET /api/auth/profile');
      final response = await _api.get('/api/auth/profile');
      if (response == null || response['success'] == false) {
        throw Exception(response?['message'] ?? 'Failed to fetch profile');
      }
      final data = response['data'] as Map<String, dynamic>? ?? {};
      log.d(
        'AuthRepository::getProfile::name=${data["name"]} email=${data["email"]}',
      );

      // Persist clientId/regionId/storeId returned from profile so all
      // subsequent booking API calls use the correct identifiers.
      final clientId = data['clientId']?.toString();
      final regionId = data['regionId']?.toString();
      final storeId = data['storeId']?.toString();
      if (clientId != null && clientId.isNotEmpty) {
        await _session.saveClientId(clientId);
      }
      if (regionId != null && regionId.isNotEmpty) {
        await _session.saveRegionId(regionId);
      }
      if (storeId != null && storeId.isNotEmpty) {
        await _session.saveStoreId(storeId);
      }

      // Also refresh session cache with latest user data while preserving local profile photo
      final existingUser = _session.getSessionUser() ?? {};
      final mergedData = {...existingUser, ...data};
      if ((data['profilePictureUrl'] == null || data['profilePictureUrl'].toString().isEmpty) &&
          existingUser['profilePictureUrl'] != null) {
        mergedData['profilePictureUrl'] = existingUser['profilePictureUrl'];
        mergedData['profilePicture'] = existingUser['profilePicture'];
      }
      await _session.saveSession(mergedData);
      return mergedData;
    } catch (error) {
      log.e('AuthRepository::getProfile::Error: $error');
      rethrow;
    }
  }

  /// PUT /api/auth/profile
  /// Updates name, mobile, and/or profile photo.
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? mobile,
    String? photoPath,
  }) async {
    return updateProfilePut(name: name, mobile: mobile, photoPath: photoPath);
  }

  /// PUT /api/auth/profile — updates profile name, mobile, and optional profile photo.
  Future<Map<String, dynamic>> updateProfilePut({
    String? name,
    String? mobile,
    String? photoPath,
  }) async {
    try {
      log.d('AuthRepository::updateProfilePut::name=$name mobile=$mobile photoPath=$photoPath');
      final payload = <String, dynamic>{};
      if (name != null && name.isNotEmpty) {
        payload['name'] = name.trim();
      }
      if (mobile != null && mobile.isNotEmpty) {
        payload['mobile'] = mobile.replaceAll(RegExp(r'[^0-9]'), '');
      }

      Map<String, dynamic>? data;

      // Handle photo upload via multipart if local photo path provided
      if (photoPath != null && photoPath.isNotEmpty && !photoPath.startsWith('http')) {
        try {
          final fileName = photoPath.split(RegExp(r'[/\\]')).last;
          final formData = FormData.fromMap({
            ...payload,
            'profilePicture': await MultipartFile.fromFile(photoPath, filename: fileName),
            'avatar': await MultipartFile.fromFile(photoPath, filename: fileName),
            'photo': await MultipartFile.fromFile(photoPath, filename: fileName),
            'image': await MultipartFile.fromFile(photoPath, filename: fileName),
          });

          final multiResp = await _api.putMultipartData('/api/auth/profile', formData);
          if (multiResp != null && multiResp['success'] != false && multiResp['data'] != null) {
            data = multiResp['data'] is Map<String, dynamic>
                ? multiResp['data'] as Map<String, dynamic>
                : <String, dynamic>{};
          } else {
            // Also try POST multipart fallback
            final postMultiResp = await _api.postMultipart('/api/auth/profile', formData);
            if (postMultiResp != null && postMultiResp['success'] != false && postMultiResp['data'] != null) {
              data = postMultiResp['data'] is Map<String, dynamic>
                  ? postMultiResp['data'] as Map<String, dynamic>
                  : <String, dynamic>{};
            }
          }
        } catch (e) {
          log.w('AuthRepository::updateProfilePut::Multipart photo upload error: $e');
        }
      }

      if (data == null || data.isEmpty) {
        if (payload.isEmpty && (photoPath == null || photoPath.isEmpty)) {
          throw Exception('At least one of name, mobile, or profile picture is required');
        }

        final response = await _api.putData('/api/auth/profile', payload);
        if (response == null || response['success'] == false) {
          throw Exception(response?['message'] ?? 'Failed to update profile');
        }
        data = response['data'] as Map<String, dynamic>? ?? {};
      }

      final merged = {..._session.getSessionUser() ?? {}, ...data};
      if (name != null && name.isNotEmpty) merged['name'] = name;
      if (mobile != null && mobile.isNotEmpty) merged['mobile'] = mobile;
      if (photoPath != null && photoPath.isNotEmpty) {
        merged['profilePictureUrl'] = photoPath;
        merged['profilePicture'] = photoPath;
      }
      await _session.saveSession(merged);
      return merged;
    } catch (error) {
      log.e('AuthRepository::updateProfilePut::Error: $error');
      rethrow;
    }
  }

  Future<void> completeRegistration(Map<String, dynamic> user) async {
    // Handled by verifyOtp in this flow
  }

  /// POST /api/auth/refresh-token
  ///
  /// Refreshes the customer access token.
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _session.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      log.d('AuthRepository::refreshToken::Refreshing customer token');

      final response = await _api.post(
        '/api/auth/refresh-token',
        {'refreshToken': refreshToken},
      );

      if (response == null ||
          response['success'] == false ||
          response['data'] == null) {
        return false;
      }

      final data = response['data'] as Map<String, dynamic>;
      final newAccessToken = data['accessToken']?.toString();
      final newRefreshToken =
          data['refreshToken']?.toString() ?? refreshToken;

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await _session.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        // Reconnect socket with refreshed token
        if (ServicesLocator.isCustomerSocketServiceRegistered) {
          try {
            await ServicesLocator.customerSocketService.connect(
              token: newAccessToken,
            );
          } catch (e) {
            log.e(
              'AuthRepository::refreshToken::Socket reconnection error: $e',
            );
          }
        }

        return true;
      }
      return false;
    } catch (error) {
      log.e('AuthRepository::refreshToken::Error: $error');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      log.d("AuthRepository::logout::Logging out");
      if (ServicesLocator.isCustomerSocketServiceRegistered) {
        ServicesLocator.customerSocketService.disconnect();
      }

      final refreshToken = await _session.getRefreshToken();
      if (refreshToken != null) {
        await _api.post('/api/auth/logout', {'refreshToken': refreshToken});
      }

      await _session.clearSession();
    } catch (error) {
      log.e("AuthRepository::logout::Error: $error");
      if (ServicesLocator.isCustomerSocketServiceRegistered) {
        ServicesLocator.customerSocketService.disconnect();
      }
      // Still clear session even if API call fails
      await _session.clearSession();
    }
  }

  /// DELETE /api/auth/account
  ///
  /// Permanently hard-deletes the authenticated customer account, pets, bookings,
  /// notifications, chat, and sessions from the database.
  /// Requires Bearer accessToken and body: { "password": "...", "confirm": "DELETE" }.
  Future<bool> deleteAccount({
    required String password,
    String confirm = 'DELETE',
  }) async {
    try {
      log.d("AuthRepository::deleteAccount::Calling DELETE /api/auth/account (hard delete)");
      if (ServicesLocator.isCustomerSocketServiceRegistered) {
        try {
          ServicesLocator.customerSocketService.disconnect();
        } catch (_) {}
      }

      final payload = {
        'password': password,
        'confirm': confirm,
      };

      final response = await _api.deleteData('/api/auth/account', payload);

      if (response == null || response['success'] == false) {
        final errorMsg = response?['message'] ?? 'Failed to delete account. Please verify your password.';
        throw Exception(errorMsg);
      }

      await _session.clearSession();
      log.d("AuthRepository::deleteAccount::Account deleted and session cleared successfully");
      return true;
    } catch (error) {
      log.e("AuthRepository::deleteAccount::Error during deletion: $error");
      rethrow;
    }
  }

  /// POST /api/auth/validate-device
  /// Validates the persistent device ID and obtains a device-level access token.
  /// userType can be: guest | registered | admin | groomer | bather
  Future<Map<String, dynamic>?> validateDevice({
    String userType = 'guest',
    int? userId,
  }) async {
    try {
      final deviceId = await ServicesLocator.deviceIdService.getDeviceId();
      log.d(
        'AuthRepository::validateDevice::Validating device: $deviceId userType=$userType',
      );

      final payload = <String, dynamic>{
        'deviceId': deviceId,
        'userType': userType,
        if (userId != null) 'userId': userId, // ignore: use_null_aware_elements
        'clientId': _session.clientId ?? 'SHEAR-001',
        'regionId': _session.regionId ?? 'DWG-001',
        'storeId': _session.storeId ?? 'SHEAR-001',
      };

      final response = await _api.post('/api/auth/validate-device', payload);
      return response;
    } catch (error) {
      log.e('AuthRepository::validateDevice::Error: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    return _session.getSessionUser();
  }
}
