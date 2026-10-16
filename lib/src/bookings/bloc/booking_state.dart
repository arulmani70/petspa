part of 'booking_bloc.dart';

enum BookingStatus { initial, loading, loaded, success, failure }

class BookingState extends Equatable {
  final BookingStatus status;
  final String message;
  final List<Map<String, dynamic>> upcomingBookings;
  final List<Map<String, dynamic>> pastBookings;
  final List<Map<String, dynamic>> cancelledBookings;
  final Set<int> cancellingBookingIds;
  final Set<int> confirmingTipBookingIds;
  final Map<int, double> confirmedTips;

  const BookingState({
    required this.status,
    required this.message,
    required this.upcomingBookings,
    required this.pastBookings,
    required this.cancelledBookings,
    required this.cancellingBookingIds,
    this.confirmingTipBookingIds = const {},
    this.confirmedTips = const {},
  });

  static const BookingState initial = BookingState(
    status: BookingStatus.initial,
    message: '',
    upcomingBookings: [],
    pastBookings: [],
    cancelledBookings: [],
    cancellingBookingIds: {},
    confirmingTipBookingIds: {},
    confirmedTips: {},
  );

  BookingState copyWith({
    BookingStatus Function()? status,
    String Function()? message,
    List<Map<String, dynamic>> Function()? upcomingBookings,
    List<Map<String, dynamic>> Function()? pastBookings,
    List<Map<String, dynamic>> Function()? cancelledBookings,
    Set<int> Function()? cancellingBookingIds,
    Set<int> Function()? confirmingTipBookingIds,
    Map<int, double> Function()? confirmedTips,
  }) {
    return BookingState(
      status: status != null ? status() : this.status,
      message: message != null ? message() : this.message,
      upcomingBookings: upcomingBookings != null ? upcomingBookings() : this.upcomingBookings,
      pastBookings: pastBookings != null ? pastBookings() : this.pastBookings,
      cancelledBookings: cancelledBookings != null ? cancelledBookings() : this.cancelledBookings,
      cancellingBookingIds: cancellingBookingIds != null ? cancellingBookingIds() : this.cancellingBookingIds,
      confirmingTipBookingIds: confirmingTipBookingIds != null ? confirmingTipBookingIds() : this.confirmingTipBookingIds,
      confirmedTips: confirmedTips != null ? confirmedTips() : this.confirmedTips,
    );
  }

  @override
  List<Object?> get props => [
        status,
        message,
        upcomingBookings,
        pastBookings,
        cancelledBookings,
        cancellingBookingIds,
        confirmingTipBookingIds,
        confirmedTips,
      ];
}
