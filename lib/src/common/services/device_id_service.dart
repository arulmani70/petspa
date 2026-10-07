import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Persistent Device ID Service
///
/// Ensures a single, immutable RFC 4122 v4 UUID is generated once upon first app launch,
/// safely stored in [FlutterSecureStorage], and consistently reused across app restarts,
/// lifecycle transitions, and user logouts.
class DeviceIdService {
  final Logger _log = Logger();
  final FlutterSecureStorage _secureStorage;
  static const String storageKey = 'device_id';
  static const Uuid _uuid = Uuid();

  String? _cachedDeviceId;

  DeviceIdService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Initializes the service during app startup.
  /// Reads existing UUID from secure storage or creates one if it does not exist.
  Future<void> initialize() async {
    try {
      _log.d("DeviceIdService::initialize::Initializing device ID");
      _log.d("DeviceIdService::initialize::Checking secure storage for existing device ID");

      final existingId = await _secureStorage.read(key: storageKey);
      if (existingId != null && existingId.trim().isNotEmpty) {
        _cachedDeviceId = existingId.trim();
        _log.d("DeviceIdService::initialize::Existing device ID found");
        return;
      }

      _log.d("DeviceIdService::initialize::No device ID found, generating new UUID");
      final newId = _uuid.v4();
      await _secureStorage.write(key: storageKey, value: newId);
      _cachedDeviceId = newId;
      _log.d("DeviceIdService::initialize::New device ID generated and saved");
    } catch (e) {
      _log.e("DeviceIdService::initialize::Error initializing device ID: $e");
    }
  }

  /// Returns the persistent device UUID.
  ///
  /// 1. Reads from in-memory cache if available.
  /// 2. Reads from [FlutterSecureStorage] with key 'device_id'.
  /// 3. If missing, generates a fresh v4 UUID and persists it.
  /// 4. Returns the immutable UUID.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      _log.d("DeviceIdService::getDeviceId::Returning cached device ID");
      return _cachedDeviceId!;
    }

    try {
      _log.d("DeviceIdService::initialize::Checking secure storage for existing device ID");
      final existingId = await _secureStorage.read(key: storageKey);
      if (existingId != null && existingId.trim().isNotEmpty) {
        _cachedDeviceId = existingId.trim();
        _log.d("DeviceIdService::initialize::Existing device ID found");
        _log.d("DeviceIdService::getDeviceId::Persistent device ID available");
        return _cachedDeviceId!;
      }

      _log.d("DeviceIdService::initialize::No device ID found, generating new UUID");
      final newId = _uuid.v4();
      await _secureStorage.write(key: storageKey, value: newId);
      _cachedDeviceId = newId;
      _log.d("DeviceIdService::initialize::New device ID generated and saved");
      _log.d("DeviceIdService::getDeviceId::Persistent device ID available");
      return _cachedDeviceId!;
    } catch (e) {
      _log.e("DeviceIdService::getDeviceId::Secure storage error: $e");
      // If secure storage read fails, fallback to generating and keeping in memory
      if (_cachedDeviceId == null || _cachedDeviceId!.isEmpty) {
        _cachedDeviceId = _uuid.v4();
      }
      _log.d("DeviceIdService::getDeviceId::Persistent device ID available");
      return _cachedDeviceId!;
    }
  }

  /// Synchronous getter for device ID once initialized.
  String? get currentDeviceId => _cachedDeviceId;
}
