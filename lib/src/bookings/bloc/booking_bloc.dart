import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';

part 'booking_event.dart';
part 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc({required BookingRepository repository})
      : _repository = repository,
        super(BookingState.initial) {
    on<InitializeBookings>(_onInitializeBookings);
    on<FetchUpcomingBookings>(_onFetchUpcomingBookings);
    on<FetchPastBookings>(_onFetchPastBookings);
    on<FetchCancelledBookings>(_onFetchCancelledBookings);
    on<CancelBookingEvent>(_onCancelBooking);
  }

  final BookingRepository _repository;
  final _log = Logger();

  Future<void> _onInitializeBookings(
    InitializeBookings event,
    Emitter<BookingState> emit,
  ) async {
    _log.d('BookingBloc::_onInitializeBookings::Initializing bookings');
    try {
      emit(state.copyWith(status: () => BookingStatus.loading));
      final upcoming = await _repository.getUpcomingBookingsApi();
      emit(state.copyWith(
        status: () => BookingStatus.loaded,
        message: () => 'Bookings initialized',
        upcomingBookings: () => upcoming,
      ));
    } catch (e) {
      _log.e('BookingBloc::_onInitializeBookings::Error: $e');
      emit(state.copyWith(
        status: () => BookingStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchUpcomingBookings(
    FetchUpcomingBookings event,
    Emitter<BookingState> emit,
  ) async {
    _log.d('BookingBloc::_onFetchUpcomingBookings::Fetching upcoming bookings');
    try {
      emit(state.copyWith(status: () => BookingStatus.loading));
      final upcoming = await _repository.getUpcomingBookingsApi();
      emit(state.copyWith(
        status: () => BookingStatus.loaded,
        message: () => 'Upcoming bookings fetched',
        upcomingBookings: () => upcoming,
      ));
    } catch (e) {
      _log.e('BookingBloc::_onFetchUpcomingBookings::Error: $e');
      emit(state.copyWith(
        status: () => BookingStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchPastBookings(
    FetchPastBookings event,
    Emitter<BookingState> emit,
  ) async {
    _log.d('BookingBloc::_onFetchPastBookings::Fetching past bookings');
    try {
      emit(state.copyWith(status: () => BookingStatus.loading));
      final past = await _repository.getPastBookingsApi();
      emit(state.copyWith(
        status: () => BookingStatus.loaded,
        message: () => 'Past bookings fetched',
        pastBookings: () => past,
      ));
    } catch (e) {
      _log.e('BookingBloc::_onFetchPastBookings::Error: $e');
      emit(state.copyWith(
        status: () => BookingStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchCancelledBookings(
    FetchCancelledBookings event,
    Emitter<BookingState> emit,
  ) async {
    _log.d('BookingBloc::_onFetchCancelledBookings::Fetching cancelled bookings');
    try {
      emit(state.copyWith(status: () => BookingStatus.loading));
      final cancelled = await _repository.getCancelledBookingsApi();
      emit(state.copyWith(
        status: () => BookingStatus.loaded,
        message: () => 'Cancelled bookings fetched',
        cancelledBookings: () => cancelled,
      ));
    } catch (e) {
      _log.e('BookingBloc::_onFetchCancelledBookings::Error: $e');
      emit(state.copyWith(
        status: () => BookingStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onCancelBooking(
    CancelBookingEvent event,
    Emitter<BookingState> emit,
  ) async {
    _log.d('BookingBloc::_onCancelBooking::Cancelling booking: ${event.bookingId}');
    final updatedCancelling = Set<int>.from(state.cancellingBookingIds)..add(event.bookingId);
    emit(state.copyWith(cancellingBookingIds: () => updatedCancelling));

    try {
      final resp = await _repository.cancelBookingApi(event.bookingId);
      final nextCancelling = Set<int>.from(state.cancellingBookingIds)..remove(event.bookingId);

      if (resp != null && resp['success'] == true) {
        // Refresh upcoming and cancelled lists
        final upcoming = await _repository.getUpcomingBookingsApi();
        final cancelled = await _repository.getCancelledBookingsApi();

        emit(state.copyWith(
          status: () => BookingStatus.success,
          message: () => 'Booking cancelled successfully',
          upcomingBookings: () => upcoming,
          cancelledBookings: () => cancelled,
          cancellingBookingIds: () => nextCancelling,
        ));
      } else {
        emit(state.copyWith(
          status: () => BookingStatus.failure,
          message: () => resp?['message']?.toString() ?? 'Failed to cancel booking',
          cancellingBookingIds: () => nextCancelling,
        ));
      }
    } catch (e) {
      _log.e('BookingBloc::_onCancelBooking::Error: $e');
      final nextCancelling = Set<int>.from(state.cancellingBookingIds)..remove(event.bookingId);
      emit(state.copyWith(
        status: () => BookingStatus.failure,
        message: () => e.toString(),
        cancellingBookingIds: () => nextCancelling,
      ));
    }
  }
}
