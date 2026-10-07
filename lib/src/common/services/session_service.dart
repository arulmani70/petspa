import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';

class SessionService {
  final Logger log = Logger();
  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const _accessTokenKey = 'ACCESS_TOKEN';
  static const _refreshTokenKey = 'REFRESH_TOKEN';
  static const _pendingEmailKey = 'PENDING_EMAIL';

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      log.d("SessionService::initialize::SharedPreferences initialized");
    } catch (error) {
      log.e("SessionService::initialize::Error: $error");
      rethrow;
    }
  }

  Future<void> saveSession(Map<String, dynamic> user) async {
    try {
      final newId = user['id']?.toString() ?? user['userId']?.toString();
      if (newId != null && newId.isNotEmpty) {
        await _prefs?.setString(
          Constants.app.SESSION_KEY,
          newId,
        );
      }
      await _prefs?.setString(Constants.app.USER_KEY, jsonEncode(user));
    } catch (error) {
      log.e("SessionService::saveSession::Error: $error");
      rethrow;
    }
  }

  Map<String, dynamic>? getSessionUser() {
    try {
      final raw = _prefs?.getString(Constants.app.USER_KEY);
      if (raw == null || raw.isEmpty) return null;
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        // Fallback for old Map.toString() format
        final cleaned = raw.replaceAll("'", '"');
        final Map<String, dynamic> result = {};
        final matches = RegExp(
          r'([a-zA-Z0-9_]+):\s*"?([^,}]+)"?',
        ).allMatches(cleaned);
        for (final match in matches) {
          result[match.group(1)!] = match.group(2)?.trim() ?? '';
        }
        return result.isNotEmpty ? result : null;
      }
    } catch (error) {
      log.e("SessionService::getSessionUser::Error: $error");
      return null;
    }
  }

  bool get isLoggedIn {
    final session = _prefs?.getString(Constants.app.SESSION_KEY);
    return session != null && session.isNotEmpty;
  }

  String? get currentUserId => _prefs?.getString(Constants.app.SESSION_KEY);

  Future<void> saveOtpVerification(Map<String, dynamic> verification) async {
    await _prefs?.setString(
      Constants.app.OTP_VERIFICATION_KEY,
      jsonEncode(verification),
    );
  }

  Future<void> saveClientId(String clientId) async {
    await _prefs?.setString(Constants.app.CLIENT_ID_KEY, clientId);
  }

  String? get clientId => _prefs?.getString(Constants.app.CLIENT_ID_KEY);

  Future<void> saveRegionId(String regionId) async {
    await _prefs?.setString(Constants.app.REGION_ID_KEY, regionId);
  }

  String? get regionId => _prefs?.getString(Constants.app.REGION_ID_KEY);

  Future<void> saveStoreId(String storeId) async {
    await _prefs?.setString(Constants.app.STORE_ID_KEY, storeId);
  }

  String? get storeId => _prefs?.getString(Constants.app.STORE_ID_KEY);

  Map<String, dynamic>? getOtpVerification() {
    final raw = _prefs?.getString(Constants.app.OTP_VERIFICATION_KEY);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      final cleaned = raw.replaceAll("'", '"');
      final Map<String, dynamic> result = {};
      final matches = RegExp(
        r'([a-zA-Z0-9_]+):\s*"?([^,}]+)"?',
      ).allMatches(cleaned);
      for (final match in matches) {
        result[match.group(1)!] = match.group(2)?.trim() ?? '';
      }
      return result.isNotEmpty ? result : null;
    }
  }

  Future<void> clearSession() async {
    try {
      log.d("SessionService::clearSession::Clearing user session");
      await _prefs?.remove(Constants.app.SESSION_KEY);
      await _prefs?.remove(Constants.app.USER_KEY);
      await _prefs?.remove(Constants.app.CLIENT_ID_KEY);
      await _prefs?.remove(Constants.app.REGION_ID_KEY);
      await _prefs?.remove(Constants.app.STORE_ID_KEY);
      await clearTokens();
    } catch (error) {
      log.e("SessionService::clearSession::Error: $error");
      rethrow;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      log.d("SessionService::saveTokens::Tokens saved securely");
    } catch (e) {
      log.e("SessionService::saveTokens::Error saving tokens: $e");
    }
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      log.d("SessionService::clearTokens::Tokens cleared");
    } catch (e) {
      log.e("SessionService::clearTokens::Error clearing tokens: $e");
    }
  }

  Future<void> savePendingEmail(String email) async {
    await _prefs?.setString(_pendingEmailKey, email);
  }

  String? getPendingEmail() {
    return _prefs?.getString(_pendingEmailKey);
  }

  Future<void> clearPendingEmail() async {
    await _prefs?.remove(_pendingEmailKey);
  }

  static const _pushTokenKey = 'FCM_PUSH_TOKEN';

  Future<void> savePushToken(String token) async {
    await _prefs?.setString(_pushTokenKey, token);
  }

  String? getPushToken() {
    return _prefs?.getString(_pushTokenKey);
  }

  Future<void> clearPushToken() async {
    await _prefs?.remove(_pushTokenKey);
  }

  // ── Groomer Session Management ──
  static const _groomerAccessTokenKey = 'GROOMER_ACCESS_TOKEN';
  static const _groomerRefreshTokenKey = 'GROOMER_REFRESH_TOKEN';
  static const _groomerUserKey = 'GROOMER_USER_DATA';

  Future<void> saveGroomerSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> groomerData,
  }) async {
    try {
      log.d("SessionService::saveGroomerSession::Saving groomer session");
      await _secureStorage.write(
        key: _groomerAccessTokenKey,
        value: accessToken,
      );
      await _secureStorage.write(
        key: _groomerRefreshTokenKey,
        value: refreshToken,
      );
      await _prefs?.setString(_groomerUserKey, jsonEncode(groomerData));
    } catch (e) {
      log.e("SessionService::saveGroomerSession::Error: $e");
    }
  }

  Future<String?> getGroomerAccessToken() async {
    return await _secureStorage.read(key: _groomerAccessTokenKey);
  }

  Future<String?> getGroomerRefreshToken() async {
    return await _secureStorage.read(key: _groomerRefreshTokenKey);
  }

  bool get isGroomerLoggedIn {
    final raw = _prefs?.getString(_groomerUserKey);
    return raw != null && raw.isNotEmpty;
  }

  Map<String, dynamic>? getGroomerUser() {
    try {
      final raw = _prefs?.getString(_groomerUserKey);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      log.e("SessionService::getGroomerUser::Error: $e");
      return null;
    }
  }

  // ── Temporary Groomer Credentials (for setup-account flow) ──
  static const _tempGroomerLoginIdKey = 'TEMP_GROOMER_LOGIN_ID';
  static const _tempGroomerPasswordKey = 'TEMP_GROOMER_PASSWORD';

  String? _tempGroomerLoginIdInMemory;
  String? _tempGroomerPasswordInMemory;

  Future<void> saveTempGroomerCredentials({
    required String tempLoginId,
    required String tempPassword,
  }) async {
    try {
      _tempGroomerLoginIdInMemory = tempLoginId;
      _tempGroomerPasswordInMemory = tempPassword;
      await _prefs?.setString(_tempGroomerLoginIdKey, tempLoginId);
      await _prefs?.setString(_tempGroomerPasswordKey, tempPassword);
      await _secureStorage.write(
        key: _tempGroomerPasswordKey,
        value: tempPassword,
      );
      log.d(
        "SessionService::saveTempGroomerCredentials::Saved temporary groomer credentials",
      );
    } catch (e) {
      log.e("SessionService::saveTempGroomerCredentials::Error: $e");
    }
  }

  String? getTempGroomerLoginId() {
    if (_tempGroomerLoginIdInMemory != null &&
        _tempGroomerLoginIdInMemory!.isNotEmpty) {
      return _tempGroomerLoginIdInMemory;
    }
    return _prefs?.getString(_tempGroomerLoginIdKey);
  }

  Future<String?> getTempGroomerPassword() async {
    if (_tempGroomerPasswordInMemory != null &&
        _tempGroomerPasswordInMemory!.isNotEmpty) {
      return _tempGroomerPasswordInMemory;
    }
    try {
      final fromSecure = await _secureStorage.read(
        key: _tempGroomerPasswordKey,
      );
      if (fromSecure != null && fromSecure.isNotEmpty) {
        _tempGroomerPasswordInMemory = fromSecure;
        return fromSecure;
      }
    } catch (_) {}
    final fromPrefs = _prefs?.getString(_tempGroomerPasswordKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _tempGroomerPasswordInMemory = fromPrefs;
      return fromPrefs;
    }
    return null;
  }

  Future<void> clearTempGroomerCredentials() async {
    try {
      _tempGroomerLoginIdInMemory = null;
      _tempGroomerPasswordInMemory = null;
      await _prefs?.remove(_tempGroomerLoginIdKey);
      await _prefs?.remove(_tempGroomerPasswordKey);
      await _secureStorage.delete(key: _tempGroomerPasswordKey);
    } catch (e) {
      log.e("SessionService::clearTempGroomerCredentials::Error: $e");
    }
  }

  Future<void> clearGroomerSession() async {
    try {
      log.d("SessionService::clearGroomerSession::Clearing groomer session");
      await _secureStorage.delete(key: _groomerAccessTokenKey);
      await _secureStorage.delete(key: _groomerRefreshTokenKey);
      await _prefs?.remove(_groomerUserKey);
      await clearTempGroomerCredentials();
    } catch (e) {
      log.e("SessionService::clearGroomerSession::Error: $e");
    }
  }
}
