import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/models/groomer_login_response.dart';

class GroomerLoginRepository {
  final Logger log = Logger();

  Future<void> initialize() async {
    log.d('GroomerLoginRepository::initialize::Initialized');
  }

  /// POST /api/groomer-auth/login
  Future<GroomerLoginResponse?> login({
    required String email,
    required String password,
  }) async {
    try {
      log.d('GroomerLoginRepository::login::Logging in groomer: $email');

      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/login',
        {'email': email.trim(), 'password': password},
      );

      if (response == null ||
          response['success'] != true ||
          response['data'] == null) {
        final message =
            response?['message'] ??
            'Login failed. Please check your credentials.';
        log.w('GroomerLoginRepository::login::Failed: $message');
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
        final resolvedTempLoginId =
            (loginResponse.tempLoginId != null &&
                loginResponse.tempLoginId!.trim().isNotEmpty)
            ? loginResponse.tempLoginId!.trim()
            : (email.trim().isNotEmpty
                  ? email.trim()
                  : loginResponse.groomer.email);
        final resolvedTempPassword =
            (loginResponse.tempPassword != null &&
                loginResponse.tempPassword!.isNotEmpty)
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
          await ServicesLocator.groomerSocketService.connect(
            token: loginResponse.accessToken,
          );
        } catch (e) {
          log.e('GroomerLoginRepository::login::Socket connection error: $e');
        }
      }

      // Register FCM device token on login
      if (ServicesLocator.isPushNotificationServiceRegistered) {
        try {
          await ServicesLocator.pushNotificationService.fetchAndRegisterToken(
            isGroomer: true,
          );
        } catch (e) {
          log.e('GroomerLoginRepository::login::FCM registration error: $e');
        }
      }

      log.d(
        'GroomerLoginRepository::login::Login successful for ${loginResponse.groomer.fullName}',
      );
      return loginResponse;
    } catch (error) {
      log.e('GroomerLoginRepository::login::Error: $error');
      rethrow;
    }
  }

  /// POST /api/groomer-auth/refresh-token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await ServicesLocator.sessionService
          .getGroomerRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      log.d('GroomerLoginRepository::refreshToken::Refreshing groomer token');

      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/refresh-token',
        {'refreshToken': refreshToken},
      );

      if (response == null ||
          response['success'] != true ||
          response['data'] == null) {
        return false;
      }

      final data = response['data'] as Map<String, dynamic>;
      final newAccessToken = data['accessToken']?.toString();
      final newRefreshToken = data['refreshToken']?.toString() ?? refreshToken;
      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        final currentGroomer =
            ServicesLocator.sessionService.getGroomerUser() ?? {};
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
              'GroomerLoginRepository::refreshToken::Socket reconnection error: $e',
            );
          }
        }

        return true;
      }
      return false;
    } catch (error) {
      log.e('GroomerLoginRepository::refreshToken::Error: $error');
      return false;
    }
  }

  /// Returns currently saved groomer profile
  GroomerUser? getCurrentGroomer() {
    try {
      final data = ServicesLocator.sessionService.getGroomerUser();
      if (data == null) return null;
      return GroomerUser.fromJson(data);
    } catch (e) {
      log.e('GroomerLoginRepository::getCurrentGroomer::Error: $e');
      return null;
    }
  }

  /// Clears groomer session
  Future<void> logout() async {
    try {
      log.d('GroomerLoginRepository::logout::Logging out groomer');
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        ServicesLocator.groomerSocketService.disconnect();
      }
      await ServicesLocator.sessionService.clearGroomerSession();
    } catch (e) {
      log.e('GroomerLoginRepository::logout::Error: $e');
    }
  }
}
