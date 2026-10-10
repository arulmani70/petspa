import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/repo/groomer_repository.dart';

part 'groomer_event.dart';
part 'groomer_state.dart';

class GroomerBloc extends Bloc<GroomerEvent, GroomerState> {
  GroomerBloc({required GroomerRepository repository})
      : _repository = repository,
        super(GroomerState.initial) {
    on<GroomerLoginEvent>(_onLogin);
    on<GroomerSetupAccountEvent>(_onSetupAccount);
    on<GroomerFetchAllDataEvent>(_onFetchAllData);
    on<GroomerFetchProfileEvent>(_onFetchProfile);
    on<GroomerUpdateProfileEvent>(_onUpdateProfile);
    on<GroomerFetchBookingsEvent>(_onFetchBookings);
    on<GroomerApproveBookingEvent>(_onApproveBooking);
    on<GroomerRejectBookingEvent>(_onRejectBooking);
    on<GroomerStartBookingEvent>(_onStartBooking);
    on<GroomerCompleteBookingEvent>(_onCompleteBooking);
    on<GroomerApproveCancellationEvent>(_onApproveCancellation);
    on<GroomerRejectCancellationEvent>(_onRejectCancellation);
    on<GroomerSelectDateEvent>(_onSelectDate);
    on<GroomerSwitchTabEvent>(_onSwitchTab);
    on<GroomerMarkNotificationReadEvent>(_onMarkNotificationRead);
    on<GroomerMarkAllNotificationsReadEvent>(_onMarkAllNotificationsRead);
    on<GroomerLogoutEvent>(_onLogout);
    on<GroomerCreateBookingForUserEvent>(_onCreateBookingForUser);
  }

  final GroomerRepository _repository;
  final Logger _log = Logger();

  Future<void> _onLogin(
    GroomerLoginEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onLogin::email=${event.email}');
    try {
      emit(state.copyWith(status: () => GroomerStatus.loading));
      final resp = await _repository.login(
        email: event.email,
        password: event.password,
      );
      if (resp != null) {
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          groomer: () => resp.groomer,
          message: () => 'Login successful',
        ));
      } else {
        emit(state.copyWith(
          status: () => GroomerStatus.failure,
          message: () => 'Login failed. Please check your credentials.',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onLogin::Error: $e');
      emit(state.copyWith(
        status: () => GroomerStatus.failure,
        message: () => e.toString().replaceAll('Exception:', '').trim(),
      ));
    }
  }

  Future<void> _onSetupAccount(
    GroomerSetupAccountEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onSetupAccount::email=${event.email}');
    try {
      emit(state.copyWith(status: () => GroomerStatus.loading));
      final resp = await _repository.setupAccount(
        tempLoginId: event.tempLoginId,
        tempPassword: event.tempPassword,
        email: event.email,
        password: event.password,
        confirmPassword: event.confirmPassword,
      );
      if (resp != null) {
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          groomer: () => resp.groomer,
          message: () => 'Account setup successful',
        ));
      } else {
        emit(state.copyWith(
          status: () => GroomerStatus.failure,
          message: () => 'Account setup failed. Please try again.',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onSetupAccount::Error: $e');
      emit(state.copyWith(
        status: () => GroomerStatus.failure,
        message: () => e.toString().replaceAll('Exception:', '').trim(),
      ));
    }
  }

  Future<void> _onFetchAllData(
    GroomerFetchAllDataEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onFetchAllData::Fetching all groomer data');
    try {
      emit(state.copyWith(
        status: () => GroomerStatus.loading,
        groomer: () => _repository.getCurrentGroomer() ?? state.groomer,
      ));

      final results = await Future.wait([
        _repository.getProfile(),
        _repository.getUpcomingBookings(),
        _repository.getPendingBookings(),
        _repository.getPastBookings(),
        _repository.getCancelledBookings(),
        _repository.getCancellationRequests(),
        _repository.getServiceHours(),
        _repository.getHolidays(),
        _repository.getNotifications(),
      ]);

      emit(state.copyWith(
        status: () => GroomerStatus.loaded,
        groomer: () => results[0] as GroomerUser? ?? state.groomer,
        upcomingBookings: () => results[1] as List<GroomerBooking>? ?? [],
        pendingBookings: () => results[2] as List<GroomerBooking>? ?? [],
        pastBookings: () => results[3] as List<GroomerBooking>? ?? [],
        cancelledBookings: () => results[4] as List<GroomerBooking>? ?? [],
        cancellationRequests: () => results[5] as List<GroomerBooking>? ?? [],
        serviceHours: () => results[6] as List<StoreServiceHour>? ?? [],
        holidays: () => results[7] as List<StoreHoliday>? ?? [],
        notifications: () => results[8] as List<Map<String, dynamic>>? ?? [],
        message: () => 'Data refreshed successfully',
      ));
    } catch (e) {
      _log.e('GroomerBloc::_onFetchAllData::Error: $e');
      emit(state.copyWith(
        status: () => GroomerStatus.failure,
        message: () => 'Unable to load real-time data. Pull to refresh.',
      ));
    }
  }

  Future<void> _onFetchProfile(
    GroomerFetchProfileEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onFetchProfile::Fetching profile');
    try {
      final profile = await _repository.getProfile();
      if (profile != null) {
        emit(state.copyWith(
          groomer: () => profile,
          status: () => GroomerStatus.loaded,
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onFetchProfile::Error: $e');
    }
  }

  Future<void> _onUpdateProfile(
    GroomerUpdateProfileEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onUpdateProfile::Updating profile');
    try {
      emit(state.copyWith(status: () => GroomerStatus.loading));
      final updated = await _repository.updateProfile(
        firstName: event.firstName,
        lastName: event.lastName,
        mobile: event.mobile,
        multiBookingEnabled: event.multiBookingEnabled,
        slotBookingLimit: event.slotBookingLimit,
      );
      if (updated != null) {
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          groomer: () => updated,
          message: () => 'Profile updated successfully',
        ));
      } else {
        emit(state.copyWith(
          status: () => GroomerStatus.failure,
          message: () => 'Failed to update profile',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onUpdateProfile::Error: $e');
      emit(state.copyWith(
        status: () => GroomerStatus.failure,
        message: () => e.toString().replaceAll('Exception:', '').trim(),
      ));
    }
  }

  Future<void> _onFetchBookings(
    GroomerFetchBookingsEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onFetchBookings::Fetching bookings');
    try {
      final results = await Future.wait([
        _repository.getUpcomingBookings(),
        _repository.getPendingBookings(),
        _repository.getPastBookings(),
        _repository.getCancelledBookings(),
        _repository.getCancellationRequests(),
      ]);

      emit(state.copyWith(
        upcomingBookings: () => results[0],
        pendingBookings: () => results[1],
        pastBookings: () => results[2],
        cancelledBookings: () => results[3],
        cancellationRequests: () => results[4],
        status: () => GroomerStatus.loaded,
      ));
    } catch (e) {
      _log.e('GroomerBloc::_onFetchBookings::Error: $e');
    }
  }

  Future<void> _onApproveBooking(
    GroomerApproveBookingEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onApproveBooking::bookingId=${event.bookingId}');
    try {
      final success = await _repository.approveBooking(event.bookingId);
      if (success) {
        add(const GroomerFetchBookingsEvent());
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          message: () => 'Booking approved successfully',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onApproveBooking::Error: $e');
    }
  }

  Future<void> _onRejectBooking(
    GroomerRejectBookingEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onRejectBooking::bookingId=${event.bookingId}');
    try {
      final success = await _repository.rejectBooking(event.bookingId);
      if (success) {
        add(const GroomerFetchBookingsEvent());
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          message: () => 'Booking rejected',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onRejectBooking::Error: $e');
    }
  }

  Future<void> _onStartBooking(
    GroomerStartBookingEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onStartBooking::bookingId=${event.bookingId}');
    try {
      final success = await _repository.startBooking(event.bookingId);
      if (success) {
        add(const GroomerFetchBookingsEvent());
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          message: () => 'Appointment started (In Progress)',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onStartBooking::Error: $e');
    }
  }

  Future<void> _onCompleteBooking(
    GroomerCompleteBookingEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onCompleteBooking::bookingId=${event.bookingId}');
    try {
      final success = await _repository.completeBooking(event.bookingId);
      if (success) {
        add(const GroomerFetchBookingsEvent());
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          message: () => 'Appointment completed',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onCompleteBooking::Error: $e');
    }
  }

  Future<void> _onApproveCancellation(
    GroomerApproveCancellationEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onApproveCancellation::bookingId=${event.bookingId}');
    try {
      final success = await _repository.approveCancellation(event.bookingId);
      if (success) {
        add(const GroomerFetchBookingsEvent());
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          message: () => 'Cancellation approved',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onApproveCancellation::Error: $e');
    }
  }

  Future<void> _onRejectCancellation(
    GroomerRejectCancellationEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onRejectCancellation::bookingId=${event.bookingId}');
    try {
      final success = await _repository.rejectCancellation(event.bookingId);
      if (success) {
        add(const GroomerFetchBookingsEvent());
        emit(state.copyWith(
          status: () => GroomerStatus.success,
          message: () => 'Cancellation rejected',
        ));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onRejectCancellation::Error: $e');
    }
  }

  void _onSelectDate(
    GroomerSelectDateEvent event,
    Emitter<GroomerState> emit,
  ) {
    emit(state.copyWith(selectedDate: () => event.date));
  }

  void _onSwitchTab(
    GroomerSwitchTabEvent event,
    Emitter<GroomerState> emit,
  ) {
    emit(state.copyWith(currentTabIndex: () => event.tabIndex));
  }

  Future<void> _onMarkNotificationRead(
    GroomerMarkNotificationReadEvent event,
    Emitter<GroomerState> emit,
  ) async {
    try {
      final success = await _repository.markNotificationRead(event.notificationId);
      if (success) {
        final notifications = await _repository.getNotifications();
        emit(state.copyWith(notifications: () => notifications));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onMarkNotificationRead::Error: $e');
    }
  }

  Future<void> _onMarkAllNotificationsRead(
    GroomerMarkAllNotificationsReadEvent event,
    Emitter<GroomerState> emit,
  ) async {
    try {
      final success = await _repository.markAllNotificationsRead();
      if (success) {
        final notifications = await _repository.getNotifications();
        emit(state.copyWith(notifications: () => notifications));
      }
    } catch (e) {
      _log.e('GroomerBloc::_onMarkAllNotificationsRead::Error: $e');
    }
  }

  Future<void> _onLogout(
    GroomerLogoutEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onLogout::Logging out');
    try {
      await _repository.logout();
      emit(GroomerState.initial);
      Routes.redirectToLogin(isGroomer: true);
    } catch (e) {
      _log.e('GroomerBloc::_onLogout::Error: $e');
      Routes.redirectToLogin(isGroomer: true);
    }
  }

  Future<void> _onCreateBookingForUser(
    GroomerCreateBookingForUserEvent event,
    Emitter<GroomerState> emit,
  ) async {
    _log.d('GroomerBloc::_onCreateBookingForUser::Creating booking for user ${event.userId} with groomer ${event.groomerId}');
    try {
      final res = await _repository.createBookingForUser(
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
        add(const GroomerFetchBookingsEvent());
      }
    } catch (e) {
      _log.e('GroomerBloc::_onCreateBookingForUser::Error: $e');
    }
  }
}

