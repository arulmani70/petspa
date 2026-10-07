import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

class NetworkService {
  final Logger log = Logger();
  final Connectivity _connectivity = Connectivity();

  StreamController<bool>? _networkStatusController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  Stream<bool> get networkStatusStream {
    _networkStatusController ??= StreamController<bool>.broadcast();
    return _networkStatusController!.stream;
  }

  Future<void> initialize() async {
    try {
      log.d("NetworkService::initialize::Starting network monitoring");

      _networkStatusController = StreamController<bool>.broadcast();
      await _checkConnectivity();

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _handleConnectivityChange(results);
        },
        onError: (error) {
          log.e("NetworkService::initialize::Connectivity listener error: $error");
        },
      );

      log.d("NetworkService::initialize::Network monitoring started");
    } catch (error) {
      log.e("NetworkService::initialize::Error: $error");
      rethrow;
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      await _checkConnectivity();
      return _isOnline;
    } catch (error) {
      log.e("NetworkService::checkConnectivity::Error: $error");
      return false;
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final wasOnline = _isOnline;

      bool hasConnection = false;
      for (final result in connectivityResults) {
        if (result == ConnectivityResult.wifi || result == ConnectivityResult.mobile || result == ConnectivityResult.ethernet) {
          hasConnection = true;
          break;
        }
      }

      if (hasConnection) {
        _isOnline = await _testInternetConnection();
      } else {
        _isOnline = false;
      }

      if (wasOnline != _isOnline) {
        log.d("NetworkService::_checkConnectivity::Network status changed: ${_isOnline ? 'Online' : 'Offline'}");
        _networkStatusController?.add(_isOnline);
      }
    } catch (error) {
      log.e("NetworkService::_checkConnectivity::Error: $error");
      _isOnline = false;
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) async {
    try {
      final wasOnline = _isOnline;

      bool hasConnection = false;
      for (final result in results) {
        if (result == ConnectivityResult.wifi || result == ConnectivityResult.mobile || result == ConnectivityResult.ethernet) {
          hasConnection = true;
          break;
        }
      }

      if (hasConnection) {
        _isOnline = await _testInternetConnection();
      } else {
        _isOnline = false;
      }

      if (wasOnline != _isOnline) {
        log.d("NetworkService::_handleConnectivityChange::Network status changed: ${_isOnline ? 'Online' : 'Offline'}");
        _networkStatusController?.add(_isOnline);
      }
    } catch (error) {
      log.e("NetworkService::_handleConnectivityChange::Error: $error");
    }
  }

  Future<bool> _testInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (error) {
      log.w("NetworkService::_testInternetConnection::No internet connection: $error");
      return false;
    }
  }

  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    try {
      log.d("NetworkService::waitForConnection::Waiting for network connection");

      if (_isOnline) {
        return true;
      }

      final completer = Completer<bool>();
      Timer? timeoutTimer;
      StreamSubscription<bool>? subscription;

      timeoutTimer = Timer(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      subscription = networkStatusStream.listen((isOnline) {
        if (isOnline) {
          timeoutTimer?.cancel();
          subscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }
      });

      return await completer.future;
    } catch (error) {
      log.e("NetworkService::waitForConnection::Error: $error");
      return false;
    }
  }

  void dispose() {
    log.d("NetworkService::dispose::Disposing network service");
    _connectivitySubscription?.cancel();
    _networkStatusController?.close();
    _networkStatusController = null;
  }
}
