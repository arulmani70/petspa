import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';

class SessionService {
  final Logger log = Logger();
  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const _accessTokenKey = 'ACCESS_TOKEN';
  static const _refreshTokenKey = 'REFRESH_TOKEN';
  static const _pendingEmailKey = 'PENDING_EMAIL';

  String? _customerAccessTokenInMemory;
  String? _customerRefreshTokenInMemory;

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

  bool get isAuthenticated => isLoggedIn;

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
      if (accessToken.trim().isNotEmpty) {
        _customerAccessTokenInMemory = accessToken.trim();
        await _prefs?.setString(_accessTokenKey, accessToken.trim());
        try {
          await _secureStorage.write(key: _accessTokenKey, value: accessToken.trim());
        } catch (e) {
          log.w("SessionService::saveTokens::SecureStorage accessToken write fallback: $e");
        }
      }
      if (refreshToken.trim().isNotEmpty) {
        _customerRefreshTokenInMemory = refreshToken.trim();
        await _prefs?.setString(_refreshTokenKey, refreshToken.trim());
        try {
          await _secureStorage.write(key: _refreshTokenKey, value: refreshToken.trim());
        } catch (e) {
          log.w("SessionService::saveTokens::SecureStorage refreshToken write fallback: $e");
        }
      }
      log.d("SessionService::saveTokens::Tokens saved securely");
    } catch (e) {
      log.e("SessionService::saveTokens::Error saving tokens: $e");
    }
  }

  Future<String?> getAccessToken() async {
    if (_customerAccessTokenInMemory != null &&
        _customerAccessTokenInMemory!.isNotEmpty) {
      return _customerAccessTokenInMemory;
    }
    try {
      final fromSecure = await _secureStorage.read(key: _accessTokenKey);
      if (fromSecure != null && fromSecure.isNotEmpty) {
        _customerAccessTokenInMemory = fromSecure;
        return fromSecure;
      }
    } catch (_) {}
    final fromPrefs = _prefs?.getString(_accessTokenKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _customerAccessTokenInMemory = fromPrefs;
      return fromPrefs;
    }
    return null;
  }

  Future<String?> getRefreshToken() async {
    if (_customerRefreshTokenInMemory != null &&
        _customerRefreshTokenInMemory!.isNotEmpty) {
      return _customerRefreshTokenInMemory;
    }
    try {
      final fromSecure = await _secureStorage.read(key: _refreshTokenKey);
      if (fromSecure != null && fromSecure.isNotEmpty) {
        _customerRefreshTokenInMemory = fromSecure;
        return fromSecure;
      }
    } catch (_) {}
    final fromPrefs = _prefs?.getString(_refreshTokenKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _customerRefreshTokenInMemory = fromPrefs;
      return fromPrefs;
    }
    return null;
  }

  Future<void> clearTokens() async {
    _customerAccessTokenInMemory = null;
    _customerRefreshTokenInMemory = null;
    await _prefs?.remove(_accessTokenKey);
    await _prefs?.remove(_refreshTokenKey);
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

  String? _groomerAccessTokenInMemory;
  String? _groomerRefreshTokenInMemory;

  static const _groomerAvatarPrefix = 'GROOMER_AVATAR_CACHE_';

  String? _extractGroomerIdentityKey(Map<String, dynamic> data) {
    final id = data['id']?.toString().trim() ?? data['groomerId']?.toString().trim() ?? '';
    if (id.isNotEmpty && id != '0') return 'id_$id';
    final code = data['groomerCode']?.toString().trim().toUpperCase() ?? '';
    if (code.isNotEmpty) return 'code_$code';
    final email = data['email']?.toString().trim().toLowerCase() ?? '';
    if (email.isNotEmpty) return 'email_$email';
    return null;
  }

  Future<void> saveGroomerUser(Map<String, dynamic> groomerData) async {
    try {
      final existing = getGroomerUser() ?? <String, dynamic>{};
      final merged = <String, dynamic>{
        ...existing,
        ...groomerData,
      };
      final identityKey = _extractGroomerIdentityKey(merged);

      // Preserve existing avatar/profilePicture if incoming payload omits them
      final incomingAvatar = groomerData['avatar']?.toString() ??
          groomerData['profilePicture']?.toString();
      if (incomingAvatar != null && incomingAvatar.trim().isNotEmpty) {
        merged['avatar'] = incomingAvatar.trim();
        merged['profilePicture'] = incomingAvatar.trim();
        if (identityKey != null) {
          await _prefs?.setString('$_groomerAvatarPrefix$identityKey', incomingAvatar.trim());
        }
      } else {
        final existingAvatar = existing['avatar']?.toString() ??
            existing['profilePicture']?.toString() ??
            (identityKey != null ? _prefs?.getString('$_groomerAvatarPrefix$identityKey') : null);
        if (existingAvatar != null && existingAvatar.trim().isNotEmpty) {
          merged['avatar'] = existingAvatar.trim();
          merged['profilePicture'] = existingAvatar.trim();
        }
      }
      await _prefs?.setString(_groomerUserKey, jsonEncode(merged));
    } catch (e) {
      log.e("SessionService::saveGroomerUser::Error: $e");
    }
  }

  Future<void> saveGroomerSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> groomerData,
  }) async {
    try {
      log.d("SessionService::saveGroomerSession::Saving groomer session");
      await saveGroomerUser(groomerData);

      if (accessToken.trim().isNotEmpty) {
        _groomerAccessTokenInMemory = accessToken.trim();
        await _prefs?.setString(_groomerAccessTokenKey, accessToken.trim());
        try {
          await _secureStorage.write(
            key: _groomerAccessTokenKey,
            value: accessToken.trim(),
          );
        } catch (e) {
          log.w("SessionService::saveGroomerSession::SecureStorage accessToken write fallback: $e");
        }
      }

      if (refreshToken.trim().isNotEmpty) {
        _groomerRefreshTokenInMemory = refreshToken.trim();
        await _prefs?.setString(_groomerRefreshTokenKey, refreshToken.trim());
        try {
          await _secureStorage.write(
            key: _groomerRefreshTokenKey,
            value: refreshToken.trim(),
          );
        } catch (e) {
          log.w("SessionService::saveGroomerSession::SecureStorage refreshToken write fallback: $e");
        }
      }
    } catch (e) {
      log.e("SessionService::saveGroomerSession::Error: $e");
    }
  }

  Future<String?> getGroomerAccessToken() async {
    if (_groomerAccessTokenInMemory != null &&
        _groomerAccessTokenInMemory!.isNotEmpty) {
      return _groomerAccessTokenInMemory;
    }
    try {
      final fromSecure = await _secureStorage.read(key: _groomerAccessTokenKey);
      if (fromSecure != null && fromSecure.isNotEmpty) {
        _groomerAccessTokenInMemory = fromSecure;
        return fromSecure;
      }
    } catch (_) {}
    final fromPrefs = _prefs?.getString(_groomerAccessTokenKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _groomerAccessTokenInMemory = fromPrefs;
      return fromPrefs;
    }
    return null;
  }

  Future<String?> getGroomerRefreshToken() async {
    if (_groomerRefreshTokenInMemory != null &&
        _groomerRefreshTokenInMemory!.isNotEmpty) {
      return _groomerRefreshTokenInMemory;
    }
    try {
      final fromSecure = await _secureStorage.read(key: _groomerRefreshTokenKey);
      if (fromSecure != null && fromSecure.isNotEmpty) {
        _groomerRefreshTokenInMemory = fromSecure;
        return fromSecure;
      }
    } catch (_) {}
    final fromPrefs = _prefs?.getString(_groomerRefreshTokenKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _groomerRefreshTokenInMemory = fromPrefs;
      return fromPrefs;
    }
    return null;
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

  Map<String, dynamic>? getGroomerData() => getGroomerUser();

  String? get userRole {
    final groomer = getGroomerUser();
    if (groomer != null && groomer['role'] != null) {
      return groomer['role'].toString();
    }
    final user = getSessionUser();
    if (user != null && user['role'] != null) {
      return user['role'].toString();
    }
    return null;
  }

  /// Whether current active session belongs to an Administrator / Store Manager / Owner.
  bool get isAdmin {
    final groomer = getGroomerUser();
    if (groomer != null) {
      if (groomer['isAdmin'] == true) return true;
      final role = (groomer['role'] ?? '').toString().toLowerCase().trim();
      if (role == 'admin' ||
          role == 'platform_admin' ||
          role == 'store_admin' ||
          role == 'staff_admin' ||
          role.contains('admin') ||
          role.contains('manager') ||
          role.contains('owner')) {
        return true;
      }
    }
    final user = getSessionUser();
    if (user != null) {
      if (user['isAdmin'] == true) return true;
      final role = (user['role'] ?? '').toString().toLowerCase().trim();
      if (role == 'admin' ||
          role == 'platform_admin' ||
          role == 'store_admin' ||
          role == 'staff_admin' ||
          role.contains('admin') ||
          role.contains('manager') ||
          role.contains('owner')) {
        return true;
      }
    }
    return false;
  }

  /// Whether current active session is the groomer currently assigned to [booking].
  bool isCurrentGroomerAssigned(GroomerBooking booking) {
    final groomer = getGroomerUser();
    if (groomer == null) return false;

    final gId = int.tryParse((groomer['id'] ?? groomer['groomerId'] ?? '').toString());
    final gCode = (groomer['groomerCode'] ?? groomer['code'] ?? groomer['GroomerId'] ?? '').toString().toUpperCase().trim();
    final gName = (groomer['fullName'] ??
            groomer['name'] ??
            '${groomer['firstName'] ?? ''} ${groomer['lastName'] ?? ''}')
        .toString()
        .toLowerCase()
        .trim();

    if (booking.isAssignedToGroomer(
      gId,
      targetGroomerCode: gCode,
      targetGroomerName: gName,
    )) {
      return true;
    }

    if (gId != null && gId > 0 && booking.groomerId != null && booking.groomerId! > 0) {
      final canonCur = BookingDateUtils.resolveCanonicalGroomerId(gId, groomerCode: gCode, groomerName: gName);
      final canonBooking = BookingDateUtils.resolveCanonicalGroomerId(booking.groomerId, groomerCode: booking.groomerCode, groomerName: booking.groomerName);
      if (canonCur != null && canonBooking != null && canonCur == canonBooking) {
        return true;
      }
      if (gId == booking.groomerId) {
        return true;
      }
    }

    if (gCode.isNotEmpty && booking.groomerCode != null && booking.groomerCode!.isNotEmpty) {
      if (gCode == booking.groomerCode!.toUpperCase().trim()) {
        return true;
      }
    }

    if (gName.isNotEmpty) {
      final bName = (booking.groomerName ?? booking.effectiveGroomerName).toLowerCase().trim();
      if (bName.isNotEmpty && (gName == bName || gName.contains(bName) || bName.contains(gName))) {
        return true;
      }
    }

    return false;
  }

  /// Determines whether the current user is authorized to manually reassign [booking].
  ///
  /// Rules:
  /// 1. Customer selected Preferred Groomer -> Reassignment is STRICTLY FORBIDDEN.
  /// 2. Admin -> Allowed to reassign any booking.
  /// 3. Currently assigned groomer -> Allowed to reassign their own booking.
  /// 4. All other users -> Blocked.
  bool canReassignBooking(GroomerBooking booking) {
    if (booking.isPreferredGroomer) {
      return false;
    }
    if (isAdmin) {
      return true;
    }
    return isCurrentGroomerAssigned(booking);
  }

  /// User-facing reason why reassignment is prohibited for [booking], or null if allowed.
  String? getReassignDisabledReason(GroomerBooking booking) {
    if (booking.isPreferredGroomer) {
      return 'The customer selected a Preferred Groomer. Reassignment to another groomer is not allowed.';
    }
    if (!isAdmin && !isCurrentGroomerAssigned(booking)) {
      return 'Unauthorized: Only an Administrator or the currently assigned groomer can reassign this appointment.';
    }
    return null;
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

  Map<String, String>? getTempGroomerCredentials() {
    final loginId = getTempGroomerLoginId();
    final pwd = _tempGroomerPasswordInMemory ?? _prefs?.getString(_tempGroomerPasswordKey);
    if (loginId == null && pwd == null) return null;
    return {
      'tempLoginId': ?loginId,
      'tempPassword': ?pwd,
    };
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
      _groomerAccessTokenInMemory = null;
      _groomerRefreshTokenInMemory = null;
      await _prefs?.remove(_groomerUserKey);
      await _prefs?.remove(_groomerAccessTokenKey);
      await _prefs?.remove(_groomerRefreshTokenKey);
      final avatarKeys = _prefs
              ?.getKeys()
              .where((k) => k.startsWith(_groomerAvatarPrefix))
              .toList() ??
          const <String>[];
      for (final key in avatarKeys) {
        await _prefs?.remove(key);
      }
      await clearTempGroomerCredentials();
      try {
        await _secureStorage.delete(key: _groomerAccessTokenKey);
        await _secureStorage.delete(key: _groomerRefreshTokenKey);
      } catch (e) {
        log.w("SessionService::clearGroomerSession::SecureStorage delete warning: $e");
      }
    } catch (e) {
      log.e("SessionService::clearGroomerSession::Error: $e");
    }
  }

  // ── Portal-Scoped Notification Persistence (Customer, Groomer, Admin) ──
  static const _customerNotifPrefix = 'PORTAL_CUSTOMER_NOTIFS_';
  static const _groomerNotifPrefix = 'PORTAL_GROOMER_NOTIFS_';
  static const _adminNotifKey = 'PORTAL_ADMIN_NOTIFS';
  static const _pendingBgFcmKey = 'PENDING_BG_FCM_NOTIFS';

  List<Map<String, dynamic>> _readNotifList(String key) {
    try {
      final raw = _prefs?.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      log.w('SessionService::_readNotifList::Error reading $key: $e');
    }
    return [];
  }

  Future<void> _writeNotifList(String key, List<Map<String, dynamic>> list) async {
    try {
      final capped = list.length > 100 ? list.sublist(0, 100) : list;
      await _prefs?.setString(key, jsonEncode(capped));
    } catch (e) {
      log.w('SessionService::_writeNotifList::Error writing $key: $e');
    }
  }

  void _upsertNotifInList(
    List<Map<String, dynamic>> list,
    Map<String, dynamic> notif,
  ) {
    final incomingId = notif['id'] ?? notif['notificationId'];
    final incomingMeta = notif['data'] is Map
        ? notif['data'] as Map
        : (notif['metadata'] is Map ? notif['metadata'] as Map : null);
    final incomingBookingId = incomingMeta?['bookingId'] ??
        incomingMeta?['booking_id'] ??
        notif['bookingId'] ??
        notif['booking_id'];
    final incomingType = (notif['type'] ?? '').toString().toLowerCase();

    final idx = list.indexWhere((item) {
      final existingId = item['id'] ?? item['notificationId'];
      if (existingId != null &&
          incomingId != null &&
          existingId.toString() == incomingId.toString()) {
        return true;
      }
      if (incomingBookingId != null && incomingType.isNotEmpty) {
        final existingMeta = item['data'] is Map
            ? item['data'] as Map
            : (item['metadata'] is Map ? item['metadata'] as Map : null);
        final existingBookingId = existingMeta?['bookingId'] ??
            existingMeta?['booking_id'] ??
            item['bookingId'] ??
            item['booking_id'];
        final existingType = (item['type'] ?? '').toString().toLowerCase();
        if (existingBookingId != null &&
            existingBookingId.toString() == incomingBookingId.toString() &&
            existingType == incomingType) {
          return true;
        }
      }
      return false;
    });

    if (idx >= 0) {
      list[idx] = notif;
    } else {
      list.insert(0, notif);
    }
  }

  Future<void> saveCustomerPortalNotification(
    Map<String, dynamic> notification, {
    int? customerId,
  }) async {
    final resolvedId = customerId ??
        int.tryParse(currentUserId ?? '') ??
        int.tryParse(notification['userId']?.toString() ?? '') ??
        0;
    final key = '$_customerNotifPrefix$resolvedId';
    final list = _readNotifList(key);
    _upsertNotifInList(list, notification);
    await _writeNotifList(key, list);
  }

  List<Map<String, dynamic>> getCustomerPortalNotifications({int? customerId}) {
    final resolvedId = customerId ?? int.tryParse(currentUserId ?? '') ?? 0;
    final specific = _readNotifList('$_customerNotifPrefix$resolvedId');
    if (resolvedId != 0) {
      final broadcast = _readNotifList('${_customerNotifPrefix}0');
      final combined = List<Map<String, dynamic>>.from(specific);
      for (final item in broadcast) {
        final itemUserId = int.tryParse(
          (item['userId'] ?? item['user_id'] ?? '').toString(),
        );
        if (itemUserId == null || itemUserId == 0 || itemUserId == resolvedId) {
          _upsertNotifInList(combined, item);
        }
      }
      return combined;
    }
    return specific;
  }

  Future<void> saveGroomerPortalNotification(
    Map<String, dynamic> notification, {
    int? groomerId,
    bool alsoSaveForAdmin = true,
  }) async {
    final currentGroomer = getGroomerUser();
    final resolvedGroomerId = groomerId ??
        int.tryParse(
          (notification['groomerId'] ??
                  (notification['data'] is Map
                      ? notification['data']['groomerId']
                      : null) ??
                  currentGroomer?['id'] ??
                  '0')
              .toString(),
        ) ??
        0;

    final key = '$_groomerNotifPrefix$resolvedGroomerId';
    final list = _readNotifList(key);
    _upsertNotifInList(list, notification);
    await _writeNotifList(key, list);

    if (alsoSaveForAdmin) {
      final adminList = _readNotifList(_adminNotifKey);
      _upsertNotifInList(adminList, notification);
      await _writeNotifList(_adminNotifKey, adminList);
    }
  }

  List<Map<String, dynamic>> getGroomerPortalNotifications({
    int? groomerId,
    bool isAdmin = false,
  }) {
    final currentGroomer = getGroomerUser();
    final role = (currentGroomer?['role'] ?? '').toString().toLowerCase();
    final effectiveIsAdmin = isAdmin ||
        role.contains('admin') ||
        role.contains('manager') ||
        role.contains('owner');
    if (effectiveIsAdmin) {
      final adminList = _readNotifList(_adminNotifKey);
      final resolvedGroomerId = groomerId ??
          int.tryParse((currentGroomer?['id'] ?? '0').toString()) ??
          0;
      if (resolvedGroomerId > 0) {
        final groomerList =
            _readNotifList('$_groomerNotifPrefix$resolvedGroomerId');
        for (final item in groomerList) {
          _upsertNotifInList(adminList, item);
        }
      }
      return adminList;
    }

    final resolvedGroomerId = groomerId ??
        int.tryParse((currentGroomer?['id'] ?? '0').toString()) ??
        0;
    final specific = _readNotifList('$_groomerNotifPrefix$resolvedGroomerId');
    if (resolvedGroomerId != 0) {
      final unassigned = _readNotifList('${_groomerNotifPrefix}0');
      final combined = List<Map<String, dynamic>>.from(specific);
      for (final item in unassigned) {
        final itemGroomerId = int.tryParse(
          (item['groomerId'] ??
                  (item['data'] is Map ? item['data']['groomerId'] : null) ??
                  '')
              .toString(),
        );
        if (itemGroomerId == null ||
            itemGroomerId == 0 ||
            itemGroomerId == resolvedGroomerId) {
          _upsertNotifInList(combined, item);
        }
      }
      return combined;
    }
    return specific;
  }

  Future<bool> markPortalNotificationRead(
    int notificationId, {
    bool isGroomer = false,
    int? customerId,
    int? groomerId,
  }) async {
    bool updatedAny = false;
    final keysToUpdate = <String>[];
    if (isGroomer) {
      final currentGroomer = getGroomerUser();
      final resolvedGroomerId = groomerId ??
          int.tryParse((currentGroomer?['id'] ?? '0').toString()) ??
          0;
      keysToUpdate.add('$_groomerNotifPrefix$resolvedGroomerId');
      keysToUpdate.add('${_groomerNotifPrefix}0');
      keysToUpdate.add(_adminNotifKey);
    } else {
      final resolvedCustomerId =
          customerId ?? int.tryParse(currentUserId ?? '') ?? 0;
      keysToUpdate.add('$_customerNotifPrefix$resolvedCustomerId');
      keysToUpdate.add('${_customerNotifPrefix}0');
    }

    for (final key in keysToUpdate) {
      final list = _readNotifList(key);
      bool changed = false;
      for (var i = 0; i < list.length; i++) {
        final rawId = list[i]['id'] ?? list[i]['notificationId'];
        if (rawId != null && rawId.toString() == notificationId.toString()) {
          list[i] = {
            ...list[i],
            'isRead': true,
            'is_read': true,
          };
          changed = true;
          updatedAny = true;
        }
      }
      if (changed) {
        await _writeNotifList(key, list);
      }
    }
    return updatedAny;
  }

  Future<void> markAllPortalNotificationsRead({
    bool isGroomer = false,
    int? customerId,
    int? groomerId,
  }) async {
    final keysToUpdate = <String>[];
    if (isGroomer) {
      final currentGroomer = getGroomerUser();
      final resolvedGroomerId = groomerId ??
          int.tryParse((currentGroomer?['id'] ?? '0').toString()) ??
          0;
      keysToUpdate.add('$_groomerNotifPrefix$resolvedGroomerId');
      keysToUpdate.add('${_groomerNotifPrefix}0');
      keysToUpdate.add(_adminNotifKey);
    } else {
      final resolvedCustomerId =
          customerId ?? int.tryParse(currentUserId ?? '') ?? 0;
      keysToUpdate.add('$_customerNotifPrefix$resolvedCustomerId');
      keysToUpdate.add('${_customerNotifPrefix}0');
    }

    for (final key in keysToUpdate) {
      final list = _readNotifList(key);
      if (list.isEmpty) continue;
      for (var i = 0; i < list.length; i++) {
        list[i] = {
          ...list[i],
          'isRead': true,
          'is_read': true,
        };
      }
      await _writeNotifList(key, list);
    }
  }

  Future<bool> deletePortalNotification(
    int notificationId, {
    bool isGroomer = false,
    int? customerId,
    int? groomerId,
  }) async {
    bool removedAny = false;
    final keysToUpdate = <String>[];
    if (isGroomer) {
      final currentGroomer = getGroomerUser();
      final resolvedGroomerId = groomerId ??
          int.tryParse((currentGroomer?['id'] ?? '0').toString()) ??
          0;
      keysToUpdate.add('$_groomerNotifPrefix$resolvedGroomerId');
      keysToUpdate.add('${_groomerNotifPrefix}0');
      keysToUpdate.add(_adminNotifKey);
    } else {
      final resolvedCustomerId =
          customerId ?? int.tryParse(currentUserId ?? '') ?? 0;
      keysToUpdate.add('$_customerNotifPrefix$resolvedCustomerId');
      keysToUpdate.add('${_customerNotifPrefix}0');
    }

    for (final key in keysToUpdate) {
      final list = _readNotifList(key);
      final beforeLen = list.length;
      list.removeWhere((item) {
        final rawId = item['id'] ?? item['notificationId'];
        return rawId != null && rawId.toString() == notificationId.toString();
      });
      if (list.length != beforeLen) {
        removedAny = true;
        await _writeNotifList(key, list);
      }
    }
    return removedAny;
  }

  Future<void> savePendingBackgroundFcmNotification(
    Map<String, dynamic> notification,
  ) async {
    final list = _readNotifList(_pendingBgFcmKey);
    _upsertNotifInList(list, notification);
    await _writeNotifList(_pendingBgFcmKey, list);
  }

  Future<List<Map<String, dynamic>>> consumePendingBackgroundFcmNotifications() async {
    final list = _readNotifList(_pendingBgFcmKey);
    if (list.isNotEmpty) {
      await _prefs?.remove(_pendingBgFcmKey);
    }
    return list;
  }

  // ── Confirmed Tip Persistence (shared between Customer & Groomer) ───────────
  static const _confirmedTipPrefix = 'CONFIRMED_TIP_BOOKING_';

  Future<void> saveConfirmedTip({
    required int bookingId,
    required double tipAmount,
    double? tipPercentage,
    int? customerId,
  }) async {
    try {
      final key = '$_confirmedTipPrefix$bookingId';
      final data = <String, dynamic>{
        'bookingId': bookingId,
        'tipAmount': tipAmount,
        'tip_amount': tipAmount,
        'tipPercentage': ?tipPercentage,
        'customerId': ?customerId,
        'isTipConfirmed': true,
        'confirmedAt': DateTime.now().toIso8601String(),
      };
      await _prefs?.setString(key, jsonEncode(data));
      log.d('SessionService::saveConfirmedTip::Saved confirmed tip \$$tipAmount for booking #$bookingId');
    } catch (e) {
      log.w('SessionService::saveConfirmedTip::Error saving confirmed tip: $e');
    }
  }

  Map<String, dynamic>? getConfirmedTip(int bookingId) {
    try {
      final key = '$_confirmedTipPrefix$bookingId';
      final jsonStr = _prefs?.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      log.w('SessionService::getConfirmedTip::Error reading confirmed tip: $e');
    }
    return null;
  }

  double? getConfirmedTipAmount(int bookingId) {
    final tipData = getConfirmedTip(bookingId);
    if (tipData != null) {
      final raw = tipData['tipAmount'] ?? tipData['tip_amount'];
      if (raw is num) return raw.toDouble();
      if (raw != null) return double.tryParse(raw.toString());
    }
    return null;
  }

  Future<void> clearConfirmedTip(int bookingId) async {
    try {
      final key = '$_confirmedTipPrefix$bookingId';
      await _prefs?.remove(key);
    } catch (_) {}
  }

  // ── Salon / Local Groomer Bookings Persistence ──
  static const _localBookingsKey = 'SHEAR_LOCAL_GROOMER_BOOKINGS';

  Future<void> saveLocalBookings(List<GroomerBooking> bookings) async {
    try {
      final list = bookings.map((b) => b.toJson()).toList();
      await _prefs?.setString(_localBookingsKey, jsonEncode(list));
    } catch (e) {
      log.w('SessionService::saveLocalBookings::Error: $e');
    }
  }

  List<GroomerBooking> getLocalBookings() {
    try {
      final raw = _prefs?.getString(_localBookingsKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => GroomerBooking.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    } catch (e) {
      log.w('SessionService::getLocalBookings::Error: $e');
    }
    return [];
  }
}

