import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/models/groomer_login_response.dart';

class GroomerRegisterRepository {
  final Logger log = Logger();

  Future<void> initialize() async {
    log.d('GroomerRegisterRepository::initialize::Initialized');
  }

  /// POST /api/auth/groomer/setup-account (fallback: POST /api/groomer-auth/setup-account)
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

      final body = {
        'tempLoginId': tempLoginId.trim(),
        'tempPassword': tempPassword,
        'email': email.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      };

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/auth/groomer/setup-account',
          body,
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true || response['data'] == null) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/setup-account',
          body,
        );
      }

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

      // Connect real-time socket notifications on setup account
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        try {
          await ServicesLocator.groomerSocketService.connect(
            token: loginResponse.accessToken,
          );
          ServicesLocator.groomerSocketService.joinGroomerRooms(
            loginResponse.groomer.toJson(),
          );
        } catch (e) {
          log.e('GroomerRegisterRepository::setupAccount::Socket connection error: $e');
        }
      }

      // Register FCM device token on setup account
      if (ServicesLocator.isPushNotificationServiceRegistered) {
        try {
          await ServicesLocator.pushNotificationService.fetchAndRegisterToken(
            isGroomer: true,
          );
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
      return await ServicesLocator.groomerHomeRepository.updateProfile(
        firstName: firstName,
        lastName: lastName,
        mobile: mobile,
        highlights: highlights,
        multiBookingEnabled: multiBookingEnabled,
        slotBookingLimit: slotBookingLimit,
        photoPath: photoPath,
      );
    } catch (error) {
      log.e('GroomerRegisterRepository::updateProfile::Error: $error');
      rethrow;
    }
  }

  /// GET /api/groomer-auth/profile
  Future<GroomerUser?> getProfile() async {
    try {
      log.d('GroomerRegisterRepository::getProfile::Fetching groomer profile');
      return await ServicesLocator.groomerHomeRepository.getProfile();
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
