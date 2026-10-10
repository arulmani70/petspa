import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

part 'groomer_home_event.dart';
part 'groomer_home_state.dart';

class GroomerHomeBloc extends Bloc<GroomerHomeEvent, GroomerHomeState> {
  final GroomerHomeRepository repository;
  final Logger log = Logger();

  StreamSubscription<AppNotification>? _notificationSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  GroomerHomeBloc({required this.repository}) : super(GroomerHomeState.initial) {
    on<GroomerHomeFetchAllDataEvent>(_onFetchAllData);
    on<GroomerHomeFetchProfileEvent>(_onFetchProfile);
    on<GroomerHomeUpdateProfileEvent>(_onUpdateProfile);
    on<GroomerHomeApproveBookingEvent>(_onApproveBooking);
    on<GroomerHomeRejectBookingEvent>(_onRejectBooking);
    on<GroomerHomeStartBookingEvent>(_onStartBooking);
    on<GroomerHomeCompleteBookingEvent>(_onCompleteBooking);
    on<GroomerHomeApproveCancellationEvent>(_onApproveCancellation);
    on<GroomerHomeRejectCancellationEvent>(_onRejectCancellation);
    on<GroomerHomeSelectDateEvent>(_onSelectDate);
    on<GroomerHomeSwitchTabEvent>(_onSwitchTab);
    on<GroomerHomeMarkNotificationReadEvent>(_onMarkNotificationRead);
    on<GroomerHomeMarkAllNotificationsReadEvent>(_onMarkAllNotificationsRead);
    on<GroomerHomeConnectSocketEvent>(_onConnectSocket);
    on<GroomerHomeSocketConnectionChangedEvent>(_onSocketConnectionChanged);
    on<GroomerHomeRealtimeNotificationReceivedEvent>(_onRealtimeNotificationReceived);
    on<GroomerHomeSaveScheduleEvent>(_onSaveSchedule);
    on<GroomerHomeLogoutEvent>(_onLogout);
    on<GroomerHomeCreateBookingForUserEvent>(_onCreateBookingForUser);
    on<GroomerHomeSearchCustomersEvent>(_onSearchCustomers);
    on<GroomerHomeGetCustomerPetsEvent>(_onGetCustomerPets);
    on<GroomerHomeGetSalonGroomersEvent>(_onGetSalonGroomers);
    on<GroomerHomeGetBookingServicesEvent>(_onGetBookingServices);
    on<GroomerHomeCheckAvailabilityEvent>(_onCheckAvailability);
    on<GroomerHomeResetBookingDialogEvent>(_onResetBookingDialog);

    _initSocketSubscriptions();
  }

  void _initSocketSubscriptions() {
    _notificationSubscription?.cancel();
    _notificationSubscription = repository.realtimeNotificationStream.listen(
      (notification) {
        add(GroomerHomeRealtimeNotificationReceivedEvent(notification));
      },
      onError: (err) {
        log.e('GroomerHomeBloc::realtimeNotificationStream error: $err');
      },
    );

    _connectionSubscription?.cancel();
    _connectionSubscription = repository.realtimeConnectionStatusStream.listen(
      (isConnected) {
        add(GroomerHomeSocketConnectionChangedEvent(isConnected));
      },
      onError: (err) {
        log.e('GroomerHomeBloc::realtimeConnectionStatusStream error: $err');
      },
    );
  }

  Future<void> _onConnectSocket(
    GroomerHomeConnectSocketEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    log.d('GroomerHomeBloc::_onConnectSocket::Connecting realtime socket');
    await repository.connectRealtimeNotifications(
      token: event.token,
      serverUrl: event.serverUrl,
    );
  }

  void _onSocketConnectionChanged(
    GroomerHomeSocketConnectionChangedEvent event,
    Emitter<GroomerHomeState> emit,
  ) {
    emit(state.copyWith(isSocketConnected: () => event.isConnected));
  }

  Future<void> _onRealtimeNotificationReceived(
    GroomerHomeRealtimeNotificationReceivedEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final newNotif = event.notification;
    log.d('GroomerHomeBloc::_onRealtimeNotificationReceived::Received #${newNotif.id} - ${newNotif.title}');

    // Convert AppNotification to Map format for the state list
    final notifMap = <String, dynamic>{
      'id': newNotif.id,
      'notificationId': newNotif.id,
      'title': newNotif.title,
      'body': newNotif.message,
      'message': newNotif.message,
      'type': newNotif.type,
      'isRead': newNotif.isRead,
      'is_read': newNotif.isRead,
      'createdAt': newNotif.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      if (newNotif.metadata != null) 'data': newNotif.metadata,
      if (newNotif.metadata != null) 'metadata': newNotif.metadata,
    };

    // Deduplication check: prevent adding duplicate notifications with identical id
    final existingList = List<Map<String, dynamic>>.from(state.notifications);
    final existsIndex = existingList.indexWhere((item) {
      final existingId = item['id'] ?? item['notificationId'];
      final incomingId = notifMap['id'] ?? notifMap['notificationId'];
      if (existingId != null && incomingId != null && existingId.toString() == incomingId.toString()) {
        return true;
      }
      return false;
    });

    if (existsIndex >= 0) {
      log.d('GroomerHomeBloc::_onRealtimeNotificationReceived::Updating existing notification #${newNotif.id}');
      existingList[existsIndex] = notifMap;
    } else {
      log.d('GroomerHomeBloc::_onRealtimeNotificationReceived::Prepending new notification #${newNotif.id}');
      existingList.insert(0, notifMap);
    }

    emit(state.copyWith(
      notifications: () => existingList,
      actionMessage: () => newNotif.title.isNotEmpty ? newNotif.title : 'New notification received',
    ));

    // If the notification is booking/cancellation related, refresh booking lists
    final type = newNotif.type.toLowerCase();
    final isBookingRelated = type.contains('booking') ||
        type.contains('cancellation') ||
        (newNotif.metadata != null &&
            (newNotif.metadata!.containsKey('bookingId') ||
                newNotif.metadata!.containsKey('booking_id')));

    if (isBookingRelated) {
      log.d('GroomerHomeBloc::_onRealtimeNotificationReceived::Refreshing bookings due to booking event');
      try {
        final upcoming = await repository.getUpcomingBookings();
        final pending = await repository.getPendingBookings();
        final cancellationReqs = await repository.getCancellationRequests();
        emit(state.copyWith(
          upcomingBookings: () => upcoming,
          pendingBookings: () => pending,
          cancellationRequests: () => cancellationReqs,
        ));
      } catch (e) {
        log.e('GroomerHomeBloc::_onRealtimeNotificationReceived::Error refreshing bookings: $e');
      }
    }
  }

  Future<void> _onFetchAllData(
    GroomerHomeFetchAllDataEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    emit(state.copyWith(
      status: () => GroomerHomeStatus.loading,
      errorMessage: () => null,
      groomer: () => repository.getCurrentGroomer(),
      bookingForUserSuccess: () => false,
      bookingForUserError: () => null,
    ));

    try {
      final results = await Future.wait([
        repository.getProfile(),
        repository.getUpcomingBookings(),
        repository.getPendingBookings(),
        repository.getPastBookings(),
        repository.getCancelledBookings(),
        repository.getCancellationRequests(),
        repository.getServiceHours(),
        repository.getHolidays(),
        repository.getNotifications(),
        repository.getGroomerHours(),
      ]);

      emit(state.copyWith(
        status: () => GroomerHomeStatus.loaded,
        groomer: () => results[0] as GroomerUser? ?? state.groomer,
        upcomingBookings: () => results[1] as List<GroomerBooking>? ?? [],
        pendingBookings: () => results[2] as List<GroomerBooking>? ?? [],
        pastBookings: () => results[3] as List<GroomerBooking>? ?? [],
        cancelledBookings: () => results[4] as List<GroomerBooking>? ?? [],
        cancellationRequests: () => results[5] as List<GroomerBooking>? ?? [],
        serviceHours: () => results[6] as List<StoreServiceHour>? ?? [],
        holidays: () => results[7] as List<StoreHoliday>? ?? [],
        notifications: () => results[8] as List<Map<String, dynamic>>? ?? [],
        groomerHours: () => results[9] as List<GroomerWorkingHour>? ?? [],
        bookingForUserSuccess: () => false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: () => GroomerHomeStatus.failure,
        errorMessage: () => 'Unable to load real-time data. Pull to refresh.',
        bookingForUserSuccess: () => false,
      ));
    }
  }

  Future<void> _onSaveSchedule(
    GroomerHomeSaveScheduleEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    emit(state.copyWith(status: () => GroomerHomeStatus.loading));
    try {
      bool serviceHoursSaved = true;
      bool groomerHoursSaved = true;

      if (event.serviceHours != null && event.serviceHours!.isNotEmpty) {
        serviceHoursSaved = await repository.updateServiceHours(event.serviceHours!);
      }

      if (event.groomerHours != null && event.groomerHours!.isNotEmpty) {
        groomerHoursSaved = await repository.saveGroomerHours(event.groomerHours!);
      }

      if (serviceHoursSaved || groomerHoursSaved) {
        // Re-fetch the true persisted state from the backend
        final refreshedServiceHours = await repository.getServiceHours();
        final refreshedGroomerHours = await repository.getGroomerHours();

        emit(state.copyWith(
          status: () => GroomerHomeStatus.success,
          serviceHours: () => refreshedServiceHours.isNotEmpty ? refreshedServiceHours : (event.serviceHours ?? state.serviceHours),
          groomerHours: () => refreshedGroomerHours.isNotEmpty ? refreshedGroomerHours : (event.groomerHours ?? state.groomerHours),
          actionMessage: () => 'Working hours updated successfully.',
        ));
      } else {
        emit(state.copyWith(
          status: () => GroomerHomeStatus.failure,
          errorMessage: () => 'Unable to update working hours. Please try again.',
        ));
      }
    } catch (e) {
      log.e('GroomerHomeBloc::_onSaveSchedule::Error: $e');
      emit(state.copyWith(
        status: () => GroomerHomeStatus.failure,
        errorMessage: () => 'Error saving working hours: $e',
      ));
    }
  }

  Future<void> _onFetchProfile(
    GroomerHomeFetchProfileEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    try {
      final profile = await repository.getProfile();
      if (profile != null) {
        emit(state.copyWith(groomer: () => profile));
      }
    } catch (e) {
      log.e('GroomerHomeBloc::_onFetchProfile::Error: $e');
    }
  }

  Future<void> _onUpdateProfile(
    GroomerHomeUpdateProfileEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    emit(state.copyWith(status: () => GroomerHomeStatus.loading));
    try {
      final updated = await repository.updateProfile(
        firstName: event.firstName,
        lastName: event.lastName,
        mobile: event.mobile,
        highlights: event.highlights,
        multiBookingEnabled: event.multiBookingEnabled,
        slotBookingLimit: event.slotBookingLimit,
      );

      if (updated != null) {
        emit(state.copyWith(
          status: () => GroomerHomeStatus.success,
          groomer: () => updated,
          actionMessage: () => 'Groomer profile updated successfully',
        ));
      } else {
        emit(state.copyWith(
          status: () => GroomerHomeStatus.failure,
          errorMessage: () => 'Failed to update profile.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: () => GroomerHomeStatus.failure,
        errorMessage: () => 'Failed to update profile: $e',
      ));
    }
  }

  Future<void> _onApproveBooking(
    GroomerHomeApproveBookingEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final success = await repository.approveBooking(event.bookingId);
    if (success) {
      emit(state.copyWith(actionMessage: () => 'Booking #${event.bookingId} approved successfully'));
      add(const GroomerHomeFetchAllDataEvent());
    } else {
      emit(state.copyWith(errorMessage: () => 'Failed to approve booking. Please try again.'));
    }
  }

  Future<void> _onRejectBooking(
    GroomerHomeRejectBookingEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final success = await repository.rejectBooking(event.bookingId);
    if (success) {
      emit(state.copyWith(actionMessage: () => 'Booking #${event.bookingId} rejected'));
      add(const GroomerHomeFetchAllDataEvent());
    } else {
      emit(state.copyWith(errorMessage: () => 'Failed to reject booking. Please try again.'));
    }
  }

  Future<void> _onStartBooking(
    GroomerHomeStartBookingEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final success = await repository.startBooking(event.bookingId);
    if (success) {
      emit(state.copyWith(actionMessage: () => 'Booking #${event.bookingId} is now In Progress'));
      add(const GroomerHomeFetchAllDataEvent());
    } else {
      emit(state.copyWith(errorMessage: () => 'Failed to start appointment. Please try again.'));
    }
  }

  Future<void> _onCompleteBooking(
    GroomerHomeCompleteBookingEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final success = await repository.completeBooking(event.bookingId);
    if (success) {
      emit(state.copyWith(actionMessage: () => 'Booking #${event.bookingId} completed successfully'));
      add(const GroomerHomeFetchAllDataEvent());
    } else {
      emit(state.copyWith(errorMessage: () => 'Failed to complete appointment. Please try again.'));
    }
  }

  Future<void> _onApproveCancellation(
    GroomerHomeApproveCancellationEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final success = await repository.approveCancellation(event.bookingId);
    if (success) {
      emit(state.copyWith(actionMessage: () => 'Cancellation for Booking #${event.bookingId} approved'));
      add(const GroomerHomeFetchAllDataEvent());
    } else {
      emit(state.copyWith(errorMessage: () => 'Failed to approve cancellation.'));
    }
  }

  Future<void> _onRejectCancellation(
    GroomerHomeRejectCancellationEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final success = await repository.rejectCancellation(event.bookingId);
    if (success) {
      emit(state.copyWith(actionMessage: () => 'Cancellation for Booking #${event.bookingId} rejected'));
      add(const GroomerHomeFetchAllDataEvent());
    } else {
      emit(state.copyWith(errorMessage: () => 'Failed to reject cancellation.'));
    }
  }

  void _onSelectDate(
    GroomerHomeSelectDateEvent event,
    Emitter<GroomerHomeState> emit,
  ) {
    emit(state.copyWith(selectedDate: () => event.date));
  }

  void _onSwitchTab(
    GroomerHomeSwitchTabEvent event,
    Emitter<GroomerHomeState> emit,
  ) {
    emit(state.copyWith(currentTabIndex: () => event.tabIndex));
  }

  Future<void> _onMarkNotificationRead(
    GroomerHomeMarkNotificationReadEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final ok = await repository.markNotificationRead(event.notificationId);
    if (ok) {
      final updated = state.notifications.map((n) {
        final id = n['id'] is int ? n['id'] as int : int.tryParse(n['id']?.toString() ?? '0') ?? 0;
        if (id == event.notificationId) {
          final copy = Map<String, dynamic>.from(n);
          copy['isRead'] = true;
          copy['is_read'] = true;
          return copy;
        }
        return n;
      }).toList();
      emit(state.copyWith(notifications: () => updated));
    }
  }

  Future<void> _onMarkAllNotificationsRead(
    GroomerHomeMarkAllNotificationsReadEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final ok = await repository.markAllNotificationsRead();
    if (ok) {
      final updated = state.notifications.map((n) {
        final copy = Map<String, dynamic>.from(n);
        copy['isRead'] = true;
        copy['is_read'] = true;
        return copy;
      }).toList();
      emit(state.copyWith(
        notifications: () => updated,
        actionMessage: () => 'All notifications marked as read',
      ));
    }
  }

  Future<void> _onLogout(
    GroomerHomeLogoutEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    await repository.logout();
    emit(GroomerHomeState.initial);
    Routes.redirectToLogin(isGroomer: true);
  }

  bool _isCreatingBooking = false;

  Future<void> _onCreateBookingForUser(
    GroomerHomeCreateBookingForUserEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    if (_isCreatingBooking || state.isCreatingBookingForUser) {
      log.w('GroomerHomeBloc::_onCreateBookingForUser::Booking creation already in progress. Ignoring duplicate trigger.');
      return;
    }
    _isCreatingBooking = true;
    log.d('GroomerHomeBloc::_onCreateBookingForUser::Creating booking for user ${event.userId} with requested groomer ${event.groomerId}');
    emit(state.copyWith(
      isCreatingBookingForUser: () => true,
      bookingForUserSuccess: () => false,
      bookingForUserError: () => null,
      lastCreatedBookingId: () => null,
    ));
    try {
      final res = await repository.createBookingForUser(
        userId: event.userId,
        petId: event.petId,
        serviceId: event.serviceId,
        packageId: event.packageId,
        addOnIds: event.addOnIds,
        groomerId: event.groomerId,
        bookingDate: event.bookingDate,
        startTime: event.startTime,
        endTime: event.endTime,
      );
      if (res != null) {
        final rawId = res['bookingId'] ?? res['id'] ?? (res['data'] is Map ? res['data']['bookingId'] : null);
        final bookingId = rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);

        emit(state.copyWith(
          isCreatingBookingForUser: () => false,
          bookingForUserSuccess: () => true,
          bookingForUserError: () => null,
          lastCreatedBookingId: () => bookingId,
        ));
        add(const GroomerHomeFetchAllDataEvent());
      } else {
        emit(state.copyWith(
          isCreatingBookingForUser: () => false,
          bookingForUserSuccess: () => false,
          bookingForUserError: () => 'Unable to create the booking. Please check slot availability and try again.',
          lastCreatedBookingId: () => null,
        ));
      }
    } catch (e) {
      log.e('GroomerHomeBloc::_onCreateBookingForUser::Error: $e');
      emit(state.copyWith(
        isCreatingBookingForUser: () => false,
        bookingForUserSuccess: () => false,
        bookingForUserError: () => 'Unable to create the booking: $e',
        lastCreatedBookingId: () => null,
      ));
    } finally {
      _isCreatingBooking = false;
    }
  }

  Future<void> _onSearchCustomers(
    GroomerHomeSearchCustomersEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    log.d('GroomerHomeBloc::_onSearchCustomers::Searching customers (query: ${event.query})');
    emit(state.copyWith(
      isSearchingCustomers: () => true,
      customerError: () => null,
    ));
    try {
      final customers = await repository.searchCustomers(query: event.query);
      emit(state.copyWith(
        searchedCustomers: () => customers,
        isSearchingCustomers: () => false,
      ));
    } catch (e) {
      log.e('GroomerHomeBloc::_onSearchCustomers::Error: $e');
      emit(state.copyWith(
        searchedCustomers: () => [],
        isSearchingCustomers: () => false,
        customerError: () => 'Unable to load customers. Please try again.',
      ));
    }
  }

  Future<void> _onGetCustomerPets(
    GroomerHomeGetCustomerPetsEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    log.d('GroomerHomeBloc::_onGetCustomerPets::Fetching pets for user ${event.userId}');
    emit(state.copyWith(
      isLoadingCustomerPets: () => true,
      petError: () => null,
    ));
    try {
      final pets = await repository.getCustomerPets(event.userId);
      emit(state.copyWith(
        customerPets: () => pets,
        isLoadingCustomerPets: () => false,
      ));
    } catch (e) {
      log.e('GroomerHomeBloc::_onGetCustomerPets::Error: $e');
      emit(state.copyWith(
        customerPets: () => [],
        isLoadingCustomerPets: () => false,
        petError: () => 'Unable to load pets. Please try again.',
      ));
    }
  }

  Future<void> _onGetSalonGroomers(
    GroomerHomeGetSalonGroomersEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    log.d('GroomerHomeBloc::_onGetSalonGroomers::Fetching salon groomers from /api/groomers');
    emit(state.copyWith(
      isLoadingSalonGroomers: () => true,
      salonGroomersError: () => null,
    ));
    try {
      final groomers = await repository.getSalonGroomers();
      emit(state.copyWith(
        salonGroomers: () => groomers,
        isLoadingSalonGroomers: () => false,
      ));
    } catch (e) {
      log.e('GroomerHomeBloc::_onGetSalonGroomers::Error: $e');
      emit(state.copyWith(
        salonGroomers: () => [],
        isLoadingSalonGroomers: () => false,
        salonGroomersError: () => 'Unable to load groomers. Please try again.',
      ));
    }
  }

  Future<void> _onGetBookingServices(
    GroomerHomeGetBookingServicesEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    log.d('GroomerHomeBloc::_onGetBookingServices::Fetching booking services from /api/service-packages');
    emit(state.copyWith(
      isLoadingBookingServices: () => true,
      bookingServicesError: () => null,
    ));
    try {
      final res = await repository.getBookingServices();
      emit(state.copyWith(
        bookingServices: () => [...res.breeds, ...res.walkIn],
        bookingPackages: () => res.packages,
        bookingAddOns: () => res.addOns,
        isLoadingBookingServices: () => false,
      ));
    } catch (e) {
      log.e('GroomerHomeBloc::_onGetBookingServices::Error: $e');
      emit(state.copyWith(
        bookingServices: () => [],
        bookingPackages: () => [],
        bookingAddOns: () => [],
        isLoadingBookingServices: () => false,
        bookingServicesError: () => 'Unable to load services. Please try again.',
      ));
    }
  }

  Future<void> _onCheckAvailability(
    GroomerHomeCheckAvailabilityEvent event,
    Emitter<GroomerHomeState> emit,
  ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(event.date);
    log.d('GroomerHomeBloc::_onCheckAvailability::Checking availability date=$dateStr, groomerId=${event.groomerId}, serviceId=${event.serviceId}, packageId=${event.packageId}, addOnIds=${event.addOnIds}');
    emit(state.copyWith(
      isCheckingAvailability: () => true,
      availabilityMessage: () => null,
      isSlotAvailable: () => false,
      availableTimeSlots: () => [],
      bookedTimeSlots: () => [],
      slotDurationMinutes: () => null,
      slotTotalPrice: () => null,
    ));

    try {
      final resp = await repository.getAvailability(
        date: dateStr,
        serviceId: event.serviceId,
        packageId: event.packageId,
        addOnIds: event.addOnIds,
        groomerId: event.groomerId,
      );

      if (resp != null && resp['success'] == true && resp['data'] != null) {
        final data = resp['data'] as Map<String, dynamic>;
        final rawSlots = data['availableSlots'] as List<dynamic>? ?? [];
        final rawBooked = data['bookedSlots'] as List<dynamic>? ?? [];

        final apiDur = data['totalDurationMinutes'];
        final int? durationMinutes = (apiDur is num && apiDur > 0) ? apiDur.toInt() : null;

        final apiPrice = data['totalPrice'];
        final double? totalPrice = apiPrice is num
            ? apiPrice.toDouble()
            : (apiPrice is String ? double.tryParse(apiPrice.replaceAll(RegExp(r'[^0-9.]'), '')) : null);

        final parsedSlots = <Map<String, dynamic>>[];
        for (final s in rawSlots) {
          if (s is Map) {
            parsedSlots.add(Map<String, dynamic>.from(s));
          }
        }

        final parsedBooked = <Map<String, dynamic>>[];
        for (final b in rawBooked) {
          if (b is Map) {
            parsedBooked.add(Map<String, dynamic>.from(b));
          }
        }

        // Sort slots chronologically
        parsedSlots.sort((a, b) {
          final aStart = a['startTime']?.toString() ?? '';
          final bStart = b['startTime']?.toString() ?? '';
          return aStart.compareTo(bStart);
        });

        final hasAvailableSlots = parsedSlots.any((s) {
          final isAvail = s['isAvailable'] != false;
          final remaining = s['remaining'];
          final maxBookings = s['maxBookings'];
          final bookingCount = s['bookingCount'];
          final hasCap = remaining == null || (remaining is num && remaining > 0);
          final notMaxed = maxBookings == null || bookingCount == null || ((bookingCount is num) && (maxBookings is num) && bookingCount < maxBookings);
          return isAvail && hasCap && notMaxed;
        });

        emit(state.copyWith(
          availableTimeSlots: () => parsedSlots,
          bookedTimeSlots: () => parsedBooked,
          slotDurationMinutes: () => durationMinutes,
          slotTotalPrice: () => totalPrice,
          isCheckingAvailability: () => false,
          isSlotAvailable: () => hasAvailableSlots,
          availabilityMessage: () => hasAvailableSlots
              ? null
              : 'No available time slots on this date. Please select another date.',
        ));
      } else {
        log.w('GroomerHomeBloc::_onCheckAvailability::Unsuccessful response: $resp');
        emit(state.copyWith(
          availableTimeSlots: () => [],
          bookedTimeSlots: () => [],
          slotDurationMinutes: () => null,
          slotTotalPrice: () => null,
          isCheckingAvailability: () => false,
          isSlotAvailable: () => false,
          availabilityMessage: () => 'Unable to load available time slots. Please try again.',
        ));
      }
    } catch (e) {
      log.e('GroomerHomeBloc::_onCheckAvailability::Error: $e');
      emit(state.copyWith(
        availableTimeSlots: () => [],
        bookedTimeSlots: () => [],
        slotDurationMinutes: () => null,
        slotTotalPrice: () => null,
        isCheckingAvailability: () => false,
        isSlotAvailable: () => false,
        availabilityMessage: () => 'Unable to load available time slots. Please try again.',
      ));
    }
  }

  void _onResetBookingDialog(
    GroomerHomeResetBookingDialogEvent event,
    Emitter<GroomerHomeState> emit,
  ) {
    emit(state.copyWith(
      isCreatingBookingForUser: () => false,
      bookingForUserSuccess: () => false,
      bookingForUserError: () => null,
      lastCreatedBookingId: () => null,
    ));
  }

  @override
  Future<void> close() async {
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    return super.close();
  }
}

