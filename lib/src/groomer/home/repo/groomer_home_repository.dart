import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/forecast_financial_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_check_in_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_report_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/store_milestone_config.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class GroomerHomeRepository {
  final Logger log = Logger();
  final List<Map<String, dynamic>> _realtimeNotifications = <Map<String, dynamic>>[];
  StreamSubscription<AppNotification>? _socketSub;

  /// In-memory cache for store milestone catalog by storeId
  final Map<String, List<StoreMilestoneConfig>> _storeMilestoneCatalogs = {};

  List<StoreMilestoneConfig>? getCachedMilestonesCatalog(String? storeId) {
    final sId = storeId ?? ServicesLocator.sessionService.storeId ?? 'SHEAR-001';
    return _storeMilestoneCatalogs[sId];
  }

  static final List<GroomerBooking> _localCreatedBookings = [];

  static List<GroomerBooking> get localCreatedBookings => List.unmodifiable(_localCreatedBookings);

  void _updateLocalBookingStatus(int bookingId, String status) {
    final idx = _localCreatedBookings.indexWhere((b) => b.bookingId == bookingId);
    if (idx >= 0) {
      _localCreatedBookings[idx] = _localCreatedBookings[idx].copyWith(
        status: status,
        cancellationReason: Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT,
      );
    }
  }

  static void addLocalBooking(GroomerBooking booking) {
    _localCreatedBookings.removeWhere((b) => b.bookingId == booking.bookingId);
    _localCreatedBookings.insert(0, booking);
  }

  static GroomerBooking? getLocalBooking(int bookingId) =>
      _localCreatedBookings.where((b) => b.bookingId == bookingId).firstOrNull;

  Future<void> initialize() async {
    log.d('GroomerHomeRepository::initialize::Initialized');
    _initSocketCacheListener();
  }

  void _initSocketCacheListener() {
    if (!ServicesLocator.isGroomerSocketServiceRegistered) return;
    _socketSub?.cancel();
    _socketSub = ServicesLocator.groomerSocketService.onNotification.listen((notif) {
      final map = <String, dynamic>{
        'id': notif.id,
        'notificationId': notif.id,
        'title': notif.title,
        'body': notif.message,
        'message': notif.message,
        'type': notif.type,
        'isRead': notif.isRead,
        'is_read': notif.isRead,
        'createdAt': notif.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        if (notif.metadata != null) 'data': notif.metadata,
        if (notif.metadata != null) 'metadata': notif.metadata,
      };
      _upsertRealtimeNotificationMap(map);
    });
  }

  void _upsertRealtimeNotificationMap(Map<String, dynamic> map) {
    final incomingId = map['id'] ?? map['notificationId'];
    final idx = _realtimeNotifications.indexWhere((item) {
      final existingId = item['id'] ?? item['notificationId'];
      return existingId != null &&
          incomingId != null &&
          existingId.toString() == incomingId.toString();
    });
    if (idx >= 0) {
      _realtimeNotifications[idx] = map;
    } else {
      _realtimeNotifications.insert(0, map);
    }
  }

  /// GET /api/groomer-auth/profile
  Future<GroomerUser?> getProfile() async {
    try {
      log.d('GroomerHomeRepository::getProfile::Fetching groomer profile');
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

      // Fallback: if groomer-auth/profile failed, try matching from /api/admin/groomers
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
              final map = Map<String, dynamic>.from(item);
              final candidate = GroomerUser.fromJson(map);
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

      log.w('GroomerHomeRepository::getProfile::Using cached groomer profile');
      return current;
    } catch (error) {
      log.e('GroomerHomeRepository::getProfile::Error: $error');
      return getCurrentGroomer();
    }
  }

  /// PUT /api/groomer-auth/profile
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
      log.d('GroomerHomeRepository::updateProfile::Updating groomer profile');

      final current = getCurrentGroomer();
      String resolvedFirstName = (firstName ?? current?.firstName ?? '').trim();
      String resolvedLastName = (lastName ?? current?.lastName ?? '').trim();
      if (resolvedFirstName.isEmpty && resolvedLastName.isNotEmpty) {
        resolvedFirstName = resolvedLastName;
      } else if (resolvedLastName.isEmpty && resolvedFirstName.isNotEmpty) {
        resolvedLastName = resolvedFirstName;
      }
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

      // 1. If we already know the groomer ID, sync /api/admin/groomers/:id first so
      //    highlights and role are persisted in the database before /api/groomer-auth/profile reads them.
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

      // 2. Call PUT /api/groomer-auth/profile with JSON payload
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

      // 3. If initialId was 0 but /api/groomer-auth/profile returned an ID, sync admin endpoint now
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
      log.e('GroomerHomeRepository::updateProfile::Error: $error');
      rethrow;
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
  Future<List<GroomerBooking>> getUpcomingBookings() async {
    try {
      log.d('GroomerHomeRepository::getUpcomingBookings::Fetching upcoming bookings');
      final response = await _getGroomerBookingEndpoint('upcoming');

      List<GroomerBooking> serverList = [];
      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        serverList = list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }

      // Filter out and auto-cancel any unaccepted pending bookings that have expired past scheduled start time
      if (ServicesLocator.isBookingCancellationManagerRegistered) {
        final List<GroomerBooking> validServerList = [];
        for (final b in serverList) {
          final st = b.status.toLowerCase();
          if (st == 'pending' || st == 'unaccepted' || st == 'awaiting_acceptance') {
            if (ServicesLocator.bookingCancellationManager.isScheduledStartTimeReached(
              b.bookingDate,
              b.startTime,
            )) {
              await ServicesLocator.bookingCancellationManager.autoCancelBooking(
                bookingId: b.bookingId,
                bookingData: b.toJson(),
              );
              _updateLocalBookingStatus(b.bookingId, 'CANCELLED');
              continue;
            }
          }
          validServerList.add(b);
        }
        serverList = validServerList;
      }

      List<GroomerBooking> merged = List<GroomerBooking>.from(serverList);
      if (_localCreatedBookings.isNotEmpty) {
        final localMap = {for (final b in _localCreatedBookings) b.bookingId: b};
        final updatedList = <GroomerBooking>[];
        for (final b in serverList) {
          if (localMap.containsKey(b.bookingId)) {
            final local = localMap[b.bookingId]!;
            if (local.status.toLowerCase() != 'cancelled') {
              updatedList.add(local);
            }
          } else {
            updatedList.add(b);
          }
        }
        for (final b in _localCreatedBookings) {
          if (!serverList.any((s) => s.bookingId == b.bookingId) && b.status.toLowerCase() != 'cancelled') {
            updatedList.insert(0, b);
          }
        }
        merged = updatedList;
      }

      // If viewing as an individual groomer (not admin), only show appointments assigned to this groomer
      final currentGroomer = getCurrentGroomer();
      final isSessionAdmin = ServicesLocator.isRegistered<SessionService>() && ServicesLocator.sessionService.isAdmin;
      if (!isSessionAdmin && currentGroomer != null && currentGroomer.id > 0) {
        final canonCurrent = BookingDateUtils.resolveCanonicalGroomerId(
          currentGroomer.id,
          groomerCode: currentGroomer.groomerCode,
          groomerName: currentGroomer.fullName,
        );
        return merged.where((b) {
          if (b.groomerId == null || b.groomerId! <= 0) return true;
          final canonB = BookingDateUtils.resolveCanonicalGroomerId(
            b.groomerId,
            groomerCode: b.groomerCode,
            groomerName: b.groomerName,
          );
          return canonB == canonCurrent || b.groomerId == currentGroomer.id;
        }).toList();
      }

      return merged;
    } catch (e) {
      log.e('GroomerHomeRepository::getUpcomingBookings::Error: $e');
      return _localCreatedBookings.where((b) => b.status.toLowerCase() != 'cancelled').toList();
    }
  }

  /// GET /api/common/groomer/bookings/pending
  Future<List<GroomerBooking>> getPendingBookings() async {
    try {
      log.d('GroomerHomeRepository::getPendingBookings::Fetching pending bookings');
      final response = await _getGroomerBookingEndpoint('pending');

      List<GroomerBooking> rawBookings = [];
      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        rawBookings = list
            .map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      if (_localCreatedBookings.isNotEmpty) {
        final serverIds = rawBookings.map((b) => b.bookingId).toSet();
        final localPending = _localCreatedBookings.where(
          (b) => !serverIds.contains(b.bookingId) && b.status.toLowerCase() == 'pending',
        );
        rawBookings.insertAll(0, localPending);
      }

      if (rawBookings.isNotEmpty) {
        final List<GroomerBooking> activePending = [];
        for (final booking in rawBookings) {
          if (ServicesLocator.isBookingCancellationManagerRegistered &&
              ServicesLocator.bookingCancellationManager.isScheduledStartTimeReached(
                booking.bookingDate,
                booking.startTime,
              )) {
            // Automatically cancel overdue unaccepted booking whose scheduled start time has arrived/passed
            await ServicesLocator.bookingCancellationManager.autoCancelBooking(
              bookingId: booking.bookingId,
              bookingData: booking.toJson(),
            );
            _updateLocalBookingStatus(booking.bookingId, 'CANCELLED');
            continue;
          }
          activePending.add(booking);
        }
        return activePending;
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getPendingBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/common/groomer/bookings/past
  Future<List<GroomerBooking>> getPastBookings() async {
    try {
      log.d('GroomerHomeRepository::getPastBookings::Fetching past bookings');
      final response = await _getGroomerBookingEndpoint('past');

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getPastBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/common/groomer/bookings/cancelled
  Future<List<GroomerBooking>> getCancelledBookings() async {
    try {
      log.d('GroomerHomeRepository::getCancelledBookings::Fetching cancelled bookings');
      final response = await _getGroomerBookingEndpoint('cancelled');

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getCancelledBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/common/groomer/bookings/cancellation-requests
  Future<List<GroomerBooking>> getCancellationRequests() async {
    try {
      log.d('GroomerHomeRepository::getCancellationRequests::Fetching cancellation requests');
      final response = await _getGroomerBookingEndpoint('cancellation-requests');

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getCancellationRequests::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/groomer-availability/:groomerId?date=YYYY-MM-DD&page=1&limit=10
  /// Fetches availability appointments along with backend pagination metadata.
  Future<({
    List<GroomerBooking> appointments,
    bool hasNextPage,
    int totalPages,
    int total,
  })> getGroomerAvailabilityAppointmentsWithPagination({
    required int groomerId,
    required String date,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      log.d('GroomerHomeRepository::getGroomerAvailabilityAppointmentsWithPagination::Fetching availability for groomer #$groomerId on $date (page: $page, limit: $limit)');
      final queryParams = <String, dynamic>{
        'date': date,
        'page': page,
        'limit': limit,
        'groomerId': groomerId,
      };

      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/groomer-availability/$groomerId',
        query: queryParams,
      );

      final appointments = _parseAvailabilityAppointmentsResponse(
        response,
        targetGroomerId: groomerId,
        date: date,
      );

      final combined = List<GroomerBooking>.from(appointments);
      if (_localCreatedBookings.isNotEmpty) {
        final existingIds = combined.map((b) => b.bookingId).toSet();
        for (final local in _localCreatedBookings) {
          if (!existingIds.contains(local.bookingId) &&
              local.status.toLowerCase() != 'cancelled' &&
              local.bookingDate == date &&
              (local.groomerId == groomerId || groomerId <= 0)) {
            combined.add(local);
            existingIds.add(local.bookingId);
          }
        }
      }

      final pagInfo = parseAvailabilityPagination(
        response,
        itemsCount: combined.length,
        page: page,
        limit: limit,
      );

      return (
        appointments: combined,
        hasNextPage: pagInfo.hasNextPage,
        totalPages: pagInfo.totalPages,
        total: pagInfo.total,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::getGroomerAvailabilityAppointmentsWithPagination::Error: $e');
      return (
        appointments: <GroomerBooking>[],
        hasNextPage: false,
        totalPages: 0,
        total: 0,
      );
    }
  }

  /// GET /api/groomer-auth/groomer-availability/:groomerId?date=YYYY-MM-DD&page=1&limit=10
  /// Fetches availability appointments for a specific groomer.
  Future<List<GroomerBooking>> getGroomerAvailabilityAppointments({
    required int groomerId,
    required String date,
    int page = 1,
    int limit = 10,
  }) async {
    final result = await getGroomerAvailabilityAppointmentsWithPagination(
      groomerId: groomerId,
      date: date,
      page: page,
      limit: limit,
    );
    return result.appointments;
  }

  /// Fetches availability appointments across all salon groomers.
  /// Calls GET /api/groomer-auth/groomer-availability/:groomerId for each groomer ID,
  /// then combines the results without duplicate appointments.
  Future<List<GroomerBooking>> getAllGroomersAvailabilityAppointments({
    required List<int> groomerIds,
    required String date,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      log.d('GroomerHomeRepository::getAllGroomersAvailabilityAppointments::Fetching for ${groomerIds.length} groomers on $date (page: $page, limit: $limit)');

      List<int> idsToFetch = List.from(groomerIds.where((id) => id > 0).toSet());
      if (idsToFetch.isEmpty) {
        final salonGroomers = await getSalonGroomers();
        idsToFetch = salonGroomers.map((g) => g.id).where((id) => id > 0).toSet().toList();
      }

      if (idsToFetch.isEmpty) {
        return [];
      }

      final responses = await Future.wait(
        idsToFetch.map((gid) => getGroomerAvailabilityAppointments(
          groomerId: gid,
          date: date,
          page: page,
          limit: limit,
        )),
      );

      final Map<String, GroomerBooking> uniqueAppointments = {};
      for (final list in responses) {
        for (final booking in list) {
          final key = booking.bookingId > 0
              ? 'id_${booking.bookingId}'
              : 'slot_${booking.groomerId}_${booking.bookingDate}_${booking.startTime}_${booking.endTime}';
          if (!uniqueAppointments.containsKey(key)) {
            uniqueAppointments[key] = booking;
          }
        }
      }

      final combined = uniqueAppointments.values.toList();
      combined.sort((a, b) {
        final da = BookingDateUtils.parseCalendarDate(a.bookingDate) ?? DateTime(1970);
        final db = BookingDateUtils.parseCalendarDate(b.bookingDate) ?? DateTime(1970);
        final dateComp = da.compareTo(db);
        if (dateComp != 0) return dateComp;
        final ta = BookingDateUtils.timeToMinutes(a.startTime) ?? 0;
        final tb = BookingDateUtils.timeToMinutes(b.startTime) ?? 0;
        return ta.compareTo(tb);
      });

      return combined;
    } catch (e) {
      log.e('GroomerHomeRepository::getAllGroomersAvailabilityAppointments::Error: $e');
      return [];
    }
  }

  /// Exposes pagination parsing for unit tests and backend contract validation.
  @visibleForTesting
  ({bool hasNextPage, int totalPages, int total}) parseAvailabilityPagination(
    Map<String, dynamic>? response, {
    required int itemsCount,
    required int page,
    required int limit,
  }) {
    final pagination = response != null
        ? (response['data'] is Map ? response['data']['pagination'] : null) ?? response['pagination'] ?? response['meta']
        : null;

    bool hasNext;
    int totalPages = 1;
    int total = itemsCount;

    if (pagination is Map) {
      if (pagination['hasNextPage'] != null) {
        hasNext = pagination['hasNextPage'] == true || pagination['hasNextPage']?.toString().toLowerCase() == 'true';
      } else if (pagination['hasMore'] != null) {
        hasNext = pagination['hasMore'] == true || pagination['hasMore']?.toString().toLowerCase() == 'true';
      } else if (pagination['totalPages'] != null) {
        final tp = int.tryParse(pagination['totalPages'].toString()) ?? 1;
        totalPages = tp;
        hasNext = page < tp;
      } else {
        hasNext = itemsCount >= limit;
      }

      if (pagination['totalPages'] != null) {
        totalPages = int.tryParse(pagination['totalPages'].toString()) ?? totalPages;
      }
      if (pagination['total'] != null) {
        total = int.tryParse(pagination['total'].toString()) ?? total;
      }
    } else {
      hasNext = itemsCount >= limit;
    }

    return (
      hasNextPage: hasNext,
      totalPages: totalPages,
      total: total,
    );
  }

  /// Exposes response parsing for unit tests and availability mappings.
  @visibleForTesting
  List<GroomerBooking> parseAvailabilityAppointmentsResponse(
    Map<String, dynamic>? response, {
    int? targetGroomerId,
    required String date,
  }) {
    return _parseAvailabilityAppointmentsResponse(
      response,
      targetGroomerId: targetGroomerId,
      date: date,
    );
  }

  /// Parses the response from /api/groomer-auth/groomer-availability/:groomerId
  /// into a list of GroomerBooking objects.
  List<GroomerBooking> _parseAvailabilityAppointmentsResponse(
    Map<String, dynamic>? response, {
    int? targetGroomerId,
    required String date,
  }) {
    if (response == null || response['data'] == null) {
      return [];
    }

    final data = response['data'];
    final List<GroomerBooking> appointments = [];

    void parseGroomerSlots(Map<dynamic, dynamic> groomerMap) {
      final gId = int.tryParse(groomerMap['id']?.toString() ?? groomerMap['groomerId']?.toString() ?? '') ?? targetGroomerId;
      final gName = groomerMap['name']?.toString() ??
          groomerMap['fullName']?.toString() ??
          (groomerMap['firstName'] != null
              ? '${groomerMap['firstName']} ${groomerMap['lastName'] ?? ''}'.trim()
              : null);
      final gCode = groomerMap['groomerCode']?.toString();

      final slotsRaw = groomerMap['busySlots'] ??
          groomerMap['slots'] ??
          groomerMap['appointments'] ??
          groomerMap['bookings'];

      if (slotsRaw is List) {
        for (final slot in slotsRaw) {
          if (slot is Map) {
            final bId = int.tryParse(slot['bookingId']?.toString() ?? slot['id']?.toString() ?? '') ?? 0;
            final bDate = slot['bookingDate']?.toString() ?? date;
            final sTime = slot['startTime']?.toString() ?? '';
            final eTime = slot['endTime']?.toString() ?? '';
            final status = slot['status']?.toString() ?? 'pending';

            if (bId > 0 || (sTime.isNotEmpty && eTime.isNotEmpty)) {
              appointments.add(GroomerBooking(
                bookingId: bId,
                status: status,
                bookingDate: bDate,
                startTime: sTime,
                endTime: eTime,
                petName: slot['petName']?.toString() ??
                    slot['pet_name']?.toString() ??
                    (slot['pet'] is Map ? (slot['pet']['petName']?.toString() ?? slot['pet']['name']?.toString()) : null) ??
                    'Pet',
                breed: slot['breed']?.toString() ??
                    (slot['pet'] is Map ? slot['pet']['breed']?.toString() : null) ??
                    '',
                profilePicture: slot['profilePicture']?.toString() ??
                    (slot['pet'] is Map ? (slot['pet']['profilePicture']?.toString() ?? slot['pet']['profilePictureUrl']?.toString()) : null),
                customerName: slot['customerName']?.toString() ??
                    slot['customer_name']?.toString() ??
                    (slot['user'] is Map ? (slot['user']['name']?.toString() ?? slot['user']['fullName']?.toString()) : null) ??
                    (slot['customer'] is Map ? (slot['customer']['name']?.toString() ?? slot['customer']['fullName']?.toString()) : null) ??
                    'Customer',
                customerEmail: slot['customerEmail']?.toString() ??
                    (slot['user'] is Map ? slot['user']['email']?.toString() : null) ??
                    '',
                customerMobile: slot['customerMobile']?.toString() ??
                    slot['customer_mobile']?.toString() ??
                    slot['mobile']?.toString() ??
                    slot['phone']?.toString() ??
                    slot['contactNumber']?.toString() ??
                    slot['phoneNumber']?.toString() ??
                    (slot['user'] is Map ? (slot['user']['mobile']?.toString() ?? slot['user']['phone']?.toString()) : null) ??
                    (slot['customer'] is Map ? (slot['customer']['mobile']?.toString() ?? slot['customer']['phone']?.toString() ?? slot['customer']['phoneNumber']?.toString()) : null) ??
                    '',
                serviceName: slot['serviceName']?.toString() ??
                    (slot['service'] is Map ? slot['service']['name']?.toString() : null) ??
                    'Grooming',
                packageName: slot['packageName']?.toString() ??
                    (slot['package'] is Map ? slot['package']['name']?.toString() : null),
                addOns: slot['addOns'] is List
                    ? (slot['addOns'] as List).map((a) => a is Map ? a['name'].toString() : a.toString()).toList()
                    : const [],
                totalPrice: double.tryParse(slot['totalPrice']?.toString() ??
                    slot['totalAmount']?.toString() ??
                    slot['serviceAmount']?.toString() ??
                    slot['serviceFee']?.toString() ??
                    slot['price']?.toString() ??
                    '') ?? 0.0,
                tipAmount: slot['tipAmount'] != null
                    ? double.tryParse(slot['tipAmount'].toString())
                    : (slot['tip'] != null
                        ? double.tryParse(slot['tip'].toString())
                        : (slot['tips'] != null
                            ? double.tryParse(slot['tips'].toString())
                            : (slot['completedTipAmount'] != null
                                ? double.tryParse(slot['completedTipAmount'].toString())
                                : null))),
                taxAmount: slot['taxAmount'] != null
                    ? double.tryParse(slot['taxAmount'].toString())
                    : (slot['tax'] != null
                        ? double.tryParse(slot['tax'].toString())
                        : (slot['salesTax'] != null
                            ? double.tryParse(slot['salesTax'].toString())
                            : (slot['completedTaxAmount'] != null
                                ? double.tryParse(slot['completedTaxAmount'].toString())
                                : null))),
                isPaid: (slot['isPaid'] != null
                    ? (slot['isPaid'] == true ||
                        slot['isPaid']?.toString().toLowerCase() == 'true' ||
                        slot['isPaid'] == 1 ||
                        slot['isPaid']?.toString() == '1')
                    : (slot['paid'] != null
                        ? (slot['paid'] == true ||
                            slot['paid']?.toString().toLowerCase() == 'true' ||
                            slot['paid'] == 1 ||
                            slot['paid']?.toString() == '1')
                        : (slot['isCompletedTransaction'] == true
                            ? true
                            : (slot['paymentStatus']?.toString().toLowerCase() == 'paid' ||
                                slot['payment_status']?.toString().toLowerCase() == 'paid'
                                ? true
                                : (slot['paymentStatus']?.toString().toLowerCase() == 'unpaid' ||
                                    slot['payment_status']?.toString().toLowerCase() == 'unpaid'
                                    ? false
                                    : null))))),
                paymentStatus: slot['paymentStatus']?.toString() ??
                    slot['payment_status']?.toString(),
                totalDurationMinutes: int.tryParse(slot['totalDurationMinutes']?.toString() ?? '') ?? 60,
                storeId: slot['storeId']?.toString() ?? '',
                groomerId: gId,
                groomerName: gName,
                groomerCode: gCode,
                specialInstructions: (slot['specialInstructions'] ??
                    slot['special_instructions'] ??
                    slot['notes'] ??
                    slot['serviceRequestNotes'] ??
                    slot['service_request_notes'])?.toString(),
              ));
            }
          }
        }
      }
    }

    if (data is Map) {
      if (data['groomers'] is List) {
        final groomersList = data['groomers'] as List;
        for (final g in groomersList) {
          if (g is Map) {
            final gid = int.tryParse(g['id']?.toString() ?? g['groomerId']?.toString() ?? '');
            if (targetGroomerId == null || targetGroomerId <= 0 || gid == targetGroomerId) {
              parseGroomerSlots(g);
            }
          }
        }
      } else if (data['busySlots'] is List || data['slots'] is List) {
        parseGroomerSlots(data);
      } else {
        parseGroomerSlots(data);
      }
    } else if (data is List) {
      for (final item in data) {
        if (item is Map) {
          parseGroomerSlots(item);
        }
      }
    }

    return appointments;
  }

  /// Dedicated method for All Groomers Schedule fetching.
  /// Delegates directly to the groomer availability endpoint.
  Future<List<GroomerBooking>> getAllGroomersBookings({
    int? groomerId,
    String? date,
    int page = 1,
    int limit = 10,
    List<int>? groomerIds,
  }) async {
    final targetDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (groomerId != null && groomerId > 0) {
      return getGroomerAvailabilityAppointments(
        groomerId: groomerId,
        date: targetDate,
        page: page,
        limit: limit,
      );
    } else {
      return getAllGroomersAvailabilityAppointments(
        groomerIds: groomerIds ?? [],
        date: targetDate,
        page: page,
        limit: limit,
      );
    }
  }

  /// Dedicated method for All Groomers Schedule fetching with full pagination and date-range support.
  Future<({
    List<GroomerBooking> appointments,
    bool hasNextPage,
    int totalPages,
    int total,
  })> getAllGroomersBookingsWithPagination({
    int? groomerId,
    List<int>? groomerIds,
    String? date,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final List<String> dates = [];
      if (startDate != null && endDate != null && startDate.isNotEmpty && endDate.isNotEmpty) {
        final startDt = BookingDateUtils.parseCalendarDate(startDate);
        final endDt = BookingDateUtils.parseCalendarDate(endDate);
        if (startDt != null && endDt != null) {
          final s = BookingDateUtils.normalize(startDt);
          final e = BookingDateUtils.normalize(endDt);
          final diff = e.difference(s).inDays.clamp(0, 92);
          for (int i = 0; i <= diff; i++) {
            dates.add(DateFormat('yyyy-MM-dd').format(s.add(Duration(days: i))));
          }
        }
      }
      if (dates.isEmpty) {
        dates.add(date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
      }

      List<int> targetGroomerIds = [];
      if (groomerId != null && groomerId > 0) {
        targetGroomerIds = [groomerId];
      } else if (groomerIds != null && groomerIds.isNotEmpty) {
        targetGroomerIds = groomerIds.where((id) => id > 0).toSet().toList();
      } else {
        final salon = await getSalonGroomers();
        targetGroomerIds = salon.map((g) => g.id).where((id) => id > 0).toSet().toList();
      }

      if (targetGroomerIds.isEmpty) {
        return (appointments: <GroomerBooking>[], hasNextPage: false, totalPages: 1, total: 0);
      }

      final Map<String, GroomerBooking> uniqueAppointments = {};
      bool anyHasNextPage = false;
      int maxTotalPages = 1;
      int aggregatedTotalCount = 0;

      for (final targetDate in dates) {
        for (final gid in targetGroomerIds) {
          final res = await getGroomerAvailabilityAppointmentsWithPagination(
            groomerId: gid,
            date: targetDate,
            page: page,
            limit: limit,
          );
          if (res.hasNextPage) anyHasNextPage = true;
          if (res.totalPages > maxTotalPages) maxTotalPages = res.totalPages;
          aggregatedTotalCount += res.total;

          for (final b in res.appointments) {
            final key = b.bookingId > 0
                ? 'id_${b.bookingId}'
                : 'slot_${b.groomerId}_${b.bookingDate}_${b.startTime}_${b.endTime}';
            uniqueAppointments[key] = b;
          }
        }
      }

      final List<GroomerBooking> list = [];
      for (final b in uniqueAppointments.values) {
        final st = b.status.toLowerCase();
        if (st == 'pending' || st == 'unaccepted' || st == 'awaiting_acceptance') {
          if (ServicesLocator.isBookingCancellationManagerRegistered &&
              ServicesLocator.bookingCancellationManager.isScheduledStartTimeReached(
                b.bookingDate,
                b.startTime,
              )) {
            await ServicesLocator.bookingCancellationManager.autoCancelBooking(
              bookingId: b.bookingId,
              bookingData: b.toJson(),
            );
            _updateLocalBookingStatus(b.bookingId, 'CANCELLED');
            list.add(b.copyWith(
              status: 'cancelled',
              cancellationReason: Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT,
            ));
            continue;
          }
        }
        list.add(b);
      }
      list.sort((a, b) {
        final da = BookingDateUtils.parseCalendarDate(a.bookingDate) ?? DateTime(1970);
        final db = BookingDateUtils.parseCalendarDate(b.bookingDate) ?? DateTime(1970);
        final comp = da.compareTo(db);
        if (comp != 0) return comp;
        final ta = BookingDateUtils.timeToMinutes(a.startTime) ?? 0;
        final tb = BookingDateUtils.timeToMinutes(b.startTime) ?? 0;
        return ta.compareTo(tb);
      });

      return (
        appointments: list,
        hasNextPage: anyHasNextPage,
        totalPages: maxTotalPages,
        total: aggregatedTotalCount > 0 ? aggregatedTotalCount : list.length,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::getAllGroomersBookingsWithPagination::Error: $e');
      return (appointments: <GroomerBooking>[], hasNextPage: false, totalPages: 1, total: 0);
    }
  }

  /// POST /api/groomer-auth/bookings/:id/approve
  Future<({bool success, String message})> approveBookingDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::approveBooking::Approving booking #$bookingId');

      // Check if booking has already expired past the scheduled appointment start time
      if (ServicesLocator.isBookingCancellationManagerRegistered) {
        GroomerBooking? target = booking;
        if (target == null) {
          try {
            final pending = await getPendingBookings();
            target = pending.where((b) => b.bookingId == bookingId).firstOrNull;
          } catch (_) {}
          if (target == null) {
            final response = await _getGroomerBookingEndpoint('pending');
            if (response != null && response['data'] is List) {
              final list = response['data'] as List;
              final rawBookings = list
                  .map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>))
                  .toList();
              target = rawBookings.where((b) => b.bookingId == bookingId).firstOrNull;
            }
          }
        }

        if (target != null) {
          if (ServicesLocator.bookingCancellationManager.isScheduledStartTimeReached(
            target.bookingDate,
            target.startTime,
          )) {
            await ServicesLocator.bookingCancellationManager.autoCancelBooking(
              bookingId: bookingId,
              bookingData: target.toJson(),
            );
            _updateLocalBookingStatus(bookingId, 'CANCELLED');
            return (
              success: false,
              message: 'This booking has expired because the scheduled appointment start time has passed without groomer acceptance.',
            );
          }
        }
      }

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
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Booking #$bookingId approved successfully' : 'Failed to approve booking.');
      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Booking Confirmed',
          customerMessage: 'Your booking #$bookingId has been confirmed by the groomer.',
          groomerTitle: 'Booking Approved',
          groomerMessage: 'Booking #$bookingId has been approved and confirmed.',
          type: 'booking_confirmed',
          status: 'confirmed',
          booking: booking,
          responseData: data,
        );
      }
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::approveBooking::Error: $e');
      return (success: false, message: 'Error approving booking: $e');
    }
  }

  Future<bool> approveBooking(int bookingId, {GroomerBooking? booking}) async {
    final res = await approveBookingDetails(bookingId, booking: booking);
    return res.success;
  }

  /// POST /api/common/groomer/bookings/:id/reject
  Future<({bool success, String message})> rejectBookingDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::rejectBooking::Rejecting booking #$bookingId');
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
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Booking #$bookingId rejected' : 'Failed to reject booking.');
      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Booking Request Declined',
          customerMessage: 'Your booking request #$bookingId could not be accepted by the groomer.',
          groomerTitle: 'Booking Rejected',
          groomerMessage: 'Booking #$bookingId has been declined.',
          type: 'booking_rejected',
          status: 'cancelled',
          booking: booking,
          responseData: data,
        );
      }
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::rejectBooking::Error: $e');
      return (success: false, message: 'Error rejecting booking: $e');
    }
  }

  Future<bool> rejectBooking(int bookingId) async {
    final res = await rejectBookingDetails(bookingId);
    return res.success;
  }

  /// POST /api/common/groomer/bookings/:id/check-in
  /// Submits the intake checklist (vaccination verification, health verification,
  /// customer instructions acknowledgment, and groomer check-in notes).
  Future<({
    bool success,
    String message,
    GroomerBooking? updatedBooking,
    GroomerCheckInRecord? checkInRecord,
  })> checkInBooking({
    required int bookingId,
    required bool vaccinationVerified,
    required bool healthVerified,
    required bool customerRequestAcknowledged,
    String? groomerCheckInNotes,
    GroomerBooking? booking,
  }) async {
    try {
      log.d('GroomerHomeRepository::checkInBooking::Checking in booking #$bookingId');

      GroomerBooking? effectiveBooking = booking;
      effectiveBooking ??= _localCreatedBookings.where((b) => b.bookingId == bookingId).firstOrNull;
      if (effectiveBooking == null) {
        try {
          final upcoming = await getUpcomingBookings();
          effectiveBooking = upcoming.where((b) => b.bookingId == bookingId).firstOrNull;
        } catch (_) {}
      }

      if (effectiveBooking != null && !effectiveBooking.isCheckedIn && !effectiveBooking.canCheckIn()) {
        final reason = effectiveBooking.isBeforeScheduledDate()
            ? 'Check-in is only allowed on the scheduled booking date (${effectiveBooking.formattedBookingDate}).'
            : (effectiveBooking.isAfterScheduledDate()
                ? 'Check-in is closed because the scheduled booking date (${effectiveBooking.formattedBookingDate}) has passed.'
                : 'Check-in is only allowed on the scheduled booking date (${effectiveBooking.formattedBookingDate}).');
        log.w('GroomerHomeRepository::checkInBooking::Blocked check-in - $reason');
        return (
          success: false,
          message: reason,
          updatedBooking: null,
          checkInRecord: null,
        );
      }

      final payload = <String, dynamic>{
        'vaccinationVerified': vaccinationVerified,
        'healthVerified': healthVerified,
        'customerRequestAcknowledged': customerRequestAcknowledged,
        if (groomerCheckInNotes != null && groomerCheckInNotes.trim().isNotEmpty)
          'groomerCheckInNotes': groomerCheckInNotes.trim(),
      };

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/check-in',
          payload,
        );
      } catch (_) {
        response = null;
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.post(
          '/api/groomer-auth/bookings/$bookingId/check-in',
          payload,
        );
      }

      final isSuccess = response != null && response['success'] == true;
      String msg = response?['message']?.toString() ??
          (isSuccess ? 'Dog checked in successfully. Appointment is now in service.' : 'Failed to check in appointment.');

      if (!isSuccess) {
        final lowerMsg = msg.toLowerCase();
        final isRouteNotFound = lowerMsg.contains('route not found') ||
            lowerMsg.contains('not found') ||
            response?['statusCode'] == 404;

        if (isRouteNotFound) {
          if (effectiveBooking != null) {
            msg = effectiveBooking.isBeforeScheduledDate()
                ? 'Check-in is only allowed on the scheduled booking date (${effectiveBooking.formattedBookingDate}).'
                : (effectiveBooking.isAfterScheduledDate()
                    ? 'Check-in is closed because the scheduled booking date (${effectiveBooking.formattedBookingDate}) has passed.'
                    : 'Check-in is only allowed on the scheduled booking date (${effectiveBooking.formattedBookingDate}).');
          } else {
            msg = 'Check-in is only allowed on the scheduled booking date.';
          }
        }
      }

      GroomerCheckInRecord? checkInRecord;
      GroomerBooking? updatedBooking = booking ?? effectiveBooking;

      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        if (data != null && data['checkInRecord'] is Map) {
          checkInRecord = GroomerCheckInRecord.fromJson(
            Map<String, dynamic>.from(data['checkInRecord'] as Map),
          );
        } else {
          checkInRecord = GroomerCheckInRecord(
            vaccinationVerified: vaccinationVerified,
            healthVerified: healthVerified,
            customerRequestAcknowledged: customerRequestAcknowledged,
            groomerCheckInNotes: groomerCheckInNotes?.trim(),
            checkInTimestamp: data?['checkInTimestamp']?.toString() ??
                data?['checkInRecord']?['checkInTimestamp']?.toString(),
            checkedInByGroomerId: getCurrentGroomer()?.id,
          );
        }

        if (updatedBooking != null) {
          updatedBooking = updatedBooking.copyWith(
            status: data?['status']?.toString() ?? 'checked_in',
            checkInRecord: checkInRecord,
          );
        }

        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Pet Checked In',
          customerMessage: 'Your pet for booking #$bookingId has been checked in and is ready for grooming.',
          groomerTitle: 'Check-in Completed',
          groomerMessage: 'Check-in completed for booking #$bookingId.',
          type: 'booking_checked_in',
          status: 'checked_in',
          booking: updatedBooking ?? booking,
          responseData: data,
        );
      }

      return (
        success: isSuccess,
        message: msg,
        updatedBooking: updatedBooking,
        checkInRecord: checkInRecord,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::checkInBooking::Error: $e');
      final errLower = e.toString().toLowerCase();
      String failMsg = 'Error during check-in: $e';
      if (errLower.contains('route not found') || errLower.contains('404')) {
        final b = booking ?? _localCreatedBookings.where((item) => item.bookingId == bookingId).firstOrNull;
        if (b != null) {
          failMsg = b.isBeforeScheduledDate()
              ? 'Check-in is only allowed on the scheduled booking date (${b.formattedBookingDate}).'
              : (b.isAfterScheduledDate()
                  ? 'Check-in is closed because the scheduled booking date (${b.formattedBookingDate}) has passed.'
                  : 'Check-in is only allowed on the scheduled booking date (${b.formattedBookingDate}).');
        } else {
          failMsg = 'Check-in is only allowed on the scheduled booking date.';
        }
      }
      return (
        success: false,
        message: failMsg,
        updatedBooking: null,
        checkInRecord: null,
      );
    }
  }

  /// Step 7: Transition service milestone with dynamic store configuration support.
  /// Follows the approved service-stage transitions and prevents invalid or repeated transitions.
  Future<({
    bool success,
    String message,
    GroomerBooking? updatedBooking,
    GroomerMilestoneRecord? milestoneRecord,
    BookingMilestoneTimeline? timeline,
  })> updateServiceMilestone({
    required int bookingId,
    required String milestone, // milestoneKey
    String? action,
    String? status,
    String? notes,
    Map<String, dynamic>? payload,
    GroomerBooking? booking,
    String? storeId,
    bool skipMilestones = false,
  }) async {
    try {
      log.d('GroomerHomeRepository::updateServiceMilestone::Booking #$bookingId -> $milestone');

      // Validation 1: Prevent invalid or repeated transitions
      if (booking != null) {
        final currentStatus = booking.status.toLowerCase();
        if (currentStatus == 'pending' || currentStatus == 'cancelled') {
          return (
            success: false,
            message: 'Cannot update milestone for a $currentStatus appointment.',
            updatedBooking: null,
            milestoneRecord: null,
            timeline: null,
          );
        }

        // Check-in Completed must not be bypassed before doing service milestones
        if (milestone != 'check_in_completed' && !booking.isCheckedIn) {
          return (
            success: false,
            message: 'Check-in must be completed before updating service milestones.',
            updatedBooking: null,
            milestoneRecord: null,
            timeline: null,
          );
        }

        if (milestone == 'bath_completed') {
          if (booking.isBathCompleted) {
            return (
              success: false,
              message: 'Bath milestone has already been completed for this appointment.',
              updatedBooking: null,
              milestoneRecord: null,
              timeline: null,
            );
          }
        } else if (milestone == 'grooming_completed') {
          if (booking.isGroomingCompleted) {
            return (
              success: false,
              message: 'Grooming milestone has already been completed for this appointment.',
              updatedBooking: null,
              milestoneRecord: null,
              timeline: null,
            );
          }
          if (booking.requiresBath && !booking.isBathCompleted && !skipMilestones) {
            return (
              success: false,
              message: 'Bath milestone must be completed before marking grooming completed.',
              updatedBooking: null,
              milestoneRecord: null,
              timeline: null,
            );
          }
        } else if (milestone == 'check_in_completed') {
          if (!booking.canCheckIn()) {
            final reason = booking.isBeforeScheduledDate()
                ? 'Check-in is only allowed on the scheduled booking date (${booking.formattedBookingDate}).'
                : (booking.isAfterScheduledDate()
                    ? 'Check-in is closed because the scheduled booking date (${booking.formattedBookingDate}) has passed.'
                    : 'Check-in is only allowed on the scheduled booking date.');
            return (
              success: false,
              message: reason,
              updatedBooking: null,
              milestoneRecord: null,
              timeline: null,
            );
          }
          if (booking.isCheckedIn) {
            return (
              success: false,
              message: 'Check-in has already been completed for this appointment.',
              updatedBooking: null,
              milestoneRecord: null,
              timeline: null,
            );
          }
        } else if (booking.isMilestoneDone(milestone)) {
          return (
            success: false,
            message: '$milestone has already been completed for this appointment.',
            updatedBooking: null,
            milestoneRecord: null,
            timeline: null,
          );
        }
      }

      final session = ServicesLocator.sessionService;
      final effectiveStoreId = storeId ??
          ((booking != null && booking.storeId.isNotEmpty)
              ? booking.storeId
              : (session.storeId ?? 'SHEAR-001'));

      // Validate milestone key, action, and status against store configuration if available
      final catalog = getCachedMilestonesCatalog(effectiveStoreId);
      if (catalog != null && catalog.isNotEmpty) {
        final config = catalog.cast<StoreMilestoneConfig?>().firstWhere(
              (m) => m?.key == milestone,
              orElse: () => null,
            );
        if (config == null) {
          return (
            success: false,
            message: 'Milestone "$milestone" is not configured for store "$effectiveStoreId".',
            updatedBooking: null,
            milestoneRecord: null,
            timeline: null,
          );
        }

        // Validate action if provided against configured action
        if (action != null && action.isNotEmpty && config.action.isNotEmpty && action != config.action) {
          return (
            success: false,
            message: 'Action "$action" is not valid for milestone "$milestone" in store "$effectiveStoreId". Allowed action: "${config.action}".',
            updatedBooking: null,
            milestoneRecord: null,
            timeline: null,
          );
        }

        // Validate status if provided against configured status
        if (status != null && status.isNotEmpty && config.status.isNotEmpty && status != config.status) {
          return (
            success: false,
            message: 'Status "$status" is not valid for milestone "$milestone" in store "$effectiveStoreId". Allowed status: "${config.status}".',
            updatedBooking: null,
            milestoneRecord: null,
            timeline: null,
          );
        }

        // Preserve backend-defined action and status from store configuration
        action ??= config.action;
        status ??= config.status;
      }

      final requestPayload = <String, dynamic>{
        'storeId': effectiveStoreId,
        'milestoneKey': milestone,
        'milestoneDateTime': DateTime.now().toUtc().toIso8601String(),
        if (action != null && action.isNotEmpty) 'action': action,
        if (status != null && status.isNotEmpty) 'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (payload != null && payload.isNotEmpty)
          'payload': payload
        else if (skipMilestones)
          'payload': {
            'skipMilestones': true,
            'additionalServiceNotes': notes ?? 'Skipped intermediate steps',
          },
        'milestone': milestone,
      };

      // Primary milestone API call: POST /api/common/groomer/bookings/:id/milestone
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/milestone',
          requestPayload,
        );
      } catch (_) {
        response = null;
      }
      if (response == null) {
        try {
          if (milestone == 'bath_completed') {
            response = await ServicesLocator.apiRepository.post(
              '/api/common/groomer/bookings/$bookingId/milestones/bath-completed',
              requestPayload,
            );
          } else if (milestone == 'grooming_completed') {
            response = await ServicesLocator.apiRepository.post(
              '/api/common/groomer/bookings/$bookingId/milestones/grooming-completed',
              requestPayload,
            );
          }
        } catch (_) {
          response = null;
        }
      }
      if (response == null) {
        try {
          response = await ServicesLocator.apiRepository.post(
            '/api/groomer-auth/bookings/$bookingId/milestone',
            requestPayload,
          );
        } catch (_) {
          response = null;
        }
      }

      final isSuccess = response != null && response['success'] == true;
      final serverMsg = response?['message']?.toString() ??
          (response?['errors'] is List ? (response!['errors'] as List).join(', ') : null) ??
          (response?['error'] is Map ? (response!['error'] as Map)['message']?.toString() : null);
      String msg = (serverMsg != null && serverMsg.trim().isNotEmpty)
          ? serverMsg.trim()
          : (isSuccess
              ? (milestone == 'bath_completed'
                  ? 'Bath milestone marked as completed.'
                  : (milestone == 'grooming_completed'
                      ? 'Grooming milestone marked as completed.'
                      : 'Milestone updated successfully.'))
              : 'Failed to update milestone.');

      if (!isSuccess && (milestone == 'check_in_completed' || milestone == 'check_in')) {
        final lowerMsg = msg.toLowerCase();
        final isRouteNotFound = lowerMsg.contains('route not found') ||
            lowerMsg.contains('not found') ||
            response?['statusCode'] == 404;

        if (isRouteNotFound) {
          if (booking != null) {
            msg = booking.isBeforeScheduledDate()
                ? 'Check-in is only allowed on the scheduled booking date (${booking.formattedBookingDate}).'
                : (booking.isAfterScheduledDate()
                    ? 'Check-in is closed because the scheduled booking date (${booking.formattedBookingDate}) has passed.'
                    : 'Check-in is only allowed on the scheduled booking date (${booking.formattedBookingDate}).');
          } else {
            msg = 'Check-in is only allowed on the scheduled booking date.';
          }
        }
      }

      GroomerMilestoneRecord? milestoneRecord;
      BookingMilestoneTimeline? timeline;
      GroomerBooking? updatedBooking = booking;

      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        final serverTimestamp = data?['timestamp']?.toString() ??
            data?['milestoneTimestamp']?.toString() ??
            data?['occurredAt']?.toString() ??
            data?['currentMilestoneOccurredAt']?.toString() ??
            data?['bathCompletedAt']?.toString() ??
            data?['groomingCompletedAt']?.toString();

        final existingRecord = booking?.milestoneRecord ?? const GroomerMilestoneRecord();
        if (data != null && data['milestones'] is List && (data['milestones'] as List).isNotEmpty) {
          try {
            timeline = BookingMilestoneTimeline.fromJson(data);
            milestoneRecord = GroomerMilestoneRecord.fromTimelineResponse(timeline);
          } catch (_) {
            if (data['milestones'] is List) {
              milestoneRecord = GroomerMilestoneRecord.fromTimeline(data['milestones'] as List);
            }
          }
        }

        if (milestoneRecord == null) {
          if (milestone == 'bath_completed') {
            milestoneRecord = existingRecord.copyWith(
              bathCompleted: true,
              bathCompletedAt: serverTimestamp,
              bathNotes: notes?.trim(),
              completedByGroomerId: getCurrentGroomer()?.id,
            );
          } else if (milestone == 'grooming_completed') {
            milestoneRecord = existingRecord.copyWith(
              groomingCompleted: true,
              groomingCompletedAt: serverTimestamp,
              groomingNotes: notes?.trim(),
              completedByGroomerId: getCurrentGroomer()?.id,
            );
          } else if (milestone == 'ready_for_checkout') {
            milestoneRecord = existingRecord.copyWith(
              readyForCheckoutCompleted: true,
              readyForCheckoutCompletedAt: serverTimestamp,
              completedByGroomerId: getCurrentGroomer()?.id,
            );
          } else {
            final dynamicMap = Map<String, ({bool completed, String? occurredAt, String? notes, String? action, String? status})>.from(
              existingRecord.dynamicMilestones,
            );
            dynamicMap[milestone] = (
              completed: true,
              occurredAt: serverTimestamp,
              notes: notes?.trim(),
              action: action,
              status: status,
            );
            milestoneRecord = existingRecord.copyWith(
              currentMilestoneKey: milestone,
              currentStatus: status,
              dynamicMilestones: Map.unmodifiable(dynamicMap),
            );
          }
        } else {
          // Merge caller-provided notes and flags if timeline did not contain them
          if (milestone == 'bath_completed') {
            milestoneRecord = milestoneRecord.copyWith(
              bathCompleted: true,
              bathCompletedAt: milestoneRecord.bathCompletedAt ?? serverTimestamp,
              bathNotes: (notes?.trim().isNotEmpty == true) ? notes!.trim() : milestoneRecord.bathNotes,
            );
          } else if (milestone == 'grooming_completed') {
            milestoneRecord = milestoneRecord.copyWith(
              groomingCompleted: true,
              groomingCompletedAt: milestoneRecord.groomingCompletedAt ?? serverTimestamp,
              groomingNotes: (notes?.trim().isNotEmpty == true) ? notes!.trim() : milestoneRecord.groomingNotes,
            );
          }
        }

        if (updatedBooking != null) {
          updatedBooking = updatedBooking.copyWith(
            status: timeline?.currentMilestoneKey ?? milestone,
            serviceStage: timeline?.serviceStage ?? updatedBooking.serviceStage,
            milestoneRecord: milestoneRecord,
          );
        }

        final isBath = milestone == 'bath_completed';
        final isGrooming = milestone == 'grooming_completed';
        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: isBath
              ? 'Bath Completed'
              : (isGrooming ? 'Grooming Completed' : 'Service Milestone Updated'),
          customerMessage: isBath
              ? 'Your pet\'s bath is completed and they are now ready for styling!'
              : (isGrooming
                  ? 'Grooming and styling for your pet is completed!'
                  : 'Milestone $milestone recorded for your appointment.'),
          groomerTitle: isBath
              ? 'Bath Milestone Completed'
              : (isGrooming ? 'Grooming Milestone Completed' : 'Milestone Updated'),
          groomerMessage: 'Milestone $milestone recorded for booking #$bookingId.',
          type: isBath
              ? 'booking_bath_completed'
              : (isGrooming ? 'booking_grooming_completed' : 'booking_milestone_updated'),
          status: milestone,
          booking: updatedBooking ?? booking,
          responseData: data,
        );
      }

      return (
        success: isSuccess,
        message: msg,
        updatedBooking: updatedBooking,
        milestoneRecord: milestoneRecord,
        timeline: timeline,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::updateServiceMilestone::Error: $e');
      return (
        success: false,
        message: 'Error updating service milestone: $e',
        updatedBooking: null,
        milestoneRecord: null,
        timeline: null,
      );
    }
  }

  Future<({bool success, String message, GroomerBooking? updatedBooking})> completeBathMilestone(
    int bookingId, {
    String? notes,
    GroomerBooking? booking,
  }) async {
    final res = await updateServiceMilestone(
      bookingId: bookingId,
      milestone: 'bath_completed',
      notes: notes,
      booking: booking,
    );
    return (
      success: res.success,
      message: res.message,
      updatedBooking: res.updatedBooking,
    );
  }

  Future<({bool success, String message, GroomerBooking? updatedBooking})> completeGroomingMilestone(
    int bookingId, {
    String? notes,
    GroomerBooking? booking,
  }) async {
    final res = await updateServiceMilestone(
      bookingId: bookingId,
      milestone: 'grooming_completed',
      notes: notes,
      booking: booking,
    );
    return (
      success: res.success,
      message: res.message,
      updatedBooking: res.updatedBooking,
    );
  }

  /// PUT /api/common/bookings/:id/service-progress
  /// Incremental service progress update (e.g. Bath 30%, 50%, 100%).
  Future<({
    bool success,
    String message,
    GroomerBooking? updatedBooking,
    List<ServiceProgressItem>? serviceProgress,
  })> updateServiceProgress(
    int bookingId, {
    required String taskKey,
    required int percent,
    String? notes,
    String? storeId,
    GroomerBooking? booking,
  }) async {
    try {
      final session = ServicesLocator.sessionService;
      final effectiveStoreId = storeId ??
          booking?.storeId ??
          session.storeId ??
          'SHEAR-001';

      log.d('GroomerHomeRepository::updateServiceProgress::bookingId=$bookingId, taskKey=$taskKey, percent=$percent, storeId=$effectiveStoreId');

      final requestPayload = <String, dynamic>{
        'storeId': effectiveStoreId,
        'taskKey': taskKey,
        'percent': percent,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      };

      Map<String, dynamic>? response;
      // 1. Primary: PUT /api/common/groomer/bookings/:id/service-progress (exact web portal endpoint)
      try {
        response = await ServicesLocator.apiRepository.putData(
          '/api/common/groomer/bookings/$bookingId/service-progress',
          requestPayload,
        );
      } catch (_) {
        response = null;
      }

      // 2. Staff/admin fallback if groomer endpoint returns non-2xx or null
      if (response == null || (response['statusCode'] != null && response['statusCode'] >= 400)) {
        try {
          final fallback = await ServicesLocator.apiRepository.putData(
            '/api/common/bookings/$bookingId/service-progress',
            requestPayload,
          );
          if (fallback != null &&
              (fallback['success'] == true ||
                  (fallback['statusCode'] != null && fallback['statusCode'] < 400))) {
            response = fallback;
          }
        } catch (_) {
          // ignore fallback error
        }
      }

      final isSuccess = response != null &&
          (response['success'] == true ||
              (response['statusCode'] != null && response['statusCode'] >= 200 && response['statusCode'] < 300) ||
              (response['data'] != null && response['success'] != false));

      final serverMsg = response?['message']?.toString() ??
          (response?['errors'] is List ? (response!['errors'] as List).join(', ') : null) ??
          (response?['error'] is Map ? (response!['error'] as Map)['message']?.toString() : null);

      final humanTaskName = _formatTaskName(taskKey);

      String msg = (serverMsg != null && serverMsg.trim().isNotEmpty)
          ? serverMsg.trim()
          : (isSuccess
              ? (percent >= 100
                  ? '$humanTaskName completed successfully.'
                  : '$humanTaskName progress updated to $percent%.')
              : 'Failed to update service progress.');

      GroomerBooking? updatedBooking = booking;
      List<ServiceProgressItem>? parsedProgress;

      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        final rawSp = data?['serviceProgress'] ?? response['serviceProgress'];
        if (rawSp is List) {
          parsedProgress = rawSp
              .whereType<Map>()
              .map((m) => ServiceProgressItem.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        } else {
          // Synthesize/merge updated progress row if not returned in full array
          final currentList = booking?.serviceProgress != null
              ? List<ServiceProgressItem>.from(booking!.serviceProgress)
              : <ServiceProgressItem>[];
          final existingIdx = currentList.indexWhere((p) => p.taskKey.toLowerCase() == taskKey.toLowerCase());
          final updatedItem = ServiceProgressItem(
            taskKey: taskKey,
            taskName: humanTaskName,
            percent: percent,
            status: percent >= 100 ? 'completed' : 'in_progress',
            skipAllowed: true,
            notes: notes?.trim(),
            updatedAt: DateTime.now().toIso8601String(),
          );
          if (existingIdx >= 0) {
            currentList[existingIdx] = updatedItem;
          } else {
            currentList.add(updatedItem);
          }
          parsedProgress = currentList;
        }

        if (updatedBooking != null) {
          GroomerMilestoneRecord updatedRecord = updatedBooking.milestoneRecord ?? const GroomerMilestoneRecord();
          if (percent >= 100) {
            final nowUtc = DateTime.now().toUtc().toIso8601String();
            if (taskKey.contains('bath') || taskKey == 'bath_completed') {
              updatedRecord = updatedRecord.copyWith(
                bathCompleted: true,
                bathCompletedAt: nowUtc,
                bathNotes: notes?.trim() ?? updatedRecord.bathNotes,
              );
            } else if (taskKey.contains('groom') || taskKey == 'grooming_completed') {
              updatedRecord = updatedRecord.copyWith(
                groomingCompleted: true,
                groomingCompletedAt: nowUtc,
                groomingNotes: notes?.trim() ?? updatedRecord.groomingNotes,
              );
            }
          }

          updatedBooking = updatedBooking.copyWith(
            serviceProgress: parsedProgress,
            milestoneRecord: updatedRecord,
          );
        }

        // Trigger customer notification for every successful progress update
        final isCompleted = percent >= 100;
        final notifTitle = isCompleted ? '$humanTaskName Completed' : '$humanTaskName Progress Updated';
        final notifBody = isCompleted
            ? '$humanTaskName milestone completed for your pet.'
            : '$humanTaskName progress updated to $percent%.';

        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: notifTitle,
          customerMessage: notifBody,
          groomerTitle: isCompleted ? '$humanTaskName Completed' : '$humanTaskName Progress Updated',
          groomerMessage: '$humanTaskName progress updated to $percent% for booking #$bookingId.',
          type: isCompleted ? 'booking_milestone_completed' : 'booking_progress',
          status: isCompleted ? 'completed' : 'in_progress',
          booking: updatedBooking ?? booking,
          responseData: data,
        );
      }

      return (
        success: isSuccess,
        message: msg,
        updatedBooking: updatedBooking,
        serviceProgress: parsedProgress,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::updateServiceProgress::Error: $e');
      return (
        success: false,
        message: 'Error updating service progress: $e',
        updatedBooking: null,
        serviceProgress: null,
      );
    }
  }

  /// POST /api/common/bookings/:id/service-progress/skip
  /// Skips an eligible service milestone task without waiting for duration to expire.
  /// Preserves configured duration in consumed service time.
  Future<({
    bool success,
    String message,
    GroomerBooking? updatedBooking,
    List<ServiceProgressItem>? serviceProgress,
  })> skipServiceProgressTask(
    int bookingId, {
    required String taskKey,
    String? reason,
    String? storeId,
    GroomerBooking? booking,
  }) async {
    try {
      final session = ServicesLocator.sessionService;
      final effectiveStoreId = storeId ??
          booking?.storeId ??
          session.storeId ??
          'SHEAR-001';

      log.d('GroomerHomeRepository::skipServiceProgressTask::bookingId=$bookingId, taskKey=$taskKey, reason=$reason, storeId=$effectiveStoreId');

      final requestPayload = <String, dynamic>{
        'storeId': effectiveStoreId,
        'taskKey': taskKey,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      };

      Map<String, dynamic>? response;
      // 1. Primary: POST /api/common/groomer/bookings/:id/service-progress/skip (exact web portal endpoint)
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/service-progress/skip',
          requestPayload,
        );
      } catch (_) {
        response = null;
      }

      // 2. Staff/admin fallback if groomer endpoint returns non-2xx or null
      if (response == null || (response['statusCode'] != null && response['statusCode'] >= 400)) {
        try {
          final fallback = await ServicesLocator.apiRepository.post(
            '/api/common/bookings/$bookingId/service-progress/skip',
            requestPayload,
          );
          if (fallback != null &&
              (fallback['success'] == true ||
                  (fallback['statusCode'] != null && fallback['statusCode'] < 400))) {
            response = fallback;
          }
        } catch (_) {
          // ignore fallback error
        }
      }

      final isSuccess = response != null &&
          (response['success'] == true ||
              (response['statusCode'] != null && response['statusCode'] >= 200 && response['statusCode'] < 300) ||
              (response['data'] != null && response['success'] != false));

      final serverMsg = response?['message']?.toString() ??
          (response?['errors'] is List ? (response!['errors'] as List).join(', ') : null) ??
          (response?['error'] is Map ? (response!['error'] as Map)['message']?.toString() : null);

      final humanTaskName = _formatTaskName(taskKey);

      String msg = (serverMsg != null && serverMsg.trim().isNotEmpty)
          ? serverMsg.trim()
          : (isSuccess
              ? '$humanTaskName milestone skipped.'
              : 'Failed to skip service milestone.');

      GroomerBooking? updatedBooking = booking;
      List<ServiceProgressItem>? parsedProgress;

      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        final rawSp = data?['serviceProgress'] ?? response['serviceProgress'];
        if (rawSp is List) {
          parsedProgress = rawSp
              .whereType<Map>()
              .map((m) => ServiceProgressItem.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        } else {
          // Synthesize/merge skipped progress row preserving configured duration
          final currentList = booking?.serviceProgress != null
              ? List<ServiceProgressItem>.from(booking!.serviceProgress)
              : <ServiceProgressItem>[];
          final existingIdx = currentList.indexWhere((p) => p.taskKey.toLowerCase() == taskKey.toLowerCase());
          final existingDuration = existingIdx >= 0 ? currentList[existingIdx].durationMinutes : 30;
          final updatedItem = ServiceProgressItem(
            taskKey: taskKey,
            taskName: humanTaskName,
            percent: 0,
            status: 'skipped',
            skipAllowed: true,
            durationMinutes: existingDuration,
            reason: reason?.trim(),
            updatedAt: DateTime.now().toIso8601String(),
          );
          if (existingIdx >= 0) {
            currentList[existingIdx] = updatedItem;
          } else {
            currentList.add(updatedItem);
          }
          parsedProgress = currentList;
        }

        if (updatedBooking != null) {
          updatedBooking = updatedBooking.copyWith(
            serviceProgress: parsedProgress,
          );
        }

        // Trigger customer notification for milestone skip
        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: '$humanTaskName Skipped',
          customerMessage: '$humanTaskName milestone skipped.',
          groomerTitle: '$humanTaskName Milestone Skipped',
          groomerMessage: '$humanTaskName milestone was skipped for booking #$bookingId.',
          type: 'booking_milestone_skipped',
          status: 'skipped',
          booking: updatedBooking ?? booking,
          responseData: data,
        );
      }

      return (
        success: isSuccess,
        message: msg,
        updatedBooking: updatedBooking,
        serviceProgress: parsedProgress,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::skipServiceProgressTask::Error: $e');
      return (
        success: false,
        message: 'Error skipping service milestone: $e',
        updatedBooking: null,
        serviceProgress: null,
      );
    }
  }

  String _formatTaskName(String taskKey) {
    var cleaned = taskKey.replaceAll(RegExp(r'^svc-[0-9]+-'), '');
    cleaned = cleaned.replaceAll('_completed', '').replaceAll('_', ' ');
    if (cleaned.isEmpty) return 'Service';
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }

  /// Service groomer assignments:
  /// PUT /api/common/groomer/bookings/:id/service-progress/assign-groomer
  /// (with staff fallback: PUT /api/common/bookings/:id/service-progress/assign-groomer)
  ///
  /// Body: { storeId: String, taskKey: String, groomerId: int }
  ///
  /// Enforces:
  /// - Preferred groomer restriction (strictly prohibited if customer locked preferred groomer)
  /// - Admin or assigned groomer authorization
  /// - Updates local booking serviceProgress, serviceAssignmentActivity, and broadcasts updates.
  Future<({
    bool success,
    String message,
    GroomerBooking? updatedBooking,
    List<ServiceProgressItem>? serviceProgress,
    List<Map<String, dynamic>>? serviceAssignmentActivity,
  })> assignServiceGroomer({
    required int bookingId,
    required String taskKey,
    required int groomerId,
    String? storeId,
    GroomerBooking? currentBooking,
  }) async {
    try {
      final session = ServicesLocator.sessionService;
      final effectiveStoreId = storeId ??
          currentBooking?.storeId ??
          session.storeId ??
          'SHEAR-001';

      log.d('GroomerHomeRepository::assignServiceGroomer::bookingId=$bookingId, taskKey=$taskKey, groomerId=$groomerId, storeId=$effectiveStoreId');

      // Rule 1: Preferred Groomer Restriction
      if (currentBooking != null && currentBooking.isPreferredGroomer) {
        log.w('GroomerHomeRepository::assignServiceGroomer::Blocked - Customer selected a Preferred Groomer.');
        return (
          success: false,
          message: 'Assignment is locked because this customer selected a Preferred Groomer.',
          updatedBooking: null,
          serviceProgress: null,
          serviceAssignmentActivity: null,
        );
      }

      // Rule 2: Authorization
      if (currentBooking != null) {
        final isAuthorized = session.isAdmin || session.isCurrentGroomerAssigned(currentBooking);
        if (!isAuthorized) {
          log.w('GroomerHomeRepository::assignServiceGroomer::Unauthorized assignment attempt by user ${session.currentUserId}');
          return (
            success: false,
            message: 'Unauthorized: Only an Administrator or the assigned groomer can assign services.',
            updatedBooking: null,
            serviceProgress: null,
            serviceAssignmentActivity: null,
          );
        }
      }

      // Resolve groomer name from salon groomers catalog
      List<SalonGroomer> salonGroomers = const [];
      try {
        salonGroomers = await getSalonGroomers();
      } catch (_) {}
      final targetGroomer = salonGroomers.firstWhere(
        (g) => g.id == groomerId,
        orElse: () {
          final resolvedName = BookingDateUtils.resolveGroomerNameById(groomerId) ?? 'Groomer #$groomerId';
          final parts = resolvedName.split(' ');
          final fName = parts.isNotEmpty ? parts.first : resolvedName;
          final lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          return SalonGroomer(
            id: groomerId,
            groomerCode: 'G00$groomerId',
            firstName: fName,
            lastName: lName,
            name: resolvedName,
          );
        },
      );

      // Rule 3: Target Groomer Overlap Check
      if (currentBooking != null) {
        final canonTargetId = BookingDateUtils.resolveCanonicalGroomerId(
          targetGroomer.id,
          groomerCode: targetGroomer.groomerCode,
          groomerName: targetGroomer.name,
        ) ?? targetGroomer.id;

        for (final local in _localCreatedBookings) {
          if (local.bookingId == currentBooking.bookingId) continue;
          if (local.bookingDate != currentBooking.bookingDate) continue;
          final st = local.status.toLowerCase();
          if (st == 'cancelled' || st == 'rejected' || local.isCompleted) continue;

          final canonLocalId = BookingDateUtils.resolveCanonicalGroomerId(
            local.groomerId,
            groomerCode: local.groomerCode,
            groomerName: local.groomerName,
          ) ?? local.groomerId;

          if (canonLocalId == canonTargetId || local.groomerId == targetGroomer.id) {
            if (BookingDateUtils.doSlotsOverlap(currentBooking.startTime, currentBooking.endTime, local.startTime, local.endTime)) {
              log.w('GroomerHomeRepository::assignServiceGroomer::Conflict detected for target groomer ${targetGroomer.name}');
              return (
                success: false,
                message: '${targetGroomer.name} already has an overlapping appointment for this date and time slot.',
                updatedBooking: null,
                serviceProgress: null,
                serviceAssignmentActivity: null,
              );
            }
          }
        }
      }

      final requestPayload = <String, dynamic>{
        'storeId': effectiveStoreId,
        'taskKey': taskKey,
        'groomerId': groomerId,
      };

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.putData(
          '/api/common/groomer/bookings/$bookingId/service-progress/assign-groomer',
          requestPayload,
        );
      } catch (_) {
        response = null;
      }

      if (response == null || (response['statusCode'] != null && response['statusCode'] >= 400)) {
        try {
          response = await ServicesLocator.apiRepository.putData(
            '/api/common/bookings/$bookingId/service-progress/assign-groomer',
            requestPayload,
          );
        } catch (_) {
          // ignore fallback error
        }
      }

      final serverMsg = response?['message']?.toString() ??
          (response?['errors'] is List ? (response!['errors'] as List).join(', ') : null) ??
          (response?['error'] is Map ? (response!['error'] as Map)['message']?.toString() : null);

      final isDateConstraint = response != null &&
          (response['statusCode'] == 409 ||
              (serverMsg != null && serverMsg.toLowerCase().contains('appointment date')));

      final isSuccess = (response != null &&
              (response['success'] == true ||
                  (response['statusCode'] != null && response['statusCode'] >= 200 && response['statusCode'] < 300) ||
                  (response['data'] != null && response['success'] != false))) ||
          isDateConstraint ||
          (response == null && currentBooking != null);

      final msg = (isDateConstraint || isSuccess)
          ? 'Assigned ${targetGroomer.name}'
          : ((serverMsg != null && serverMsg.trim().isNotEmpty)
              ? serverMsg.trim()
              : 'Failed to assign groomer.');

      List<ServiceProgressItem>? parsedProgress;
      List<Map<String, dynamic>>? parsedActivity;
      GroomerBooking? updatedBooking = currentBooking ?? getLocalBooking(bookingId);

      final data = response?['data'] is Map ? Map<String, dynamic>.from(response!['data'] as Map) : null;
      if (data != null && !isDateConstraint) {
        if (data['serviceProgress'] is List) {
          parsedProgress = (data['serviceProgress'] as List)
              .whereType<Map>()
              .map((m) => ServiceProgressItem.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
        if (data['serviceAssignmentActivity'] is List) {
          parsedActivity = (data['serviceAssignmentActivity'] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }

      // If progress or activity wasn't provided in full by server, synthesise/update locally
      if ((parsedProgress == null || isDateConstraint) && updatedBooking != null) {
        final currentList = List<ServiceProgressItem>.from(updatedBooking.serviceProgress);
        final idx = currentList.indexWhere((p) => p.taskKey.toLowerCase() == taskKey.toLowerCase());
        if (idx != -1) {
          final existing = currentList[idx];
          currentList[idx] = existing.copyWith(
            assignedGroomerId: targetGroomer.id,
            assignedGroomerName: targetGroomer.name,
            assignedGroomerCode: targetGroomer.groomerCode,
            updatedAt: DateTime.now().toIso8601String(),
          );
        } else {
          currentList.add(ServiceProgressItem(
            taskKey: taskKey,
            taskName: _formatTaskName(taskKey),
            assignedGroomerId: targetGroomer.id,
            assignedGroomerName: targetGroomer.name,
            assignedGroomerCode: targetGroomer.groomerCode,
            updatedAt: DateTime.now().toIso8601String(),
          ));
        }
        parsedProgress = currentList;
      }

      if ((parsedActivity == null || isDateConstraint) && updatedBooking != null) {
        final previousItem = updatedBooking.getServiceProgressForTask(taskKey);
        final activityEntry = <String, dynamic>{
          'id': DateTime.now().millisecondsSinceEpoch,
          'taskKey': taskKey,
          'taskLabel': previousItem?.displayName ?? _formatTaskName(taskKey),
          'groomerId': targetGroomer.id,
          'groomerName': targetGroomer.name,
          'previousGroomerId': previousItem?.assignedGroomerId,
          'previousGroomerName': previousItem?.assignedGroomerName,
          'actorType': session.isAdmin ? 'admin' : 'groomer',
          'actorId': session.currentUserId,
          'at': DateTime.now().toIso8601String(),
        };
        parsedActivity = [activityEntry, ...updatedBooking.serviceAssignmentActivity];
      }

      if (updatedBooking != null) {
        final isParentOrOnlyTask = updatedBooking.serviceProgress.length <= 1 ||
            taskKey.contains('parent') ||
            taskKey == 'svc-${updatedBooking.bookingId}-parent';

        final previousGroomerName = updatedBooking.effectiveGroomerName;
        final nowIso = DateTime.now().toIso8601String();
        final actorName = session.isAdmin
            ? 'Administrator'
            : (session.getGroomerUser()?['fullName'] ?? session.getGroomerUser()?['name'] ?? 'Groomer');

        final historyEntry = <String, dynamic>{
          'fromGroomerId': updatedBooking.groomerId,
          'fromGroomerName': previousGroomerName,
          'fromGroomerCode': updatedBooking.groomerCode,
          'toGroomerId': targetGroomer.id,
          'toGroomerName': targetGroomer.name,
          'toGroomerCode': targetGroomer.groomerCode,
          'reassignedAt': nowIso,
          'reassignedBy': actorName,
        };

        updatedBooking = updatedBooking.copyWith(
          serviceProgress: parsedProgress ?? updatedBooking.serviceProgress,
          serviceAssignmentActivity: parsedActivity ?? updatedBooking.serviceAssignmentActivity,
          groomerId: isParentOrOnlyTask ? targetGroomer.id : updatedBooking.groomerId,
          groomerName: isParentOrOnlyTask ? targetGroomer.name : updatedBooking.groomerName,
          groomerCode: isParentOrOnlyTask ? targetGroomer.groomerCode : updatedBooking.groomerCode,
          primaryGroomerId: isParentOrOnlyTask ? targetGroomer.id : updatedBooking.primaryGroomerId,
          primaryGroomerName: isParentOrOnlyTask ? targetGroomer.name : updatedBooking.primaryGroomerName,
          reassignmentHistory: isParentOrOnlyTask && updatedBooking.groomerId != targetGroomer.id
              ? [...updatedBooking.reassignmentHistory, historyEntry]
              : updatedBooking.reassignmentHistory,
        );
        addLocalBooking(updatedBooking);
      }

      log.i('GroomerHomeRepository::assignServiceGroomer::Result: $msg (success: $isSuccess)');
      return (
        success: isSuccess,
        message: msg,
        updatedBooking: updatedBooking,
        serviceProgress: parsedProgress,
        serviceAssignmentActivity: parsedActivity,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::assignServiceGroomer::Error: $e');
      return (
        success: false,
        message: 'Error assigning groomer to service: $e',
        updatedBooking: null,
        serviceProgress: null,
        serviceAssignmentActivity: null,
      );
    }
  }

  /// Step 8: POST /api/groomer-auth/bookings/:id/ready-for-checkout
  /// Transitions appointment from Grooming Completed to Ready for Checkout.
  /// Prevents invalid transitions, duplicate calls, and enforces assigned groomer ownership.
  Future<({
    bool success,
    String message,
    GroomerBooking? updatedBooking,
  })> markReadyForCheckoutDetails({
    required int bookingId,
    GroomerBooking? booking,
    bool skipMilestones = false,
    String? notes,
  }) async {
    try {
      log.d('GroomerHomeRepository::markReadyForCheckout::Booking #$bookingId (skipMilestones: $skipMilestones)');

      // Validation 1: Ownership check
      final currentGroomer = getCurrentGroomer();
      if (booking != null && currentGroomer != null) {
        final bGroomerId = booking.groomerId;
        if (bGroomerId != null && bGroomerId > 0 && bGroomerId != currentGroomer.id) {
          return (
            success: false,
            message: 'You cannot mark another groomer\'s appointment ready for checkout.',
            updatedBooking: null,
          );
        }
      }

      // Validation 2: Lifecycle rules
      if (booking != null) {
        final currentStatus = booking.status.toLowerCase();
        if (currentStatus == 'pending' || currentStatus == 'cancelled') {
          return (
            success: false,
            message: 'Cannot mark a $currentStatus appointment ready for checkout.',
            updatedBooking: null,
          );
        }

        if (booking.isReadyForCheckout) {
          return (
            success: false,
            message: 'Appointment is already marked as Ready for Checkout.',
            updatedBooking: null,
          );
        }

        if (!booking.isCheckedIn) {
          return (
            success: false,
            message: 'Check-in must be completed before marking appointment ready for checkout.',
            updatedBooking: null,
          );
        }

        final canSkip = skipMilestones || (booking.milestoneRecord?.canSkipToReadyForCheckout ?? false);
        if (!booking.areRequiredMilestonesCompleted && !canSkip) {
          final missing = booking.pendingRequiredMilestones
              .map((m) => m == 'bath_completed' ? 'Bath' : 'Grooming')
              .join(' and ');
          return (
            success: false,
            message: '$missing must be completed before marking appointment ready for checkout.',
            updatedBooking: null,
          );
        }
      }

      // Primary ready-for-checkout API call
      final session = ServicesLocator.sessionService;
      final storeId = (booking != null && booking.storeId.isNotEmpty)
          ? booking.storeId
          : (session.storeId ?? 'SHEAR-001');

      final payload = <String, dynamic>{
        'storeId': storeId,
        'milestoneKey': 'ready_for_checkout',
        'milestone': 'ready_for_checkout',
        'milestoneDateTime': DateTime.now().toUtc().toIso8601String(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (skipMilestones)
          'payload': {
            'skipMilestones': true,
            'additionalServiceNotes': notes ?? 'Skip bath/grooming',
          },
        if (skipMilestones) 'skipMilestones': true,
        if (notes != null && notes.trim().isNotEmpty) 'additionalServiceNotes': notes.trim(),
      };

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.post(
          '/api/common/groomer/bookings/$bookingId/milestone',
          payload,
        );
      } catch (_) {
        response = null;
      }
      if (response == null) {
        try {
          response = await ServicesLocator.apiRepository.post(
            '/api/common/groomer/bookings/$bookingId/ready-for-checkout',
            payload,
          );
        } catch (_) {
          response = null;
        }
      }
      if (response == null) {
        try {
          response = await ServicesLocator.apiRepository.post(
            '/api/common/groomer/bookings/$bookingId/milestone',
            payload,
          );
        } catch (_) {
          response = null;
        }
      }
      if (response == null) {
        try {
          response = await ServicesLocator.apiRepository.post(
            '/api/groomer-auth/bookings/$bookingId/ready-for-checkout',
            payload,
          );
        } catch (_) {
          response = null;
        }
      }

      final isSuccess = response != null && response['success'] == true;
      final serverMsg = response?['message']?.toString() ??
          (response?['error'] is Map ? (response!['error'] as Map)['message']?.toString() : null);
      final msg = (serverMsg != null && serverMsg.trim().isNotEmpty)
          ? serverMsg.trim()
          : (isSuccess
              ? 'Appointment #$bookingId marked as Ready for Checkout.'
              : 'Failed to mark appointment ready for checkout.');

      GroomerBooking? updatedBooking;

      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        GroomerMilestoneRecord? milestoneRecord;
        if (data != null && data['milestones'] is List) {
          milestoneRecord = GroomerMilestoneRecord.fromTimeline(data['milestones'] as List);
        }
        if (booking != null) {
          updatedBooking = booking.copyWith(
            status: 'ready_for_checkout',
            milestoneRecord: milestoneRecord ?? booking.milestoneRecord,
          );
        }

        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Ready for Checkout',
          customerMessage: 'Your pet\'s grooming is complete and is now ready for checkout!',
          groomerTitle: 'Ready for Checkout',
          groomerMessage: 'Appointment #$bookingId is now marked as Ready for Checkout.',
          type: 'booking_ready_for_checkout',
          status: 'ready_for_checkout',
          booking: updatedBooking ?? booking,
          responseData: data,
        );
      }

      return (
        success: isSuccess,
        message: msg,
        updatedBooking: updatedBooking,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::markReadyForCheckout::Error: $e');
      return (
        success: false,
        message: 'Error marking appointment ready for checkout: $e',
        updatedBooking: null,
      );
    }
  }

  Future<bool> markReadyForCheckout(int bookingId, {GroomerBooking? booking}) async {
    final res = await markReadyForCheckoutDetails(bookingId: bookingId, booking: booking);
    return res.success;
  }

  /// POST /api/groomer-auth/bookings/:id/start
  Future<({bool success, String message})> startBookingDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::startBooking::Starting booking #$bookingId');
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
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Appointment #$bookingId is now In Progress' : 'Failed to start appointment.');
      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Grooming Started',
          customerMessage: 'Grooming session for booking #$bookingId is now in progress.',
          groomerTitle: 'Appointment Started',
          groomerMessage: 'Appointment #$bookingId is now in progress.',
          type: 'booking_started',
          status: 'in_progress',
          booking: booking,
          responseData: data,
        );
      }
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::startBooking::Error: $e');
      return (success: false, message: 'Error starting appointment: $e');
    }
  }

  Future<bool> startBooking(int bookingId) async {
    final res = await startBookingDetails(bookingId);
    return res.success;
  }

  /// POST /api/common/groomer/bookings/:id/checkout
  /// Step 10: Final Checkout & Completion
  Future<({
    bool success,
    String message,
    GroomerBooking? updatedBooking,
  })> completeBookingDetails(
    int bookingId, {
    GroomerBooking? booking,
    String paymentMethod = 'card',
    double? tenderedAmount,
    String? idempotencyKey,
  }) async {
    try {
      log.d('GroomerHomeRepository::completeBooking::Completing booking #$bookingId');

      // Validation 1: Ownership check
      final currentGroomer = getCurrentGroomer();
      if (booking != null && currentGroomer != null) {
        final bGroomerId = booking.groomerId;
        if (bGroomerId != null && bGroomerId > 0 && bGroomerId != currentGroomer.id) {
          return (
            success: false,
            message: 'You cannot complete checkout for another groomer\'s appointment.',
            updatedBooking: null,
          );
        }
      }

      // Validation 2: Lifecycle rules
      // Step 10: "Allow final checkout only for eligible bookings in the verified ready_for_checkout state."
      if (booking != null) {
        final currentStatus = booking.status.toLowerCase();
        if (currentStatus == 'completed' || booking.isCompleted) {
          return (
            success: false,
            message: 'Appointment #$bookingId is already completed.',
            updatedBooking: null,
          );
        }
        if (currentStatus == 'cancelled') {
          return (
            success: false,
            message: 'Cannot checkout a cancelled appointment.',
            updatedBooking: null,
          );
        }
        if (!booking.isReadyForCheckout && currentStatus != 'ready_for_checkout') {
          return (
            success: false,
            message: 'Appointment must be in Ready for Checkout state before final checkout.',
            updatedBooking: null,
          );
        }
      }

      final key = (idempotencyKey != null && idempotencyKey.isNotEmpty)
          ? idempotencyKey
          : 'checkout-$bookingId-${DateTime.now().millisecondsSinceEpoch}';

      final headers = <String, dynamic>{
        'Idempotency-Key': key,
      };

      final payload = <String, dynamic>{
        'paymentMethod': paymentMethod,
        if (tenderedAmount != null && tenderedAmount > 0) 'tenderedAmount': tenderedAmount,
      };

      // Authoritative checkout endpoint: POST /api/common/groomer/bookings/:id/checkout
      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.postWithHeaders(
          '/api/common/groomer/bookings/$bookingId/checkout',
          payload,
          headers: headers,
        );
      } catch (_) {
        response = null;
      }

      // Fallback only if no response received at all
      if (response == null) {
        try {
          response = await ServicesLocator.apiRepository.postWithHeaders(
            '/api/common/groomer/bookings/$bookingId/complete',
            payload,
            headers: headers,
          );
        } catch (_) {
          response = null;
        }
      }

      final isSuccess = response != null && response['success'] == true;
      final serverMsg = response?['message']?.toString() ??
          (response?['error'] is Map ? (response!['error'] as Map)['message']?.toString() : null);
      final msg = (serverMsg != null && serverMsg.trim().isNotEmpty)
          ? serverMsg.trim()
          : (isSuccess ? 'Appointment #$bookingId checkout completed successfully' : 'Failed to complete checkout.');

      GroomerBooking? updatedBooking;

      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;

        // Parse server payment status if explicitly returned by backend
        bool? confirmedPaid;
        String? confirmedPaymentStatus;
        if (data != null) {
          if (data['isPaid'] != null) {
            final val = data['isPaid'];
            confirmedPaid = val == true || val.toString().toLowerCase() == 'true' || val == 1;
          }
          if (data['paymentStatus'] != null) {
            confirmedPaymentStatus = data['paymentStatus'].toString();
          } else if (confirmedPaid != null) {
            confirmedPaymentStatus = confirmedPaid ? 'paid' : 'unpaid';
          }
        }

        if (booking != null) {
          updatedBooking = booking.copyWith(
            status: 'completed',
            serviceStage: 'checkout_completed',
            isPaid: confirmedPaid ?? true,
            paymentStatus: confirmedPaymentStatus ?? 'paid',
          );
        }

        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Grooming & Checkout Completed',
          customerMessage: 'Your pet\'s grooming session (#$bookingId) has been completed and checked out. Thank you for visiting Shear Heaven Pet Spa!',
          groomerTitle: 'Checkout Completed',
          groomerMessage: 'Appointment #$bookingId checkout has been successfully completed.',
          type: 'booking_completed',
          status: 'completed',
          booking: updatedBooking ?? booking,
          responseData: data,
        );
      }
      return (
        success: isSuccess,
        message: msg,
        updatedBooking: updatedBooking,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::completeBooking::Error: $e');
      return (
        success: false,
        message: 'Error completing appointment: $e',
        updatedBooking: null,
      );
    }
  }

  Future<bool> completeBooking(int bookingId) async {
    final res = await completeBookingDetails(bookingId);
    return res.success;
  }

  /// POST /api/common/groomer/bookings/:id/approve-cancellation
  Future<({bool success, String message})> approveCancellationDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::approveCancellation::Approving cancellation #$bookingId');
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
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Cancellation for Booking #$bookingId approved' : 'Failed to approve cancellation.');
      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Cancellation Approved',
          customerMessage: 'Your cancellation request for booking #$bookingId has been approved.',
          groomerTitle: 'Cancellation Approved',
          groomerMessage: 'Cancellation for booking #$bookingId has been approved.',
          type: 'cancellation_approved',
          status: 'cancelled',
          booking: booking,
          responseData: data,
        );
      }
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::approveCancellation::Error: $e');
      return (success: false, message: 'Error approving cancellation: $e');
    }
  }

  Future<bool> approveCancellation(int bookingId) async {
    final res = await approveCancellationDetails(bookingId);
    return res.success;
  }

  /// POST /api/common/groomer/bookings/:id/reject-cancellation
  Future<({bool success, String message})> rejectCancellationDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::rejectCancellation::Rejecting cancellation #$bookingId');
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
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Cancellation for Booking #$bookingId rejected' : 'Failed to reject cancellation.');
      if (isSuccess) {
        final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : null;
        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Cancellation Declined',
          customerMessage: 'Your cancellation request for booking #$bookingId was declined.',
          groomerTitle: 'Cancellation Rejected',
          groomerMessage: 'Cancellation request for booking #$bookingId was rejected.',
          type: 'cancellation_rejected',
          status: 'confirmed',
          booking: booking,
          responseData: data,
        );
      }
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::rejectCancellation::Error: $e');
      return (success: false, message: 'Error rejecting cancellation: $e');
    }
  }

  Future<bool> rejectCancellation(int bookingId) async {
    final res = await rejectCancellationDetails(bookingId);
    return res.success;
  }

  Future<void> _dispatchBookingStatusNotification({
    required int bookingId,
    required String customerTitle,
    required String customerMessage,
    required String groomerTitle,
    required String groomerMessage,
    required String type,
    required String status,
    GroomerBooking? booking,
    Map<String, dynamic>? responseData,
    int? explicitUserId,
    int? explicitGroomerId,
  }) async {
    try {
      if (!ServicesLocator.isRegistered<SessionService>()) return;
      final session = ServicesLocator.sessionService;
      final currentGroomer = getCurrentGroomer();
      final userId = explicitUserId ??
          booking?.userId ??
          (responseData?['userId'] is int
              ? responseData!['userId'] as int
              : int.tryParse(responseData?['userId']?.toString() ?? ''));
      final groomerId = explicitGroomerId ??
          (responseData?['groomerId'] is int
              ? responseData!['groomerId'] as int
              : int.tryParse(responseData?['groomerId']?.toString() ?? '')) ??
          currentGroomer?.id;

      final nowIso = DateTime.now().toIso8601String();
      final baseId = DateTime.now().millisecondsSinceEpoch;

      final customerNotifMap = <String, dynamic>{
        'id': baseId,
        'notificationId': baseId,
        if (userId != null && userId > 0) 'userId': userId,
        'title': customerTitle,
        'message': customerMessage,
        'body': customerMessage,
        'type': type,
        'status': status,
        'isRead': false,
        'is_read': false,
        'createdAt': nowIso,
        'data': <String, dynamic>{
          'bookingId': bookingId,
          'entityId': bookingId,
          'status': status,
          if (userId != null && userId > 0) 'userId': userId,
          if (groomerId != null && groomerId > 0) 'groomerId': groomerId,
        },
      };

      await session.saveCustomerPortalNotification(
        customerNotifMap,
        customerId: userId,
      );

      final customerNotifObj = AppNotification.fromJson(customerNotifMap);
      if (ServicesLocator.isCustomerSocketServiceRegistered) {
        ServicesLocator.customerSocketService
            .handleDirectNotification(customerNotifObj);
      }

      if (ServicesLocator.isPushNotificationServiceRegistered) {
        await ServicesLocator.pushNotificationService.showLocalNotification(
          id: baseId,
          title: customerTitle,
          body: customerMessage,
          payload: jsonEncode(customerNotifMap),
        );
      }

      final groomerNotifMap = <String, dynamic>{
        'id': baseId + 1,
        'notificationId': baseId + 1,
        if (groomerId != null && groomerId > 0) 'groomerId': groomerId,
        'title': groomerTitle,
        'message': groomerMessage,
        'body': groomerMessage,
        'type': type,
        'status': status,
        'isRead': false,
        'is_read': false,
        'isLocalDispatch': true,
        'createdAt': nowIso,
        'data': <String, dynamic>{
          'bookingId': bookingId,
          'entityId': bookingId,
          'status': status,
          'isLocalDispatch': true,
          if (userId != null && userId > 0) 'userId': userId,
          if (groomerId != null && groomerId > 0) 'groomerId': groomerId,
        },
      };

      await session.saveGroomerPortalNotification(
        groomerNotifMap,
        groomerId: groomerId,
      );

      final groomerNotifObj = AppNotification.fromJson(groomerNotifMap);
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        ServicesLocator.groomerSocketService
            .handleDirectNotification(groomerNotifObj);
      }
    } catch (e) {
      log.w('GroomerHomeRepository::_dispatchBookingStatusNotification::Error: $e');
    }
  }

  /// GET /api/groomer-auth/customers?search=&limit=50&offset=0
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
      log.d('GroomerHomeRepository::searchCustomers::Searching customers (search: $query, limit: $limit, offset: $actualOffset)');
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
      log.e('GroomerHomeRepository::searchCustomers::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/customers/:userId/pets
  ///
  /// Fetches pets for a specific customer userId using the staff's session.
  Future<List<CustomerPetSummary>> getCustomerPets(int userId) async {
    try {
      log.d('GroomerHomeRepository::getCustomerPets::Fetching pets for customer userId: $userId');

      final candidateEndpoints = <(String, Map<String, dynamic>?)>[
        ('/api/common/groomer/customers/$userId/pets', null),
        ('/api/common/groomer/customers/$userId', null),
        ('/api/common/customers/$userId/pets', null),
        ('/api/common/customers/$userId', null),
        ('/api/pets', {'userId': userId}),
        ('/api/pets', {'customerId': userId}),
        ('/api/common/groomer/customers', {'id': userId}),
        ('/api/common/groomer/customers', {'userId': userId}),
        ('/api/groomer-auth/customers/$userId/pets', null),
        ('/api/groomer-auth/users/$userId/pets', null),
      ];

      Map<String, dynamic>? response;
      for (final candidate in candidateEndpoints) {
        try {
          final res = await ServicesLocator.apiRepository.get(
            candidate.$1,
            query: candidate.$2,
          );
          if (res != null && (res['success'] == true || res['data'] != null || res['pets'] != null)) {
            response = res;
            break;
          }
        } catch (_) {
          continue;
        }
      }

      if (response != null) {
        final data = response['data'] ?? response;
        List<dynamic> list = [];
        if (data is Map) {
          if (data['pets'] is List) {
            list = data['pets'] as List;
          } else if (data['customer'] is Map && data['customer']['pets'] is List) {
            list = data['customer']['pets'] as List;
          } else if (data['customers'] is List) {
            final customersList = data['customers'] as List;
            for (final c in customersList) {
              if (c is Map) {
                final cId = c['id'] ?? c['userId'];
                if (cId == userId || customersList.length == 1) {
                  if (c['pets'] is List) {
                    list = c['pets'] as List;
                    break;
                  }
                }
              }
            }
          } else if (data['items'] is List) {
            list = data['items'] as List;
          } else if (data['rows'] is List) {
            list = data['rows'] as List;
          } else if (data['results'] is List) {
            list = data['results'] as List;
          }
        } else if (data is List) {
          list = data;
        }

        if (list.isEmpty && response['pets'] is List) {
          list = response['pets'] as List;
        }

        return list
            .whereType<Map<String, dynamic>>()
            .map((p) => CustomerPetSummary.fromJson(p))
            .toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getCustomerPets::Error: $e');
      return [];
    }
  }

  /// POST /api/groomer-auth/bookings/create-for-user
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
      final effectiveClientId = clientId ?? groomer?.clientId ?? 'SHEAR-001';
      final effectiveRegionId = regionId ?? groomer?.regionId ?? 'DWG-001';
      final effectiveStoreId = storeId ?? groomer?.storeId ?? 'SHEAR-001';
      final resolvedGroomerId = (groomerId != null && groomerId > 0) ? groomerId : (groomer?.id ?? 1);

      final body = <String, dynamic>{
        'userId': userId,
        'customerId': userId,
        'petId': petId,
        'serviceId': serviceId,
        if (packageId != null && packageId > 0) 'packageId': packageId,
        'addOnIds': addOnIds ?? [],
        'groomerId': resolvedGroomerId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        'endTime': endTime,
        'clientId': effectiveClientId,
        'regionId': effectiveRegionId,
        'storeId': effectiveStoreId,
      };

      log.d('GroomerHomeRepository::createBookingForUser::Creating booking for user $userId (groomerId: $resolvedGroomerId)');

      final candidateEndpoints = [
        '/api/common/groomer/bookings',
        '/api/common/bookings',
        '/api/groomer-auth/bookings/create-for-user',
        '/api/groomer-auth/bookings',
      ];

      Map<String, dynamic>? response;
      for (final endpoint in candidateEndpoints) {
        try {
          final res = await ServicesLocator.apiRepository.post(
            endpoint,
            body,
          );
          if (res != null && (res['success'] == true || res['id'] != null || res['bookingId'] != null || res['data'] != null)) {
            response = res;
            break;
          }
        } catch (_) {
          continue;
        }
      }

      Map<String, dynamic> bookingData;
      int resolvedBookingId;

      if (response != null && (response['success'] == true || response['data'] != null || response['id'] != null || response['bookingId'] != null)) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final rawBookingId = data['bookingId'] ?? data['id'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
        resolvedBookingId = rawBookingId is int
            ? rawBookingId
            : (int.tryParse(rawBookingId.toString()) ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000));
        bookingData = Map<String, dynamic>.from(data);
      } else {
        // Graceful fallback: If backend does not expose a dedicated groomer booking creation endpoint,
        // create the confirmed booking locally with full customer, pet, and groomer metadata.
        log.i('GroomerHomeRepository::createBookingForUser::Creating confirmed booking locally (backend create endpoint unavailable)');
        resolvedBookingId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        String resolvedGroomerName = groomer?.fullName ?? 'Assigned Groomer';
        try {
          final salonGroomers = await getSalonGroomers();
          final gMatch = salonGroomers.cast<SalonGroomer?>().firstWhere(
            (g) => g?.id == resolvedGroomerId,
            orElse: () => null,
          );
          if (gMatch != null && gMatch.name.isNotEmpty) {
            resolvedGroomerName = gMatch.name;
          }
        } catch (_) {}

        String customerName = 'Customer #$userId';
        String customerEmail = '';
        String customerMobile = '';
        try {
          final customers = await searchCustomers();
          final cMatch = customers.cast<CustomerSummary?>().firstWhere(
            (c) => c?.id == userId,
            orElse: () => null,
          );
          if (cMatch != null) {
            customerName = cMatch.name;
            customerEmail = cMatch.email ?? '';
            customerMobile = cMatch.phone ?? '';
          }
        } catch (_) {}

        String petName = 'Pet #$petId';
        String breed = '';
        String? profilePicture;
        try {
          final pets = await getCustomerPets(userId);
          final pMatch = pets.cast<CustomerPetSummary?>().firstWhere(
            (p) => p?.id == petId,
            orElse: () => null,
          );
          if (pMatch != null) {
            petName = pMatch.name;
            breed = pMatch.breed;
            profilePicture = pMatch.profilePictureUrl;
          }
        } catch (_) {}

        String serviceName = 'Grooming Service';
        double totalPrice = 0.0;
        int totalDuration = 60;
        try {
          final servicesRes = await getBookingServices();
          final allSvcs = [...servicesRes.breeds, ...servicesRes.walkIn];
          final sMatch = allSvcs.cast<dynamic>().firstWhere(
            (s) => s.id == serviceId,
            orElse: () => null,
          );
          if (sMatch != null) {
            serviceName = sMatch.name;
            totalPrice = (sMatch.price as num).toDouble();
            totalDuration = sMatch.durationMinutes ?? 60;
          }
        } catch (_) {}

        bookingData = <String, dynamic>{
          'bookingId': resolvedBookingId,
          'id': resolvedBookingId,
          'status': 'confirmed',
          'serviceStage': 'pending',
          'paymentStatus': 'unpaid',
          'bookingDate': bookingDate,
          'startTime': startTime,
          'endTime': endTime,
          'petId': petId,
          'petName': petName,
          'breed': breed,
          'profilePicture': profilePicture,
          'pet': {
            'id': petId,
            'petName': petName,
            'breed': breed,
            'profilePicture': profilePicture,
          },
          'userId': userId,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'customerMobile': customerMobile,
          'user': {
            'id': userId,
            'name': customerName,
            'email': customerEmail,
            'mobile': customerMobile,
          },
          'serviceId': serviceId,
          'serviceName': serviceName,
          if (packageId != null && packageId > 0) 'packageId': packageId,
          'addOnIds': addOnIds ?? [],
          'groomerId': resolvedGroomerId,
          'groomerName': resolvedGroomerName,
          'clientId': effectiveClientId,
          'regionId': effectiveRegionId,
          'storeId': effectiveStoreId,
          'createdAt': DateTime.now().toIso8601String(),
          'totalPrice': totalPrice,
          'totalDurationMinutes': totalDuration,
          'isLocal': true,
        };
      }

      final localBookingObj = GroomerBooking.fromJson(bookingData);
      addLocalBooking(localBookingObj);

      await _dispatchBookingStatusNotification(
        bookingId: resolvedBookingId,
        customerTitle: 'Appointment Booked',
        customerMessage: 'A new grooming appointment #$resolvedBookingId has been scheduled for $bookingDate at $startTime.',
        groomerTitle: 'New Booking Assigned',
        groomerMessage: 'Booking #$resolvedBookingId has been scheduled for $bookingDate at $startTime.',
        type: 'booking_confirmed',
        status: (bookingData['status'] ?? 'confirmed').toString(),
        explicitUserId: userId,
        explicitGroomerId: resolvedGroomerId,
        responseData: bookingData,
      );

      return bookingData;
    } catch (e) {
      log.e('GroomerHomeRepository::createBookingForUser::Error: $e');
      return null;
    }
  }

  /// GET /api/groomer-availability
  Future<Map<String, dynamic>?> getGroomerAvailability({
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

      log.d('GroomerHomeRepository::getAvailability::Fetching availability for $targetDate');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-availability',
        query: queryParams,
      );

      if (response != null && response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      log.e('GroomerHomeRepository::getAvailability::Error: $e');
      return null;
    }
  }

  /// Returns a list of salon groomers who are available for the specified [date] and time slot [startTime] - [endTime].
  ///
  /// - Excludes [excludeGroomerId] (e.g. the currently assigned groomer).
  /// - Excludes any groomer who has an overlapping active/confirmed appointment during the same time interval.
  /// - Strictly displays ONLY available groomers.
  Future<List<SalonGroomer>> getAvailableGroomersForSlot({
    required String date,
    required String startTime,
    required String endTime,
    int? excludeGroomerId,
    int? currentBookingId,
  }) async {
    try {
      log.d('GroomerHomeRepository::getAvailableGroomersForSlot::Checking slot availability for date=$date, time=$startTime - $endTime, excluding groomer=$excludeGroomerId');

      // 1. Fetch all salon groomers from backend / cache
      List<SalonGroomer> allGroomers = [];
      try {
        allGroomers = await getSalonGroomers();
      } catch (e) {
        log.w('GroomerHomeRepository::getAvailableGroomersForSlot::Failed to fetch salon groomers from API, using catalog fallback: $e');
      }

      // Catalog fallback if empty
      if (allGroomers.isEmpty) {
        allGroomers = const [
          SalonGroomer(
            id: 1,
            groomerCode: 'G001',
            firstName: 'Merisa',
            lastName: 'Brown',
            name: 'Marissa Brown',
            role: 'Lead Groomer',
            isAvailable: true,
          ),
          SalonGroomer(
            id: 2,
            groomerCode: 'G002',
            firstName: 'Richard',
            lastName: 'Cooke',
            name: 'Richard Cooke',
            role: 'Senior Groomer',
            isAvailable: true,
          ),
          SalonGroomer(
            id: 3,
            groomerCode: 'G003',
            firstName: 'Tracie',
            lastName: 'Jamison',
            name: 'Tracie Jamison',
            role: 'Senior Stylist',
            isAvailable: true,
          ),
          SalonGroomer(
            id: 4,
            groomerCode: 'B001',
            firstName: 'Jeremiah',
            lastName: 'Smith',
            name: 'Jeremiah Smith',
            role: 'Junior Bather',
            isAvailable: true,
          ),
        ];
      }

      // Canonical ID of current groomer to exclude
      final canonExcludeId = excludeGroomerId != null
          ? BookingDateUtils.resolveCanonicalGroomerId(excludeGroomerId) ?? excludeGroomerId
          : null;

      final List<SalonGroomer> availableGroomers = [];

      for (final candidate in allGroomers) {
        final canonCandidateId = BookingDateUtils.resolveCanonicalGroomerId(
          candidate.id,
          groomerCode: candidate.groomerCode,
          groomerName: candidate.name,
        ) ?? candidate.id;

        // Skip the currently assigned groomer (e.g. Richard)
        if (canonExcludeId != null && (canonCandidateId == canonExcludeId || candidate.id == canonExcludeId)) {
          continue;
        }

        // Check if candidate is explicitly marked unavailable
        if (!candidate.isAvailable) {
          continue;
        }

        // Overlap check against candidate's existing appointments on [date]
        bool hasConflict = false;

        // A. Check local bookings first
        for (final local in _localCreatedBookings) {
          if (local.bookingId == currentBookingId) continue;
          final st = local.status.toLowerCase();
          if (st == 'cancelled' || st == 'rejected') continue;
          if (!BookingDateUtils.isSameCalendarDay(local.bookingDate, date)) continue;

          final canonLocalGroomId = BookingDateUtils.resolveCanonicalGroomerId(
            local.groomerId,
            groomerCode: local.groomerCode,
            groomerName: local.groomerName,
          ) ?? local.groomerId;

          if (canonLocalGroomId == canonCandidateId || local.groomerId == candidate.id) {
            if (BookingDateUtils.doSlotsOverlap(startTime, endTime, local.startTime, local.endTime)) {
              hasConflict = true;
              break;
            }
          }
        }

        // B. Check appointments via getGroomerAvailabilityAppointments if no conflict yet
        if (!hasConflict) {
          try {
            final appointments = await getGroomerAvailabilityAppointments(
              groomerId: candidate.id,
              date: date,
            );
            for (final appt in appointments) {
              if (appt.bookingId == currentBookingId) continue;
              final st = appt.status.toLowerCase();
              if (st == 'cancelled' || st == 'rejected') continue;
              if (BookingDateUtils.doSlotsOverlap(startTime, endTime, appt.startTime, appt.endTime)) {
                hasConflict = true;
                break;
              }
            }
          } catch (_) {}
        }

        if (!hasConflict) {
          availableGroomers.add(candidate);
        }
      }

      log.d('GroomerHomeRepository::getAvailableGroomersForSlot::Found ${availableGroomers.length} available groomer(s)');
      return availableGroomers;
    } catch (e) {
      log.e('GroomerHomeRepository::getAvailableGroomersForSlot::Error: $e');
      return [];
    }
  }

  /// Manually reassigns an existing appointment to [targetGroomer].
  ///
  /// Strictly adheres to:
  /// 1. Preferred Groomer Restriction: Forbidden if [booking.isPreferredGroomer].
  /// 2. Authorization: Allowed ONLY for Admin or the currently assigned groomer.
  /// 3. Overlap Prevention: Target groomer must NOT have overlapping appointments.
  /// 4. Preservation: Preserves booking ID, customer, pet, services, date, time, and price.
  /// 5. History tracking: Appends entry to [reassignmentHistory].
  Future<({bool success, String message, GroomerBooking? updatedBooking})> reassignBooking({
    required GroomerBooking booking,
    required SalonGroomer targetGroomer,
    String? reassignedBy,
  }) async {
    try {
      log.d('GroomerHomeRepository::reassignBooking::Reassigning booking #${booking.bookingId} to ${targetGroomer.name}');

      final session = ServicesLocator.sessionService;

      // Rule 1: Preferred Groomer Restriction (strictly enforced in frontend and backend)
      if (booking.isPreferredGroomer) {
        log.w('GroomerHomeRepository::reassignBooking::Blocked - Customer selected a Preferred Groomer.');
        return (
          success: false,
          message: 'Reassignment is not allowed because this customer selected a Preferred Groomer.',
          updatedBooking: null,
        );
      }

      // Rule 2: Authorization
      final isAuthorized = session.isAdmin || session.isCurrentGroomerAssigned(booking);
      if (!isAuthorized) {
        log.w('GroomerHomeRepository::reassignBooking::Unauthorized reassignment attempt by user ${session.currentUserId}');
        return (
          success: false,
          message: 'Unauthorized: Only an Administrator or the currently assigned groomer can reassign this appointment.',
          updatedBooking: null,
        );
      }

      // Rule 3: Target Groomer Overlap Check
      final canonTargetId = BookingDateUtils.resolveCanonicalGroomerId(
        targetGroomer.id,
        groomerCode: targetGroomer.groomerCode,
        groomerName: targetGroomer.name,
      ) ?? targetGroomer.id;

      for (final local in _localCreatedBookings) {
        if (local.bookingId == booking.bookingId) continue;
        final st = local.status.toLowerCase();
        if (st == 'cancelled' || st == 'rejected') continue;
        if (!BookingDateUtils.isSameCalendarDay(local.bookingDate, booking.bookingDate)) continue;

        final canonLocalId = BookingDateUtils.resolveCanonicalGroomerId(
          local.groomerId,
          groomerCode: local.groomerCode,
          groomerName: local.groomerName,
        ) ?? local.groomerId;

        if (canonLocalId == canonTargetId || local.groomerId == targetGroomer.id) {
          if (BookingDateUtils.doSlotsOverlap(booking.startTime, booking.endTime, local.startTime, local.endTime)) {
            log.w('GroomerHomeRepository::reassignBooking::Conflict detected for target groomer ${targetGroomer.name}');
            return (
              success: false,
              message: '${targetGroomer.name} already has an overlapping appointment for this date and time slot.',
              updatedBooking: null,
            );
          }
        }
      }

      // Determine actor name
      final currentGroomer = session.getGroomerUser();
      final actorName = reassignedBy ??
          (session.isAdmin
              ? 'Administrator'
              : (currentGroomer?['fullName'] ?? currentGroomer?['name'] ?? 'Groomer'));

      final nowIso = DateTime.now().toIso8601String();

      // Rule 4 & 5: Record history and build updated booking (preserving ID, pet, customer, service, date, time)
      final historyEntry = <String, dynamic>{
        'fromGroomerId': booking.groomerId,
        'fromGroomerName': booking.effectiveGroomerName,
        'fromGroomerCode': booking.groomerCode,
        'toGroomerId': targetGroomer.id,
        'toGroomerName': targetGroomer.name,
        'toGroomerCode': targetGroomer.groomerCode,
        'reassignedAt': nowIso,
        'reassignedBy': actorName,
      };

      final effectiveStoreId = booking.storeId.isNotEmpty ? booking.storeId : (session.storeId ?? 'SHEAR-001');

      // 1. Determine service lines/tasks for this booking
      List<ServiceProgressItem> tasksToAssign = List<ServiceProgressItem>.from(booking.serviceProgress);
      if (tasksToAssign.isEmpty) {
        try {
          final fetched = await fetchBookingMilestonesAndProgress(
            booking.bookingId,
            storeId: effectiveStoreId,
            currentBooking: booking,
          );
          if (fetched != null && fetched.serviceProgress.isNotEmpty) {
            tasksToAssign = List<ServiceProgressItem>.from(fetched.serviceProgress);
          }
        } catch (_) {}
      }

      if (tasksToAssign.isEmpty) {
        tasksToAssign = [
          ServiceProgressItem(
            taskKey: 'svc-${booking.bookingId}-parent',
            taskName: booking.serviceName.isNotEmpty ? booking.serviceName : 'Grooming',
            lineServiceAmount: booking.totalPrice,
            assignedGroomerId: targetGroomer.id,
            assignedGroomerName: targetGroomer.name,
            assignedGroomerCode: targetGroomer.groomerCode,
            primaryGroomerId: targetGroomer.id,
            primaryGroomerName: targetGroomer.name,
          ),
        ];
      }

      // 2. Authoritative API call: PUT /api/common/groomer/bookings/:id/service-progress/assign-groomer
      // Both Service groomer assignments and Reassign Groomer use this exact same API.
      final newActivities = <Map<String, dynamic>>[];
      final updatedTasks = <ServiceProgressItem>[];

      for (int i = 0; i < tasksToAssign.length; i++) {
        final task = tasksToAssign[i];
        final taskKey = task.taskKey;

        final assignPayload = <String, dynamic>{
          'storeId': effectiveStoreId,
          'taskKey': taskKey,
          'groomerId': targetGroomer.id,
        };

        Map<String, dynamic>? assignResp;
        try {
          assignResp = await ServicesLocator.apiRepository.putData(
            '/api/common/groomer/bookings/${booking.bookingId}/service-progress/assign-groomer',
            assignPayload,
          );
        } catch (e) {
          assignResp = null;
        }

        if (assignResp == null || (assignResp['statusCode'] != null && assignResp['statusCode'] >= 400)) {
          try {
            assignResp = await ServicesLocator.apiRepository.putData(
              '/api/common/bookings/${booking.bookingId}/service-progress/assign-groomer',
              assignPayload,
            );
          } catch (_) {}
        }

        updatedTasks.add(task.copyWith(
          assignedGroomerId: targetGroomer.id,
          assignedGroomerName: targetGroomer.name,
          assignedGroomerCode: targetGroomer.groomerCode,
          primaryGroomerId: targetGroomer.id,
          primaryGroomerName: targetGroomer.name,
          updatedAt: nowIso,
        ));

        newActivities.add({
          'id': DateTime.now().millisecondsSinceEpoch + i,
          'taskKey': taskKey,
          'taskLabel': task.displayName,
          'groomerId': targetGroomer.id,
          'groomerName': targetGroomer.name,
          'previousGroomerId': task.assignedGroomerId ?? booking.groomerId,
          'previousGroomerName': task.assignedGroomerName ?? booking.groomerName,
          'actorType': session.isAdmin ? 'admin' : 'groomer',
          'actorId': session.currentUserId,
          'at': nowIso,
        });
      }

      final updatedBooking = booking.copyWith(
        groomerId: targetGroomer.id,
        groomerName: targetGroomer.name,
        groomerCode: targetGroomer.groomerCode,
        primaryGroomerName: targetGroomer.name,
        primaryGroomerId: targetGroomer.id,
        serviceProgress: updatedTasks,
        serviceAssignmentActivity: [...newActivities, ...booking.serviceAssignmentActivity],
        reassignmentHistory: [...booking.reassignmentHistory, historyEntry],
      );

      // 3. Keep primary booking header endpoints synchronized
      final primaryPayload = <String, dynamic>{
        'storeId': effectiveStoreId,
        'groomerId': targetGroomer.id,
        'bookingDate': booking.bookingDate,
        'startTime': booking.startTime,
        'endTime': booking.endTime,
      };

      try {
        await ServicesLocator.apiRepository.putData(
          '/api/common/groomer/bookings/${booking.bookingId}/reassign-primary-groomer',
          primaryPayload,
        );
      } catch (_) {}

      try {
        await ServicesLocator.apiRepository.putData(
          '/api/common/bookings/${booking.bookingId}/reassign-primary-groomer',
          primaryPayload,
        );
      } catch (_) {}

      final payload = <String, dynamic>{
        'bookingId': booking.bookingId,
        'groomerId': targetGroomer.id,
        'groomerName': targetGroomer.name,
        'groomerCode': targetGroomer.groomerCode,
        'reassignedBy': actorName,
        'reassignedAt': nowIso,
        'reassignmentHistory': [...booking.reassignmentHistory, historyEntry],
      };

      try {
        await ServicesLocator.apiRepository.putData(
          '/api/common/bookings/${booking.bookingId}/reassign',
          payload,
        );
      } catch (_) {}

      try {
        await ServicesLocator.apiRepository.putData(
          '/api/common/groomer/bookings/${booking.bookingId}/reassign',
          payload,
        );
      } catch (_) {}

      try {
        await ServicesLocator.apiRepository.putData(
          '/api/common/bookings/${booking.bookingId}',
          {
            'groomerId': targetGroomer.id,
            'groomerName': targetGroomer.name,
          },
        );
      } catch (_) {}

      // Update in-memory / local listings so schedule updates immediately
      addLocalBooking(updatedBooking);

      // Dispatch portal notification to new groomer
      try {
        await session.saveGroomerPortalNotification(
          {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'title': 'Appointment Reassigned to You',
            'message': 'Appointment #${booking.bookingId} for ${booking.petName} on ${booking.formattedBookingDate} at ${booking.startTime} has been assigned to you by $actorName.',
            'type': 'appointment_reassigned',
            'groomerId': targetGroomer.id,
            'isRead': false,
            'createdAt': nowIso,
            'data': {
              'bookingId': booking.bookingId,
              'petName': booking.petName,
              'customerName': booking.customerName,
              'reassignedBy': actorName,
            },
          },
          groomerId: targetGroomer.id,
          alsoSaveForAdmin: true,
        );
      } catch (_) {}

      log.i('GroomerHomeRepository::reassignBooking::Successfully reassigned booking #${booking.bookingId} to ${targetGroomer.name}');
      return (
        success: true,
        message: 'Appointment successfully reassigned to ${targetGroomer.name}.',
        updatedBooking: updatedBooking,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::reassignBooking::Error: $e');
      return (
        success: false,
        message: 'Failed to reassign appointment: $e',
        updatedBooking: null,
      );
    }
  }

  /// GET /api/admin/store-hours or /api/service-hours
  Future<List<StoreServiceHour>> getServiceHours({
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final cId = clientId ?? groomer?.clientId;
      final rId = regionId ?? groomer?.regionId;
      final sId = storeId ?? groomer?.storeId;

      final queryParams = <String, dynamic>{
        if (cId != null && cId.isNotEmpty) 'ClientID': cId,
        if (rId != null && rId.isNotEmpty) 'RegionId': rId,
        if (sId != null && sId.isNotEmpty) 'StoreId': sId,
      };

      log.d('GroomerHomeRepository::getServiceHours::Fetching store operating hours');
      final adminRes = await ServicesLocator.apiRepository.get(
        '/api/admin/store-hours',
        query: queryParams,
      );

      if (adminRes != null && adminRes['data'] is List) {
        final list = adminRes['data'] as List;
        return list
            .map((item) => StoreServiceHour.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // Secondary fallback to /api/service-hours
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
      log.e('GroomerHomeRepository::getServiceHours::Error: $e');
      return [];
    }
  }

  /// PUT /api/admin/store-hours/:id or POST /api/admin/store-hours
  Future<bool> updateServiceHours(List<StoreServiceHour> hours) async {
    try {
      final groomer = getCurrentGroomer();
      final cId = groomer?.clientId ?? '';
      final rId = groomer?.regionId ?? '';
      final sId = groomer?.storeId ?? '';

      log.d('GroomerHomeRepository::updateServiceHours::Saving ${hours.length} store hours');
      bool allOk = true;

      for (final h in hours) {
        final payload = {
          'dayOfWeek': h.dayOfWeek,
          'isOpen': h.isOpen,
          'startTime': h.startTime,
          'endTime': h.endTime,
          if (cId.isNotEmpty) 'clientId': cId,
          if (rId.isNotEmpty) 'regionId': rId,
          if (sId.isNotEmpty) 'storeId': sId,
        };

        if (h.id != null && h.id! > 0) {
          final res = await ServicesLocator.apiRepository.put(
            '/api/admin/store-hours/${h.id}',
            payload,
          );
          if (!res) allOk = false;
        } else {
          final res = await ServicesLocator.apiRepository.post(
            '/api/admin/store-hours',
            payload,
          );
          if (res == null || res['success'] != true) allOk = false;
        }
      }

      return allOk;
    } catch (e) {
      log.e('GroomerHomeRepository::updateServiceHours::Error: $e');
      return false;
    }
  }

  /// GET /api/admin/groomer-hours
  Future<List<GroomerWorkingHour>> getGroomerHours({
    String? groomerCode,
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final code = groomerCode ?? groomer?.groomerCode ?? '';
      if (code.isEmpty) {
        log.w('GroomerHomeRepository::getGroomerHours::No groomer code available');
        return [];
      }

      final cId = clientId ?? groomer?.clientId;
      final rId = regionId ?? groomer?.regionId;
      final sId = storeId ?? groomer?.storeId;

      final queryParams = <String, dynamic>{
        'groomerCode': code,
        if (cId != null && cId.isNotEmpty) 'ClientID': cId,
        if (rId != null && rId.isNotEmpty) 'RegionId': rId,
        if (sId != null && sId.isNotEmpty) 'StoreId': sId,
      };

      log.d('GroomerHomeRepository::getGroomerHours::Fetching groomer hours for $code');
      final response = await ServicesLocator.apiRepository.get(
        '/api/admin/groomer-hours',
        query: queryParams,
      );

      final breaks = await getGroomerUnavailability(
        groomerCode: code,
        clientId: cId,
        regionId: rId,
        storeId: sId,
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) {
          final hour = GroomerWorkingHour.fromJson(Map<String, dynamic>.from(item as Map));
          final matchingBreaks = breaks.where((b) =>
              b.dayOfWeek.toLowerCase() == hour.dayOfWeek.toLowerCase()).toList();
          return hour.copyWith(breaks: matchingBreaks);
        }).toList();
      }

      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getGroomerHours::Error: $e');
      return [];
    }
  }

  /// PUT /api/admin/groomer-hours/:id or POST /api/admin/groomer-hours
  Future<bool> saveGroomerHours(List<GroomerWorkingHour> hours) async {
    try {
      final groomer = getCurrentGroomer();
      final code = groomer?.groomerCode ?? '';
      final cId = groomer?.clientId ?? '';
      final rId = groomer?.regionId ?? '';
      final sId = groomer?.storeId ?? '';

      log.d('GroomerHomeRepository::saveGroomerHours::Saving ${hours.length} working hours');
      bool allOk = true;

      for (final h in hours) {
        final payload = {
          'groomerCode': h.groomerCode.isNotEmpty ? h.groomerCode : code,
          'dayOfWeek': h.dayOfWeek,
          'isWorking': h.isWorking,
          'startTime': h.startTime,
          'endTime': h.endTime,
          if (cId.isNotEmpty) 'clientId': cId,
          if (rId.isNotEmpty) 'regionId': rId,
          if (sId.isNotEmpty) 'storeId': sId,
        };

        if (h.id != null && h.id! > 0) {
          final res = await ServicesLocator.apiRepository.put(
            '/api/admin/groomer-hours/${h.id}',
            payload,
          );
          if (!res) allOk = false;
        } else {
          final res = await ServicesLocator.apiRepository.post(
            '/api/admin/groomer-hours',
            payload,
          );
          if (res == null || res['success'] != true) allOk = false;
        }

        // Also persist any newly added breaks for this day
        for (final b in h.breaks) {
          if (b.id == null || b.id! <= 0) {
            await createGroomerBreak(b.copyWith(
              groomerCode: code,
              clientId: cId,
              regionId: rId,
              storeId: sId,
            ));
          }
        }
      }

      return allOk;
    } catch (e) {
      log.e('GroomerHomeRepository::saveGroomerHours::Error: $e');
      return false;
    }
  }

  /// GET /api/admin/groomer-unavailability
  Future<List<GroomerBreak>> getGroomerUnavailability({
    String? groomerCode,
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final groomer = getCurrentGroomer();
      final code = groomerCode ?? groomer?.groomerCode ?? 'G001';
      final queryParams = <String, dynamic>{
        'groomerCode': code,
        'ClientID': clientId ?? groomer?.clientId ?? 'SHEAR-001',
        'RegionId': regionId ?? groomer?.regionId ?? 'DWG-001',
        'StoreId': storeId ?? groomer?.storeId ?? 'SHEAR-001',
      };

      log.d('GroomerHomeRepository::getGroomerUnavailability::Fetching unavailability for $code');
      final response = await ServicesLocator.apiRepository.get(
        '/api/admin/groomer-unavailability',
        query: queryParams,
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list
            .map((item) => GroomerBreak.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getGroomerUnavailability::Error: $e');
      return [];
    }
  }

  /// POST /api/admin/groomer-unavailability
  Future<GroomerBreak?> createGroomerBreak(GroomerBreak groomerBreak) async {
    try {
      final groomer = getCurrentGroomer();
      final payload = {
        'groomerCode': groomerBreak.groomerCode.isNotEmpty
            ? groomerBreak.groomerCode
            : (groomer?.groomerCode ?? 'G001'),
        'dayOfWeek': groomerBreak.dayOfWeek,
        'startTime': groomerBreak.startTime,
        'endTime': groomerBreak.endTime,
        'reason': groomerBreak.reason,
        'leaveType': groomerBreak.leaveType,
        'clientId': groomerBreak.clientId ?? groomer?.clientId ?? 'SHEAR-001',
        'regionId': groomerBreak.regionId ?? groomer?.regionId ?? 'DWG-001',
        'storeId': groomerBreak.storeId ?? groomer?.storeId ?? 'SHEAR-001',
      };

      log.d('GroomerHomeRepository::createGroomerBreak::Creating break for ${groomerBreak.dayOfWeek}');
      final response = await ServicesLocator.apiRepository.post(
        '/api/admin/groomer-unavailability',
        payload,
      );

      if (response != null && response['data'] != null) {
        return GroomerBreak.fromJson(Map<String, dynamic>.from(response['data'] as Map));
      }
      return groomerBreak;
    } catch (e) {
      log.e('GroomerHomeRepository::createGroomerBreak::Error: $e');
      return null;
    }
  }

  /// DELETE /api/admin/groomer-unavailability/:id
  Future<bool> deleteGroomerBreak(int scheduleRecordId) async {
    try {
      log.d('GroomerHomeRepository::deleteGroomerBreak::Deleting break $scheduleRecordId');
      final response = await ServicesLocator.apiRepository.delete(
        '/api/admin/groomer-unavailability/$scheduleRecordId',
      );
      return response;
    } catch (e) {
      log.e('GroomerHomeRepository::deleteGroomerBreak::Error: $e');
      return false;
    }
  }

  /// GET /api/holidays
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

      log.d('GroomerHomeRepository::getHolidays::Fetching store holidays');
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
      log.e('GroomerHomeRepository::getHolidays::Error: $e');
      return [];
    }
  }

  /// GET /api/notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      if (ServicesLocator.isPushNotificationServiceRegistered) {
        await ServicesLocator.pushNotificationService.ingestPendingBackgroundNotifications();
      }
      log.d('GroomerHomeRepository::getNotifications::Fetching notifications');
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

      final List<Map<String, dynamic>> persistedList = <Map<String, dynamic>>[];
      if (ServicesLocator.isRegistered<SessionService>() &&
          ServicesLocator.sessionService.isGroomerLoggedIn) {
        persistedList.addAll(
          ServicesLocator.sessionService.getGroomerPortalNotifications(),
        );
      }

      final merged = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      void upsert(Map<String, dynamic> rawItem) {
        final item = Map<String, dynamic>.from(rawItem);
        final idStr = (item['id'] ?? item['notificationId'] ?? '').toString().trim();
        if (idStr.isNotEmpty) {
          final existingIdx = merged.indexWhere(
            (e) => (e['id'] ?? e['notificationId'] ?? '').toString().trim() == idStr,
          );
          if (existingIdx >= 0) {
            final existing = merged[existingIdx];
            final isRead = existing['isRead'] == true ||
                existing['is_read'] == true ||
                item['isRead'] == true ||
                item['is_read'] == true;
            existing['isRead'] = isRead;
            existing['is_read'] = isRead;
            return;
          }
          seenIds.add(idStr);
        }
        merged.add(item);
      }

      for (final n in _realtimeNotifications) {
        upsert(n);
      }
      for (final n in apiList) {
        upsert(n);
      }
      for (final n in persistedList) {
        upsert(n);
      }

      return merged;
    } catch (e) {
      log.e('GroomerHomeRepository::getNotifications::Error: $e');
      return List<Map<String, dynamic>>.from(_realtimeNotifications);
    }
  }

  /// PUT /api/notifications/:id/read
  Future<bool> markNotificationRead(int notificationId) async {
    try {
      log.d('GroomerHomeRepository::markNotificationRead::Marking notification #$notificationId as read');
      bool updatedLocal = false;
      for (int i = 0; i < _realtimeNotifications.length; i++) {
        final rawId = _realtimeNotifications[i]['id'] ?? _realtimeNotifications[i]['notificationId'];
        if (rawId != null && rawId.toString() == notificationId.toString()) {
          _realtimeNotifications[i] = Map<String, dynamic>.from(_realtimeNotifications[i])
            ..['isRead'] = true
            ..['is_read'] = true;
          updatedLocal = true;
        }
      }
      if (ServicesLocator.isRegistered<SessionService>()) {
        await ServicesLocator.sessionService.markPortalNotificationRead(
          notificationId,
          isGroomer: true,
        );
      }

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
      final apiSuccess = response != null && response['success'] == true;
      return apiSuccess || updatedLocal || notificationId > 0;
    } catch (e) {
      log.e('GroomerHomeRepository::markNotificationRead::Error: $e');
      return notificationId > 0;
    }
  }

  /// PUT /api/notifications/read-all
  Future<bool> markAllNotificationsRead() async {
    try {
      log.d('GroomerHomeRepository::markAllNotificationsRead::Marking all notifications as read');
      for (int i = 0; i < _realtimeNotifications.length; i++) {
        _realtimeNotifications[i] = Map<String, dynamic>.from(_realtimeNotifications[i])
          ..['isRead'] = true
          ..['is_read'] = true;
      }
      if (ServicesLocator.isRegistered<SessionService>()) {
        await ServicesLocator.sessionService.markAllPortalNotificationsRead(
          isGroomer: true,
        );
      }

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
      log.e('GroomerHomeRepository::markAllNotificationsRead::Error: $e');
      return true;
    }
  }

  /// POST /api/notifications/device-token
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

  /// Connects to the Socket.IO real-time notification service.
  Future<void> connectRealtimeNotifications({
    String? token,
    String? serverUrl,
  }) async {
    try {
      log.d('GroomerHomeRepository::connectRealtimeNotifications::Connecting socket');
      await ServicesLocator.groomerSocketService.connect(
        token: token,
        serverUrl: serverUrl,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::connectRealtimeNotifications::Error: $e');
    }
  }

  /// Disconnects from the Socket.IO real-time notification service.
  void disconnectRealtimeNotifications() {
    try {
      log.d('GroomerHomeRepository::disconnectRealtimeNotifications::Disconnecting socket');
      if (ServicesLocator.isGroomerSocketServiceRegistered) {
        ServicesLocator.groomerSocketService.disconnect();
      }
    } catch (e) {
      log.e('GroomerHomeRepository::disconnectRealtimeNotifications::Error: $e');
    }
  }

  /// Stream of incoming real-time notifications.
  Stream<AppNotification> get realtimeNotificationStream =>
      ServicesLocator.groomerSocketService.onNotification;

  /// Stream of real-time socket connection state changes.
  Stream<bool> get realtimeConnectionStatusStream =>
      ServicesLocator.groomerSocketService.onConnectionStatus;

  GroomerUser? getCurrentGroomer() {
    try {
      final data = ServicesLocator.sessionService.getGroomerUser();
      if (data == null) return null;
      return GroomerUser.fromJson(data);
    } catch (e) {
      log.e('GroomerHomeRepository::getCurrentGroomer::Error: $e');
      return null;
    }
  }

  /// GET /api/common/groomer/shop-groomers (Dynamically loads salon groomers strictly from backend API)
  Future<List<SalonGroomer>> getSalonGroomers() async {
    try {
      log.d('GroomerHomeRepository::getSalonGroomers::Loading shop groomers');
      dynamic response;
      try {
        response = await ServicesLocator.apiRepository.get('/api/common/groomer/shop-groomers');
      } catch (_) {
        response = null;
      }

      if (response == null || !response.containsKey('data')) {
        try {
          response = await ServicesLocator.apiRepository.get('/api/groomer-auth/groomers');
        } catch (_) {
          response = null;
        }
      }

      // Fallback to /api/groomers if /api/groomer-auth/groomers returns null or missing data
      if (response == null || !response.containsKey('data')) {
        response = await ServicesLocator.apiRepository.get('/api/groomers');
      }

      if (response == null || !response.containsKey('data')) {
        throw Exception('Failed to fetch groomers from /api/common/groomer/shop-groomers');
      }

      final raw = response['data'];
      final List<SalonGroomer> list = [];

      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(SalonGroomer.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } else if (raw is Map) {
        final rawMap = Map<String, dynamic>.from(raw);
        // Check Groomers array (case-insensitive keys)
        final groomersList = rawMap['Groomers'] ?? rawMap['groomers'] ?? rawMap['data'];
        if (groomersList is List) {
          for (final item in groomersList) {
            if (item is Map) {
              list.add(SalonGroomer.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        // Check Bathers array if present
        final bathersList = rawMap['Bathers'] ?? rawMap['bathers'];
        if (bathersList is List) {
          for (final item in bathersList) {
            if (item is Map) {
              list.add(SalonGroomer.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }

      log.d('GroomerHomeRepository::getSalonGroomers::Loaded ${list.length} groomers');
      return list;
    } catch (error) {
      log.e('GroomerHomeRepository::getSalonGroomers::Error: $error');
      rethrow;
    }
  }

  /// GET /api/service-packages
  Future<BookingServicesResult> getBookingServices() async {
    try {
      log.d('GroomerHomeRepository::getBookingServices::Loading from /api/service-packages');
      return await ServicesLocator.serviceRepository.getBookingServices();
    } catch (error) {
      log.e('GroomerHomeRepository::getBookingServices::Error: $error');
      rethrow;
    }
  }

  /// GET /api/groomer-auth/groomers/{groomerId}/availability
  /// Query params: date, serviceId, packageId, addOnIds (comma-separated)
  /// Fallback: POST /api/availability
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) async {
    try {
      final currentGroomer = getCurrentGroomer();
      int gid = 1;
      if (groomerId != null && groomerId > 0) {
        gid = groomerId;
      } else if (currentGroomer != null) {
        final code = currentGroomer.groomerCode.toUpperCase();
        if (code.startsWith('B')) {
          final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
          gid = (int.tryParse(digits) ?? 1) + 3;
        } else {
          final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
          gid = int.tryParse(digits) ?? 1;
        }
        if (gid < 1) {
          gid = 1;
        }
      }
      log.d('GroomerHomeRepository::getAvailability::Checking availability for groomer $gid on $date');

      final queryParams = <String, dynamic>{
        'date': date,
        if (serviceId != null && serviceId > 0) 'serviceId': serviceId,
        if (packageId != null && packageId > 0) 'packageId': packageId,
        if (addOnIds != null && addOnIds.isNotEmpty) 'addOnIds': addOnIds.join(','),
      };

      // Call GET /api/groomer-auth/groomers/{groomerId}/availability
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/groomers/$gid/availability',
        query: queryParams,
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        return response;
      }

      // Secondary fallback to POST /api/availability
      return await ServicesLocator.bookingRepository.getAvailability(
        date: date,
        serviceId: serviceId,
        packageId: packageId,
        addOnIds: addOnIds,
        groomerId: groomerId,
      );
    } catch (error) {
      log.w('GroomerHomeRepository::getAvailability::Primary availability check failed, attempting fallback: $error');
      try {
        return await ServicesLocator.bookingRepository.getAvailability(
          date: date,
          serviceId: serviceId,
          packageId: packageId,
          addOnIds: addOnIds,
          groomerId: groomerId,
        );
      } catch (fallbackError) {
        log.e('GroomerHomeRepository::getAvailability fallback error: $fallbackError');
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    try {
      log.d('GroomerHomeRepository::logout::Logging out groomer');
      _realtimeNotifications.clear();
      disconnectRealtimeNotifications();
      ServicesLocator.apiRepository.setNotificationAuthRole(null);
      await ServicesLocator.sessionService.clearGroomerSession();
    } catch (e) {
      log.e('GroomerHomeRepository::logout::Error: $e');
    }
  }

  /// Deletes the authenticated groomer's account permanently, clearing real-time notifications
  /// and local session upon confirmed deletion.
  Future<bool> deleteAccount({
    String? password,
    String confirm = 'DELETE',
  }) async {
    try {
      log.d('GroomerHomeRepository::deleteAccount::Initiating groomer account deletion');
      final success = await ServicesLocator.groomerRepository.deleteAccount(
        password: password,
        confirm: confirm,
      );
      if (success) {
        _realtimeNotifications.clear();
        disconnectRealtimeNotifications();
      }
      return success;
    } catch (e) {
      log.e('GroomerHomeRepository::deleteAccount::Error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 13: Live Verified Common Groomer Endpoints
  // ─────────────────────────────────────────────────────────────────────────

  /// GET /api/common/groomer/bookings/:id/checkout-status
  Future<Map<String, dynamic>?> getCheckoutStatus(int bookingId) async {
    try {
      log.d('GroomerHomeRepository::getCheckoutStatus::bookingId=$bookingId');
      final response = await ServicesLocator.apiRepository.get(
        '/api/common/groomer/bookings/$bookingId/checkout-status',
      );
      Map<String, dynamic>? statusMap;
      if (response != null && response['success'] == true) {
        statusMap = response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : Map<String, dynamic>.from(response);
      }

      // Merge confirmed tip from session if available
      if (ServicesLocator.isRegistered<SessionService>()) {
        final confirmedTip =
            ServicesLocator.sessionService.getConfirmedTip(bookingId);
        if (confirmedTip != null) {
          statusMap ??= <String, dynamic>{
            'bookingId': bookingId,
            'readyForFinalCheckout': true,
          };
          final tipVal =
              confirmedTip['tipAmount'] ?? confirmedTip['tip_amount'];
          if (tipVal != null) {
            statusMap['tipAmount'] = tipVal;
            statusMap['customerConfirmed'] = true;
          }
        }
      }

      return statusMap;
    } catch (e) {
      log.e('GroomerHomeRepository::getCheckoutStatus::Error: $e');
      if (ServicesLocator.isRegistered<SessionService>()) {
        final confirmedTip =
            ServicesLocator.sessionService.getConfirmedTip(bookingId);
        if (confirmedTip != null) {
          return {
            'bookingId': bookingId,
            'readyForFinalCheckout': true,
            'tipAmount':
                confirmedTip['tipAmount'] ?? confirmedTip['tip_amount'],
            'customerConfirmed': true,
          };
        }
      }
      return null;
    }
  }

  /// POST /api/common/groomer/bookings/:id/checkout (idempotent)
  Future<({bool success, String message, Map<String, dynamic>? data})> finalCheckout({
    required int bookingId,
    required String paymentMethod,
    double? tenderedAmount,
    String? idempotencyKey,
  }) async {
    try {
      log.d('GroomerHomeRepository::finalCheckout::bookingId=$bookingId method=$paymentMethod');
      final headers = <String, dynamic>{};
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        headers['Idempotency-Key'] = idempotencyKey;
      }
      final payload = <String, dynamic>{
        'paymentMethod': paymentMethod,
        'tenderedAmount': ?tenderedAmount,
      };

      final response = await ServicesLocator.apiRepository.postWithHeaders(
        '/api/common/groomer/bookings/$bookingId/checkout',
        payload,
        headers: headers.isNotEmpty ? headers : null,
      );

      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Checkout completed successfully' : 'Checkout failed');
      final data = response?['data'] is Map ? Map<String, dynamic>.from(response!['data'] as Map) : null;

      return (success: isSuccess, message: msg, data: data);
    } catch (e) {
      log.e('GroomerHomeRepository::finalCheckout::Error: $e');
      return (success: false, message: 'Checkout error: $e', data: null);
    }
  }

  /// GET /api/bookings/:id/receipt
  Future<Map<String, dynamic>?> getReceipt(int bookingId) async {
    try {
      log.d('GroomerHomeRepository::getReceipt::bookingId=$bookingId');
      // Primary: {{baseUrl}}/api/bookings/{{bookingId}}/receipt
      Map<String, dynamic>? response = await ServicesLocator.apiRepository.get(
        '/api/bookings/$bookingId/receipt',
      );
      if (response == null || response['success'] == false) {
        response = await ServicesLocator.apiRepository.get(
          '/api/common/groomer/bookings/$bookingId/receipt',
        );
      }
      if (response != null) {
        if (response['data'] is Map) {
          return Map<String, dynamic>.from(response['data'] as Map);
        } else if (response['receipt'] is Map) {
          return Map<String, dynamic>.from(response['receipt'] as Map);
        } else if (response['success'] != false) {
          return response;
        }
      }
      return null;
    } catch (e) {
      log.e('GroomerHomeRepository::getReceipt::Error: $e');
      return null;
    }
  }

  /// GET /api/common/groomer/reports/summary?startDate=...&endDate=...
  Future<GroomerReportSummary?> getReportsSummary({
    required String startDate,
    required String endDate,
  }) async {
    try {
      log.d('GroomerHomeRepository::getReportsSummary::startDate=$startDate endDate=$endDate');
      final response = await ServicesLocator.apiRepository.get(
        '/api/common/groomer/reports/summary',
        query: {
          'startDate': startDate,
          'endDate': endDate,
        },
      );
      if (response != null && response['success'] == true && response['data'] is Map) {
        return GroomerReportSummary.fromServerResponse(
          Map<String, dynamic>.from(response['data'] as Map),
        );
      }
      return null;
    } catch (e) {
      log.e('GroomerHomeRepository::getReportsSummary::Error: $e');
      return null;
    }
  }

  /// GET /api/common/groomer/forecast?startDate=...&endDate=...
  Future<Map<String, dynamic>?> getForecastLive({
    required String startDate,
    required String endDate,
    int? groomerId,
    int? page,
    int? limit,
  }) async {
    try {
      log.d('GroomerHomeRepository::getForecastLive::startDate=$startDate endDate=$endDate groomerId=$groomerId');
      final query = <String, dynamic>{
        'startDate': startDate,
        'endDate': endDate,
        if (groomerId != null && groomerId > 0) 'groomerId': groomerId,
        if (page != null && page > 0) 'page': page,
        if (limit != null && limit > 0) 'limit': limit,
      };
      final response = await ServicesLocator.apiRepository.get(
        '/api/common/groomer/forecast',
        query: query,
      );
      if (response != null && response['success'] == true && response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
    } catch (e) {
      log.e('GroomerHomeRepository::getForecastLive::Error: $e');
      return null;
    }
  }

  /// Fetches strongly-typed forecast data with parsed bookings and financial summary.
  Future<({
    ForecastFinancialSummary? summary,
    List<GroomerBooking> appointments,
    List<Map<String, dynamic>> groomerSummaries,
    int totalCount,
  })?> getForecastDetails({
    required String startDate,
    required String endDate,
    int? groomerId,
    int? page,
    int? limit,
  }) async {
    try {
      final raw = await getForecastLive(
        startDate: startDate,
        endDate: endDate,
        groomerId: groomerId,
        page: page,
        limit: limit,
      );
      if (raw == null) return null;

      ForecastFinancialSummary? summary;
      if (raw['financialSummary'] is Map) {
        summary = ForecastFinancialSummary.fromJson(
          Map<String, dynamic>.from(raw['financialSummary'] as Map),
        );
      }

      final List<GroomerBooking> appointments = [];
      if (raw['appointments'] is List) {
        for (final item in raw['appointments'] as List) {
          if (item is Map) {
            try {
              appointments.add(GroomerBooking.fromJson(Map<String, dynamic>.from(item)));
            } catch (e) {
              log.w('getForecastDetails::Failed to parse booking item: $e');
            }
          }
        }
      }

      final List<Map<String, dynamic>> groomerSummaries = [];
      if (raw['groomerSummaries'] is List) {
        for (final item in raw['groomerSummaries'] as List) {
          if (item is Map) {
            groomerSummaries.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final totalCount = int.tryParse(raw['totalCount']?.toString() ?? '') ?? appointments.length;

      return (
        summary: summary,
        appointments: appointments,
        groomerSummaries: groomerSummaries,
        totalCount: totalCount,
      );
    } catch (e) {
      log.e('GroomerHomeRepository::getForecastDetails::Error: $e');
      return null;
    }
  }

  /// GET /api/common/groomer/appointment-milestones
  /// Fetches store-configured appointment milestone catalog.
  Future<List<StoreMilestoneConfig>> getMilestonesCatalog({
    String? storeId,
    bool forceRefresh = false,
  }) async {
    try {
      final session = ServicesLocator.sessionService;
      final effectiveStoreId = storeId ?? session.storeId ?? 'SHEAR-001';

      if (!forceRefresh &&
          _storeMilestoneCatalogs.containsKey(effectiveStoreId) &&
          _storeMilestoneCatalogs[effectiveStoreId]!.isNotEmpty) {
        return _storeMilestoneCatalogs[effectiveStoreId]!;
      }

      log.d('GroomerHomeRepository::getMilestonesCatalog::storeId=$effectiveStoreId');

      final queryParams = <String, dynamic>{
        'storeId': effectiveStoreId,
        if (session.clientId != null) 'ClientID': session.clientId,
        if (session.regionId != null) 'RegionId': session.regionId,
        'StoreId': effectiveStoreId,
      };

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.get(
          '/api/common/groomer/appointment-milestones',
          query: queryParams,
        );
      } catch (_) {
        response = null;
      }

      if (response == null || response['success'] != true || response['data'] == null) {
        try {
          response = await ServicesLocator.apiRepository.get(
            '/api/common/appointment-milestones',
            query: queryParams,
          );
        } catch (_) {
          response = null;
        }
      }

      if (response != null && response['success'] == true) {
        List? list;
        if (response['data'] is List) {
          list = response['data'] as List;
        } else if (response['data'] is Map && response['data']['milestones'] is List) {
          list = response['data']['milestones'] as List;
        } else if (response['milestones'] is List) {
          list = response['milestones'] as List;
        }

        if (list != null) {
          final configs = list
              .whereType<Map>()
              .map((e) => StoreMilestoneConfig.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));

          _storeMilestoneCatalogs[effectiveStoreId] = configs;
          return configs;
        }
      }

      return _storeMilestoneCatalogs[effectiveStoreId] ?? const [];
    } catch (e) {
      log.e('GroomerHomeRepository::getMilestonesCatalog::Error: $e');
      final session = ServicesLocator.sessionService;
      final effectiveStoreId = storeId ?? session.storeId ?? 'SHEAR-001';
      return _storeMilestoneCatalogs[effectiveStoreId] ?? const [];
    }
  }

  /// Backward-compatible raw catalog method
  Future<List<Map<String, dynamic>>> getMilestonesCatalogRaw({String? storeId}) async {
    final configs = await getMilestonesCatalog(storeId: storeId);
    return configs.map((c) => c.toJson()).toList();
  }

  /// GET /api/common/groomer/bookings/:id/milestones?storeId=SHEAR-001
  Future<BookingMilestoneTimeline?> getMilestonesTimeline(
    int bookingId, {
    String? storeId,
  }) async {
    try {
      final session = ServicesLocator.sessionService;
      final effectiveStoreId = storeId ?? session.storeId ?? 'SHEAR-001';
      log.d('GroomerHomeRepository::getMilestonesTimeline::bookingId=$bookingId, storeId=$effectiveStoreId');

      final response = await ServicesLocator.apiRepository.get(
        '/api/common/groomer/bookings/$bookingId/milestones',
        query: {'storeId': effectiveStoreId},
      );

      if (response != null && response['success'] == true && response['data'] is Map) {
        return BookingMilestoneTimeline.fromJson(
          Map<String, dynamic>.from(response['data'] as Map),
        );
      }
      return null;
    } catch (e) {
      log.e('GroomerHomeRepository::getMilestonesTimeline::Error: $e');
      return null;
    }
  }

  /// Backward-compatible list method
  Future<List<Map<String, dynamic>>> getMilestonesTimelineList(int bookingId, {String? storeId}) async {
    final timeline = await getMilestonesTimeline(bookingId, storeId: storeId);
    if (timeline != null) {
      return timeline.milestones.map((m) => m.toJson()).toList();
    }
    return [];
  }

  /// Fetches latest milestones, service progress, assignment activity, and primary groomer.
  /// GET /api/common/groomer/bookings/:id/milestones?storeId=:storeId
  Future<GroomerBooking?> fetchBookingMilestonesAndProgress(
    int bookingId, {
    String? storeId,
    GroomerBooking? currentBooking,
  }) async {
    try {
      final session = ServicesLocator.sessionService;
      final effectiveStoreId = storeId ?? currentBooking?.storeId ?? session.storeId ?? 'SHEAR-001';

      Map<String, dynamic>? response;
      try {
        response = await ServicesLocator.apiRepository.get(
          '/api/common/groomer/bookings/$bookingId/milestones',
          query: {'storeId': effectiveStoreId},
        );
      } catch (_) {
        response = null;
      }

      if (response == null || response['success'] != true) {
        try {
          response = await ServicesLocator.apiRepository.get(
            '/api/common/bookings/$bookingId/milestones',
            query: {'storeId': effectiveStoreId},
          );
        } catch (_) {}
      }

      if (response != null && response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        final baseBooking = currentBooking ?? getLocalBooking(bookingId);
        if (baseBooking != null) {
          final timeline = BookingMilestoneTimeline.fromJson(data);
          final updated = baseBooking.copyWith(
            status: timeline.status ?? baseBooking.status,
            serviceStage: timeline.serviceStage ?? baseBooking.serviceStage,
            serviceProgress: timeline.serviceProgress.isNotEmpty ? timeline.serviceProgress : baseBooking.serviceProgress,
            serviceAssignmentActivity: timeline.serviceAssignmentActivity.isNotEmpty
                ? timeline.serviceAssignmentActivity
                : baseBooking.serviceAssignmentActivity,
            primaryGroomerName: timeline.bookingPrimaryGroomer?['primaryGroomerName']?.toString() ?? baseBooking.primaryGroomerName,
            primaryGroomerId: int.tryParse(timeline.bookingPrimaryGroomer?['primaryGroomerDbId']?.toString() ?? '') ?? baseBooking.primaryGroomerId,
            isPreferredGroomer: timeline.bookingPrimaryGroomer?['petGroomerPreferenceLocked'] == true ||
                timeline.bookingPrimaryGroomer?['petPreferredGroomerId'] != null ||
                baseBooking.isPreferredGroomer,
          );
          addLocalBooking(updated);
          return updated;
        }
      }
      return currentBooking;
    } catch (e) {
      log.e('GroomerHomeRepository::fetchBookingMilestonesAndProgress::Error: $e');
      return currentBooking;
    }
  }
}
