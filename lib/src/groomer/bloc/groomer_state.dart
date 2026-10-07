part of 'groomer_bloc.dart';

enum GroomerStatus { initial, loading, loaded, success, failure }

class GroomerState extends Equatable {
  final GroomerStatus status;
  final GroomerUser? groomer;
  final List<GroomerBooking> upcomingBookings;
  final List<GroomerBooking> pendingBookings;
  final List<GroomerBooking> pastBookings;
  final List<GroomerBooking> cancelledBookings;
  final List<GroomerBooking> cancellationRequests;
  final List<StoreServiceHour> serviceHours;
  final List<StoreHoliday> holidays;
  final List<Map<String, dynamic>> notifications;
  final DateTime selectedDate;
  final int currentTabIndex;
  final String message;

  const GroomerState({
    required this.status,
    this.groomer,
    this.upcomingBookings = const [],
    this.pendingBookings = const [],
    this.pastBookings = const [],
    this.cancelledBookings = const [],
    this.cancellationRequests = const [],
    this.serviceHours = const [],
    this.holidays = const [],
    this.notifications = const [],
    required this.selectedDate,
    this.currentTabIndex = 0,
    this.message = '',
  });

  static final GroomerState initial = GroomerState(
    status: GroomerStatus.initial,
    selectedDate: DateTime.now(),
    message: '',
  );

  GroomerState copyWith({
    GroomerStatus Function()? status,
    GroomerUser? Function()? groomer,
    List<GroomerBooking> Function()? upcomingBookings,
    List<GroomerBooking> Function()? pendingBookings,
    List<GroomerBooking> Function()? pastBookings,
    List<GroomerBooking> Function()? cancelledBookings,
    List<GroomerBooking> Function()? cancellationRequests,
    List<StoreServiceHour> Function()? serviceHours,
    List<StoreHoliday> Function()? holidays,
    List<Map<String, dynamic>> Function()? notifications,
    DateTime Function()? selectedDate,
    int Function()? currentTabIndex,
    String Function()? message,
  }) {
    return GroomerState(
      status: status != null ? status() : this.status,
      groomer: groomer != null ? groomer() : this.groomer,
      upcomingBookings: upcomingBookings != null ? upcomingBookings() : this.upcomingBookings,
      pendingBookings: pendingBookings != null ? pendingBookings() : this.pendingBookings,
      pastBookings: pastBookings != null ? pastBookings() : this.pastBookings,
      cancelledBookings: cancelledBookings != null ? cancelledBookings() : this.cancelledBookings,
      cancellationRequests: cancellationRequests != null ? cancellationRequests() : this.cancellationRequests,
      serviceHours: serviceHours != null ? serviceHours() : this.serviceHours,
      holidays: holidays != null ? holidays() : this.holidays,
      notifications: notifications != null ? notifications() : this.notifications,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      currentTabIndex: currentTabIndex != null ? currentTabIndex() : this.currentTabIndex,
      message: message != null ? message() : this.message,
    );
  }

  @override
  List<Object?> get props => [
        status,
        groomer,
        upcomingBookings,
        pendingBookings,
        pastBookings,
        cancelledBookings,
        cancellationRequests,
        serviceHours,
        holidays,
        notifications,
        selectedDate,
        currentTabIndex,
        message,
      ];
}
