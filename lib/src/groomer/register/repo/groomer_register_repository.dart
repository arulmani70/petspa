import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/models/groomer_login_response.dart';

class GroomerRegisterRepository {
  final Logger log = Logger();

  Future<void> initialize() async {
    log.d('GroomerRegisterRepository::initialize::Initialized');
  }

  /// POST /api/groomer-auth/setup-account
  Future<GroomerLoginResponse?> setupAccount({
    required String tempLoginId,
    required String tempPassword,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      log.d('GroomerRegisterRepository::setupAccount::Setting up groomer account for $email');

      if (tempPassword.trim().isEmpty) {
        const errorMsg = 'tempPassword is required and cannot be empty.';
        log.e('GroomerRegisterRepository::setupAccount::Validation Error: $errorMsg');
        throw Exception(errorMsg);
      }
      if (tempLoginId.trim().isEmpty) {
        const errorMsg = 'tempLoginId is required and cannot be empty.';
        log.e('GroomerRegisterRepository::setupAccount::Validation Error: $errorMsg');
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
        log.w('GroomerRegisterRepository::setupAccount::Failed: $message');
        throw Exception(message);
      }

      final data = response['data'] as Map<String, dynamic>;
      final loginResponse = GroomerLoginResponse.fromJson(data);

      await ServicesLocator.sessionService.saveGroomerSession(
        accessToken: loginResponse.accessToken,
        refreshToken: loginResponse.refreshToken,
        groomerData: loginResponse.groomer.toJson(),
      );

      // Register FCM device token on setup account
      if (ServicesLocator.isPushNotificationServiceRegistered) {
        try {
          await ServicesLocator.pushNotificationService.registerDeviceToken();
        } catch (e) {
          log.e('GroomerRegisterRepository::setupAccount::FCM registration error: $e');
        }
      }

      log.d('GroomerRegisterRepository::setupAccount::Setup successful for ${loginResponse.groomer.fullName}');
      return loginResponse;
    } catch (error) {
      log.e('GroomerRegisterRepository::setupAccount::Error: $error');
      rethrow;
    }
  }

  /// Updates profile details (names, mobile, photo, etc.).
  Future<GroomerUser?> updateProfile({
    String? firstName,
    String? lastName,
    String? mobile,
    String? highlights,
    bool? multiBookingEnabled,
    int? slotBookingLimit,
    String? photoPath,
  }) async {
    try {
      log.d('GroomerRegisterRepository::updateProfile::Updating groomer profile');

      final current = getCurrentGroomer();
      final body = <String, dynamic>{
        'firstName': firstName ?? current?.firstName ?? '',
        'lastName': lastName ?? current?.lastName ?? '',
        'mobile': mobile ?? current?.mobile ?? '',
        'highlights': highlights ?? current?.highlights ?? '',
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
          log.w('GroomerRegisterRepository::updateProfile::Multipart upload error: $e');
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
      log.e('GroomerRegisterRepository::updateProfile::Error: $error');
      rethrow;
    }
  }

  /// GET /api/groomer-auth/profile
  Future<GroomerUser?> getProfile() async {
    try {
      log.d('GroomerRegisterRepository::getProfile::Fetching groomer profile');

      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/profile',
      );

      if (response == null || response['success'] != true || response['data'] == null) {
        log.w('GroomerRegisterRepository::getProfile::Failed to fetch profile');
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
      log.e('GroomerRegisterRepository::getProfile::Error: $error');
      return getCurrentGroomer();
    }
  }

  /// Returns currently saved groomer profile
  GroomerUser? getCurrentGroomer() {
    try {
      final data = ServicesLocator.sessionService.getGroomerUser();
      if (data == null) return null;
      return GroomerUser.fromJson(data);
    } catch (e) {
      log.e('GroomerRegisterRepository::getCurrentGroomer::Error: $e');
      return null;
    }
  }
}
