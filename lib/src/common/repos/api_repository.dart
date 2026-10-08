import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

class ApiRepository {
  final Logger log = Logger();
  late final Dio _dio;
  bool? _notificationAuthIsGroomer;

  Completer<bool>? _customerRefreshCompleter;
  Completer<bool>? _groomerRefreshCompleter;

  @visibleForTesting
  Dio get dio => _dio;

  String get baseUrl => Constants.app.BASE_URL;

  void setNotificationAuthRole(bool? isGroomer) {
    _notificationAuthIsGroomer = isGroomer;
  }

  bool _isGroomerPath(String path) {
    final session = ServicesLocator.sessionService;
    return path.contains('/api/groomer-auth') ||
        _notificationAuthIsGroomer == true ||
        (_notificationAuthIsGroomer != false &&
            session.isGroomerLoggedIn &&
            (path.contains('/api/groomer-availability') ||
                path.contains('/api/availability') ||
                path.contains('/api/notifications')));
  }

  bool _isExcludedAuthPath(String path) {
    final cleanPath = path.toLowerCase().split('?').first;
    const excludedEndpoints = [
      '/api/auth/login',
      '/api/auth/signup',
      '/api/auth/send-otp',
      '/api/auth/verify-otp',
      '/api/auth/forgot-password',
      '/api/auth/reset-password',
      '/api/auth/refresh-token',
      '/api/auth/validate-device',
      '/api/auth/logout',
      '/api/groomer-auth/login',
      '/api/groomer-auth/register',
      '/api/groomer-auth/setup-account',
      '/api/groomer-auth/refresh-token',
      '/api/groomer-auth/logout',
    ];
    return excludedEndpoints.any(
      (endpoint) => cleanPath.endsWith(endpoint) || cleanPath.contains(endpoint),
    );
  }

  Future<bool> _refreshCustomerTokenWithMutex() async {
    if (_customerRefreshCompleter != null) {
      log.d('[AUTH] Customer refresh already in progress - waiting');
      final result = await _customerRefreshCompleter!.future;
      if (result) {
        log.d('[AUTH] Retrying queued requests');
      }
      return result;
    }

    log.d('[AUTH] Customer refresh started');
    final completer = Completer<bool>();
    _customerRefreshCompleter = completer;

    try {
      final success = await _performCustomerTokenRefresh();
      if (!completer.isCompleted) {
        completer.complete(success);
      }
      if (success) {
        log.d('[AUTH] Customer refresh succeeded');
        log.d('[AUTH] New Customer access token stored');
      } else {
        log.d('[AUTH] Customer refresh failed');
        await _handleCustomerAuthFailure();
      }
      return success;
    } catch (e) {
      log.d('[AUTH] Customer refresh failed: $e');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      await _handleCustomerAuthFailure();
      return false;
    } finally {
      _customerRefreshCompleter = null;
    }
  }

  Future<bool> _performCustomerTokenRefresh() async {
    try {
      final refreshToken = await ServicesLocator.sessionService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        log.w('[AUTH] Customer refresh token is missing or empty');
        return false;
      }

      log.d('[AUTH] POST /api/auth/refresh-token called');
      final response = await _dio.post(
        '/api/auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(
          extra: {'is_retry': true},
        ),
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w('[AUTH] Customer refresh-token failed with status ${response.statusCode}');
        return false;
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        log.w('[AUTH] Customer refresh-token invalid response body: $data');
        return false;
      }

      if (data['success'] == false) {
        log.w('[AUTH] Customer refresh-token returned success=false: ${data['message']}');
        return false;
      }

      final responseData = data['data'] as Map<String, dynamic>? ?? data;
      final newAccessToken = responseData['accessToken']?.toString();
      final newRefreshToken = responseData['refreshToken']?.toString() ?? refreshToken;

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        await ServicesLocator.sessionService.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        if (ServicesLocator.isCustomerSocketServiceRegistered) {
          try {
            await ServicesLocator.customerSocketService.connect(token: newAccessToken);
          } catch (e) {
            log.e('[AUTH] Customer socket reconnection error after refresh: $e');
          }
        }

        return true;
      }

      return false;
    } catch (e) {
      log.e('[AUTH] _performCustomerTokenRefresh error: $e');
      return false;
    }
  }

  Future<void> _handleCustomerAuthFailure() async {
    try {
      log.d('[AUTH] Clearing Customer session');
      final session = ServicesLocator.sessionService;
      await session.clearSession();

      log.d('[AUTH] Disconnecting Customer socket');
      if (ServicesLocator.isCustomerSocketServiceRegistered) {
        ServicesLocator.customerSocketService.disconnect();
      }

      log.d('[AUTH] Redirecting to Customer login');
      Routes.redirectToLogin(isGroomer: false);
    } catch (e) {
      log.e('[AUTH] _handleCustomerAuthFailure error: $e');
    }
  }

  Future<bool> _refreshGroomerTokenWithMutex() async {
    if (_groomerRefreshCompleter != null) {
      log.d('[AUTH] Groomer refresh already in progress - waiting');
      final result = await _groomerRefreshCompleter!.future;
      if (result) {
        log.d('[AUTH] Retrying queued requests');
      }
      return result;
    }

    log.d('[AUTH] Groomer refresh started');
    final completer = Completer<bool>();
    _groomerRefreshCompleter = completer;

    try {
      final success = await _performGroomerTokenRefresh();
      if (!completer.isCompleted) {
        completer.complete(success);
      }
      if (success) {
        log.d('[AUTH] Groomer refresh succeeded');
        log.d('[AUTH] New Groomer access token stored');
      } else {
        log.d('[AUTH] Groomer refresh failed');
        await _handleGroomerAuthFailure();
      }
      return success;
    } catch (e) {
      log.d('[AUTH] Groomer refresh failed: $e');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      await _handleGroomerAuthFailure();
      return false;
    } finally {
      _groomerRefreshCompleter = null;
    }
  }

  Future<bool> _performGroomerTokenRefresh() async {
    try {
      final refreshToken = await ServicesLocator.sessionService.getGroomerRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        log.w('[AUTH] Groomer refresh token is missing or empty');
        return false;
      }

      log.d('[AUTH] POST /api/groomer-auth/refresh-token called');
      final response = await _dio.post(
        '/api/groomer-auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(
          extra: {'is_retry': true},
        ),
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w('[AUTH] Groomer refresh-token failed with status ${response.statusCode}');
        return false;
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        log.w('[AUTH] Groomer refresh-token invalid response body: $data');
        return false;
      }

      if (data['success'] == false) {
        log.w('[AUTH] Groomer refresh-token returned success=false: ${data['message']}');
        return false;
      }

      final responseData = data['data'] as Map<String, dynamic>? ?? data;
      final newAccessToken = responseData['accessToken']?.toString();
      final newRefreshToken = responseData['refreshToken']?.toString() ?? refreshToken;

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        final currentGroomer = ServicesLocator.sessionService.getGroomerUser() ?? {};
        await ServicesLocator.sessionService.saveGroomerSession(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          groomerData: currentGroomer,
        );

        if (ServicesLocator.isGroomerSocketServiceRegistered) {
          try {
            await ServicesLocator.groomerSocketService.connect(token: newAccessToken);
          } catch (e) {
            log.e('[AUTH] Groomer socket reconnection error after refresh: $e');
          }
        }

        return true;
      }

      return false;
    } catch (e) {
      log.e('[AUTH] _performGroomerTokenRefresh error: $e');
      return false;
    }
  }

  Future<void> _handleGroomerAuthFailure() async {
    try {
      log.d('[AUTH] Clearing Groomer session');
      final session = ServicesLocator.sessionService;
      await session.clearGroomerSession();

      log.d('[AUTH] Disconnecting Groomer socket');
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        ServicesLocator.groomerSocketService.disconnect();
      }

      log.d('[AUTH] Redirecting to Groomer login');
      Routes.redirectToLogin(isGroomer: true);
    } catch (e) {
      log.e('[AUTH] _handleGroomerAuthFailure error: $e');
    }
  }

  Future<void> initialize() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (_) => true,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = ServicesLocator.sessionService;

          if (session.clientId != null) {
            options.headers['x-client-id'] = session.clientId;
          }
          if (session.regionId != null) {
            options.headers['x-region-id'] = session.regionId;
          }
          if (session.storeId != null) {
            options.headers['x-store-id'] = session.storeId;
          }

          if (_isExcludedAuthPath(options.path)) {
            return handler.next(options);
          }

          final isGroomerPath = _isGroomerPath(options.path);

          if (isGroomerPath) {
            log.d('[AUTH] Groomer API request started: ${options.path}');
            final groomerToken = await session.getGroomerAccessToken();
            if (groomerToken != null &&
                groomerToken.isNotEmpty &&
                !options.headers.containsKey('Authorization')) {
              options.headers['Authorization'] = 'Bearer $groomerToken';
            }
          } else {
            if (session.isLoggedIn) {
              log.d('[AUTH] Customer API request started: ${options.path}');
            } else {
              log.d('[AUTH] Guest API request started: ${options.path}');
            }

            final accessToken = await session.getAccessToken();
            if (accessToken != null &&
                accessToken.isNotEmpty &&
                !options.headers.containsKey('Authorization')) {
              options.headers['Authorization'] = 'Bearer $accessToken';
            }
          }

          return handler.next(options);
        },
        onResponse: (response, handler) async {
          if (_isExcludedAuthPath(response.requestOptions.path)) {
            log.d('[AUTH] Auth endpoint response received: ${response.requestOptions.path} (${response.statusCode})');
            log.d('[AUTH] Refresh skipped for auth endpoint');
            return handler.next(response);
          }

          if (response.statusCode == 401) {
            if (response.requestOptions.extra['is_retry'] == true) {
              log.d('[AUTH] Refresh skipped for already retried request');
              return handler.next(response);
            }

            final session = ServicesLocator.sessionService;
            final isGroomer = _isGroomerPath(response.requestOptions.path);
            final isCustomer = !isGroomer && session.isLoggedIn;

            if (!isGroomer && !isCustomer) {
              log.d('[AUTH] Guest request returned 401: ${response.requestOptions.path}');
              log.d('[AUTH] Guest session does not support token refresh');
              log.d('[AUTH] Skipping Customer/Groomer refresh');
              return handler.next(response);
            }

            if (isGroomer) {
              log.d('[AUTH] Groomer API returned 401: ${response.requestOptions.path}');
              log.d('[AUTH] Groomer access token expired/invalid');
              final refreshed = await _refreshGroomerTokenWithMutex();

              if (refreshed) {
                try {
                  log.d('[AUTH] Retrying original Groomer request');
                  final retryOptions = response.requestOptions;
                  retryOptions.extra['is_retry'] = true;
                  final freshToken = await session.getGroomerAccessToken();

                  if (freshToken != null && freshToken.isNotEmpty) {
                    retryOptions.headers['Authorization'] = 'Bearer $freshToken';
                  }

                  final retryResponse = await _dio.fetch(retryOptions);
                  if (retryResponse.statusCode != null &&
                      retryResponse.statusCode! >= 200 &&
                      retryResponse.statusCode! < 300) {
                    log.d('[AUTH] Original Groomer request succeeded after retry');
                  }
                  return handler.resolve(retryResponse);
                } catch (e) {
                  log.e('[AUTH] Error retrying Groomer request after refresh: $e');
                  return handler.next(response);
                }
              }
            } else {
              log.d('[AUTH] Customer API returned 401: ${response.requestOptions.path}');
              log.d('[AUTH] Customer access token expired/invalid');
              final refreshed = await _refreshCustomerTokenWithMutex();

              if (refreshed) {
                try {
                  log.d('[AUTH] Retrying original Customer request');
                  final retryOptions = response.requestOptions;
                  retryOptions.extra['is_retry'] = true;
                  final freshToken = await session.getAccessToken();

                  if (freshToken != null && freshToken.isNotEmpty) {
                    retryOptions.headers['Authorization'] = 'Bearer $freshToken';
                  }

                  final retryResponse = await _dio.fetch(retryOptions);
                  if (retryResponse.statusCode != null &&
                      retryResponse.statusCode! >= 200 &&
                      retryResponse.statusCode! < 300) {
                    log.d('[AUTH] Original Customer request succeeded after retry');
                  }
                  return handler.resolve(retryResponse);
                } catch (e) {
                  log.e('[AUTH] Error retrying Customer request after refresh: $e');
                  return handler.next(response);
                }
              }
            }
          }
          return handler.next(response);
        },
        onError: (DioException err, handler) async {
          if (err.response?.statusCode == 401) {
            if (err.requestOptions.extra['is_retry'] == true ||
                _isExcludedAuthPath(err.requestOptions.path)) {
              return handler.next(err);
            }

            final session = ServicesLocator.sessionService;
            final isGroomer = _isGroomerPath(err.requestOptions.path);
            final isCustomer = !isGroomer && session.isLoggedIn;

            if (!isGroomer && !isCustomer) {
              return handler.next(err);
            }

            final refreshed = isGroomer
                ? await _refreshGroomerTokenWithMutex()
                : await _refreshCustomerTokenWithMutex();

            if (refreshed) {
              try {
                final retryOptions = err.requestOptions;
                retryOptions.extra['is_retry'] = true;
                final freshToken = isGroomer
                    ? await session.getGroomerAccessToken()
                    : await session.getAccessToken();

                if (freshToken != null && freshToken.isNotEmpty) {
                  retryOptions.headers['Authorization'] = 'Bearer $freshToken';
                }

                final retryResponse = await _dio.fetch(retryOptions);
                return handler.resolve(retryResponse);
              } catch (e) {
                log.e('ApiRepository::Error retrying request after refresh (onError): $e');
                return handler.next(err);
              }
            }
          }
          return handler.next(err);
        },
      ),
    );

    log.d("ApiRepository::initialize::Dio initialized with baseUrl: $baseUrl");
  }

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final queryString = (query != null && query.isNotEmpty)
          ? '?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value?.toString() ?? '')}').join('&')}'
          : '';
      log.d("ApiRepository::get::Fetching: $path$queryString");
      final response = await _dio.get(path, queryParameters: query);

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w("ApiRepository::get::Unexpected status: ${response.statusCode}");
        return null;
      }

      return response.data as Map<String, dynamic>;
    } catch (error) {
      if (error is DioException &&
          error.response != null &&
          error.response?.data is Map<String, dynamic>) {
        return error.response?.data as Map<String, dynamic>;
      }
      log.w("ApiRepository::get::Error: $error");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      log.d("ApiRepository::getList::Fetching: $path");
      final response = await _dio.get(path, queryParameters: query);

      if (response.statusCode == 404) {
        log.w(
          "ApiRepository::getList::Resource not found (404) - returning empty list",
        );
        return [];
      }

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w(
          "ApiRepository::getList::Unexpected status: ${response.statusCode}",
        );
        return [];
      }

      final data = response.data;
      if (data is! List) {
        log.w("ApiRepository::getList::Response is not a list: $data");
        return [];
      }

      log.d("ApiRepository::getList::Fetched ${data.length} items");
      return data.map((e) => e as Map<String, dynamic>).toList();
    } catch (error) {
      log.w("ApiRepository::getList::Error: $error");
      return [];
    }
  }

  Future<Map<String, dynamic>?> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      log.d("ApiRepository::post::Posting to: $path");
      final response = await _dio.post(path, data: data);

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w(
          "ApiRepository::post::Unexpected status: ${response.statusCode} body: ${response.data}",
        );
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
        return null;
      }

      log.d("ApiRepository::post::Posted successfully");
      return response.data as Map<String, dynamic>;
    } catch (error) {
      if (error is DioException &&
          error.response != null &&
          error.response?.data is Map<String, dynamic>) {
        return error.response?.data as Map<String, dynamic>;
      }
      log.w("ApiRepository::post::Error: $error");
      return null;
    }
  }

  Future<Map<String, dynamic>?> postMultipart(
    String path,
    FormData data,
  ) async {
    try {
      log.d("ApiRepository::postMultipart::Posting to: $path");
      final response = await _dio.post(
        path,
        data: data,
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w(
          "ApiRepository::postMultipart::Unexpected status: ${response.statusCode} data: ${response.data}",
        );
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
        return null;
      }

      log.d("ApiRepository::postMultipart::Posted successfully");
      return response.data as Map<String, dynamic>;
    } catch (error) {
      if (error is DioException) {
        log.w(
          "ApiRepository::postMultipart::DioException: ${error.message}, Response: ${error.response?.data}",
        );
      } else {
        log.w("ApiRepository::postMultipart::Error: $error");
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> putData(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      log.d("ApiRepository::putData::Updating: $path");
      final response = await _dio.put(path, data: data);

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w(
          "ApiRepository::putData::Unexpected status: ${response.statusCode} body: ${response.data}",
        );
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
        return null;
      }

      log.d("ApiRepository::putData::Updated successfully");
      return response.data as Map<String, dynamic>;
    } catch (error) {
      if (error is DioException &&
          error.response != null &&
          error.response?.data is Map<String, dynamic>) {
        return error.response?.data as Map<String, dynamic>;
      }
      log.w("ApiRepository::putData::Error: $error");
      return null;
    }
  }

  Future<bool> put(String path, Map<String, dynamic> data) async {
    try {
      log.d("ApiRepository::put::Updating: $path");
      final response = await _dio.put(path, data: data);

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w("ApiRepository::put::Unexpected status: ${response.statusCode} body: ${response.data}");
        return false;
      }

      log.d("ApiRepository::put::Updated successfully");
      return true;
    } catch (error) {
      log.w("ApiRepository::put::Error: $error");
      return false;
    }
  }

  Future<bool> putMultipart(String path, FormData data) async {
    try {
      log.d("ApiRepository::putMultipart::Updating via multipart: $path");
      final response = await _dio.put(
        path,
        data: data,
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w(
          "ApiRepository::putMultipart::Unexpected status: ${response.statusCode} body: ${response.data}",
        );
        return false;
      }

      log.d("ApiRepository::putMultipart::Updated successfully");
      return true;
    } catch (error) {
      log.w("ApiRepository::putMultipart::Error: $error");
      return false;
    }
  }

  Future<Map<String, dynamic>?> putMultipartData(
    String path,
    FormData data,
  ) async {
    try {
      log.d("ApiRepository::putMultipartData::Updating via multipart: $path");
      final response = await _dio.put(
        path,
        data: data,
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w(
          "ApiRepository::putMultipartData::Unexpected status: ${response.statusCode} body: ${response.data}",
        );
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
        return null;
      }

      log.d("ApiRepository::putMultipartData::Updated successfully");
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'success': true};
    } catch (error) {
      if (error is DioException &&
          error.response != null &&
          error.response?.data is Map<String, dynamic>) {
        return error.response?.data as Map<String, dynamic>;
      }
      log.w("ApiRepository::putMultipartData::Error: $error");
      return null;
    }
  }

  Future<bool> delete(String path) async {
    try {
      log.d("ApiRepository::delete::Deleting: $path");
      final response = await _dio.delete(path);

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w(
          "ApiRepository::delete::Unexpected status: ${response.statusCode}",
        );
        return false;
      }

      log.d("ApiRepository::delete::Deleted successfully");
      return true;
    } catch (error) {
      log.w("ApiRepository::delete::Error: $error");
      return false;
    }
  }

  Future<Map<String, dynamic>?> deleteData(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      log.d("ApiRepository::deleteData::Deleting with payload: $path");
      final response = await _dio.delete(path, data: data);

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        log.w(
          "ApiRepository::deleteData::Unexpected status: ${response.statusCode} body: ${response.data}",
        );
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
        return null;
      }

      log.d("ApiRepository::deleteData::Deleted successfully");
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'success': true};
    } catch (error) {
      if (error is DioException &&
          error.response != null &&
          error.response?.data is Map<String, dynamic>) {
        return error.response?.data as Map<String, dynamic>;
      }
      log.w("ApiRepository::deleteData::Error: $error");
      return null;
    }
  }
}
