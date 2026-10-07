part of 'booking_bloc.dart';

sealed class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

class InitializeBookings extends BookingEvent {
  const InitializeBookings();
}

class FetchUpcomingBookings extends BookingEvent {
  final bool forceRefresh;

  const FetchUpcomingBookings({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class FetchPastBookings extends BookingEvent {
  final bool forceRefresh;

  const FetchPastBookings({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class FetchCancelledBookings extends BookingEvent {
  final bool forceRefresh;

  const FetchCancelledBookings({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class CancelBookingEvent extends BookingEvent {
  final int bookingId;
  final String? cancellationReason;

  const CancelBookingEvent({required this.bookingId, this.cancellationReason});

  @override
  List<Object?> get props => [bookingId, cancellationReason];
}
