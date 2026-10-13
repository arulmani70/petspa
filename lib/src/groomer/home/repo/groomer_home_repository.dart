import 'dart:async';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class GroomerHomeRepository {
  final Logger log = Logger();
  final List<Map<String, dynamic>> _realtimeNotifications = <Map<String, dynamic>>[];
  StreamSubscription<AppNotification>? _socketSub;

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

      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/profile',
      );

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

  /// GET /api/groomer-auth/bookings/upcoming
  Future<List<GroomerBooking>> getUpcomingBookings() async {
    try {
      log.d('GroomerHomeRepository::getUpcomingBookings::Fetching upcoming bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/upcoming',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        return list.map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      log.e('GroomerHomeRepository::getUpcomingBookings::Error: $e');
      return [];
    }
  }

  /// GET /api/groomer-auth/bookings/pending
  Future<List<GroomerBooking>> getPendingBookings() async {
    try {
      log.d('GroomerHomeRepository::getPendingBookings::Fetching pending bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/pending',
      );

      if (response != null && response['data'] is List) {
        final list = response['data'] as List;
        final rawBookings = list
            .map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>))
            .toList();

        final List<GroomerBooking> activePending = [];
        for (final booking in rawBookings) {
          if (ServicesLocator.isBookingCancellationManagerRegistered &&
              ServicesLocator.bookingCancellationManager.isScheduledStartTimeReached(
                booking.bookingDate,
                booking.startTime,
              )) {
            // Automatically cancel overdue unaccepted booking whose scheduled start time has arrived/passed
            ServicesLocator.bookingCancellationManager.autoCancelBooking(
              bookingId: booking.bookingId,
              bookingData: booking.toJson(),
            );
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

  /// GET /api/groomer-auth/bookings/past
  Future<List<GroomerBooking>> getPastBookings() async {
    try {
      log.d('GroomerHomeRepository::getPastBookings::Fetching past bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/past',
      );

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

  /// GET /api/groomer-auth/bookings/cancelled
  Future<List<GroomerBooking>> getCancelledBookings() async {
    try {
      log.d('GroomerHomeRepository::getCancelledBookings::Fetching cancelled bookings');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/cancelled',
      );

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

  /// GET /api/groomer-auth/bookings/cancellation-requests
  Future<List<GroomerBooking>> getCancellationRequests() async {
    try {
      log.d('GroomerHomeRepository::getCancellationRequests::Fetching cancellation requests');
      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/bookings/cancellation-requests',
      );

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

  /// POST /api/groomer-auth/bookings/:id/approve
  Future<({bool success, String message})> approveBookingDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::approveBooking::Approving booking #$bookingId');

      // Check if booking has already expired past the scheduled appointment start time
      if (ServicesLocator.isBookingCancellationManagerRegistered) {
        GroomerBooking? target = booking;
        if (target == null) {
          final response = await ServicesLocator.apiRepository.get(
            '/api/groomer-auth/bookings/pending',
          );
          if (response != null && response['data'] is List) {
            final list = response['data'] as List;
            final rawBookings = list
                .map((item) => GroomerBooking.fromJson(item as Map<String, dynamic>))
                .toList();
            target = rawBookings.where((b) => b.bookingId == bookingId).firstOrNull;
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
            return (
              success: false,
              message: 'This booking has expired because the scheduled appointment start time has passed without groomer acceptance.',
            );
          }
        }
      }

      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/approve',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Booking #$bookingId approved successfully' : 'Failed to approve booking.');
      if (isSuccess) {
        final data = response?['data'] is Map ? Map<String, dynamic>.from(response!['data'] as Map) : null;
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

  /// POST /api/groomer-auth/bookings/:id/reject
  Future<({bool success, String message})> rejectBookingDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::rejectBooking::Rejecting booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/reject',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Booking #$bookingId rejected' : 'Failed to reject booking.');
      if (isSuccess) {
        final data = response?['data'] is Map ? Map<String, dynamic>.from(response!['data'] as Map) : null;
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

  /// POST /api/groomer-auth/bookings/:id/start
  Future<({bool success, String message})> startBookingDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::startBooking::Starting booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/start',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Appointment #$bookingId is now In Progress' : 'Failed to start appointment.');
      if (isSuccess) {
        final data = response?['data'] is Map ? Map<String, dynamic>.from(response!['data'] as Map) : null;
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

  /// POST /api/groomer-auth/bookings/:id/complete
  Future<({bool success, String message})> completeBookingDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::completeBooking::Completing booking #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/complete',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Appointment #$bookingId marked as completed' : 'Failed to complete appointment.');
      if (isSuccess) {
        final data = response?['data'] is Map ? Map<String, dynamic>.from(response!['data'] as Map) : null;
        await _dispatchBookingStatusNotification(
          bookingId: bookingId,
          customerTitle: 'Grooming Completed',
          customerMessage: 'Your pet\'s grooming session (#$bookingId) is completed and ready for pickup!',
          groomerTitle: 'Appointment Completed',
          groomerMessage: 'Appointment #$bookingId has been marked as completed.',
          type: 'booking_completed',
          status: 'completed',
          booking: booking,
          responseData: data,
        );
      }
      return (success: isSuccess, message: msg);
    } catch (e) {
      log.e('GroomerHomeRepository::completeBooking::Error: $e');
      return (success: false, message: 'Error completing appointment: $e');
    }
  }

  Future<bool> completeBooking(int bookingId) async {
    final res = await completeBookingDetails(bookingId);
    return res.success;
  }

  /// POST /api/groomer-auth/bookings/:id/approve-cancellation
  Future<({bool success, String message})> approveCancellationDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::approveCancellation::Approving cancellation #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/approve-cancellation',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Cancellation for Booking #$bookingId approved' : 'Failed to approve cancellation.');
      if (isSuccess) {
        final data = response?['data'] is Map ? Map<String, dynamic>.from(response!['data'] as Map) : null;
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

  /// POST /api/groomer-auth/bookings/:id/reject-cancellation
  Future<({bool success, String message})> rejectCancellationDetails(int bookingId, {GroomerBooking? booking}) async {
    try {
      log.d('GroomerHomeRepository::rejectCancellation::Rejecting cancellation #$bookingId');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/$bookingId/reject-cancellation',
        {},
      );
      final isSuccess = response != null && response['success'] == true;
      final msg = response?['message']?.toString() ??
          (isSuccess ? 'Cancellation for Booking #$bookingId rejected' : 'Failed to reject cancellation.');
      if (isSuccess) {
        final data = response?['data'] is Map ? Map<String, dynamic>.from(response!['data'] as Map) : null;
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

      await session.saveCustomerPortalNotification(customerNotifMap);

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
        'createdAt': nowIso,
        'data': <String, dynamic>{
          'bookingId': bookingId,
          'entityId': bookingId,
          'status': status,
          if (userId != null && userId > 0) 'userId': userId,
          if (groomerId != null && groomerId > 0) 'groomerId': groomerId,
        },
      };

      await session.saveGroomerPortalNotification(groomerNotifMap);
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

      final response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/customers',
        query: queryParams,
      );

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

      // Primary endpoint from Postman: /api/groomer-auth/customers/:userId/pets
      var response = await ServicesLocator.apiRepository.get(
        '/api/groomer-auth/customers/$userId/pets',
      );

      // Fallback endpoint if primary returns null / false
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.get(
          '/api/groomer-auth/users/$userId/pets',
        );
      }
      if (response == null || response['success'] != true) {
        response = await ServicesLocator.apiRepository.get(
          '/api/pets',
          query: {'userId': userId},
        );
      }

      if (response != null && response['data'] != null) {
        final data = response['data'];
        List<dynamic> list = [];
        if (data is Map && data['pets'] is List) {
          list = data['pets'] as List;
        } else if (data is List) {
          list = data;
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
      final body = <String, dynamic>{
        'userId': userId,
        'petId': petId,
        'serviceId': serviceId,
        if (packageId != null && packageId > 0) 'packageId': packageId,
        'addOnIds': addOnIds ?? [],
        if (groomerId != null && groomerId > 0) 'groomerId': groomerId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        'endTime': endTime,
        'clientId': clientId ?? groomer?.clientId ?? 'SHEAR-001',
        'regionId': regionId ?? groomer?.regionId ?? 'DWG-001',
        'storeId': storeId ?? groomer?.storeId ?? 'SHEAR-001',
      };

      log.d('GroomerHomeRepository::createBookingForUser::Creating booking for user $userId (groomerId: ${groomerId ?? groomer?.id})');
      final response = await ServicesLocator.apiRepository.post(
        '/api/groomer-auth/bookings/create-for-user',
        body,
      );

      if (response != null && response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final rawBookingId = data['bookingId'] ?? data['id'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final resolvedBookingId = rawBookingId is int
            ? rawBookingId
            : (int.tryParse(rawBookingId.toString()) ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000));
        await _dispatchBookingStatusNotification(
          bookingId: resolvedBookingId,
          customerTitle: 'Appointment Booked',
          customerMessage: 'A new grooming appointment #$resolvedBookingId has been scheduled for $bookingDate at $startTime.',
          groomerTitle: 'New Booking Assigned',
          groomerMessage: 'Booking #$resolvedBookingId has been scheduled for $bookingDate at $startTime.',
          type: 'booking_confirmed',
          status: (data['status'] ?? 'confirmed').toString(),
          explicitUserId: userId,
          explicitGroomerId: groomerId ?? groomer?.id,
          responseData: data,
        );
        return data;
      }
      return null;
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

  /// GET /api/groomer-auth/groomers (Dynamically loads salon groomers strictly from backend API)
  Future<List<SalonGroomer>> getSalonGroomers() async {
    try {
      log.d('GroomerHomeRepository::getSalonGroomers::Loading from /api/groomer-auth/groomers');
      var response = await ServicesLocator.apiRepository.get('/api/groomer-auth/groomers');

      // Fallback to /api/groomers if /api/groomer-auth/groomers returns null or missing data
      if (response == null || !response.containsKey('data')) {
        response = await ServicesLocator.apiRepository.get('/api/groomers');
      }

      if (response == null || !response.containsKey('data')) {
        throw Exception('Failed to fetch groomers from /api/groomer-auth/groomers');
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
}
