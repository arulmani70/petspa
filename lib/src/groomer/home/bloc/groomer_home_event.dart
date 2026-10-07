part of 'groomer_home_bloc.dart';

sealed class GroomerHomeEvent extends Equatable {
  const GroomerHomeEvent();

  @override
  List<Object?> get props => [];
}

final class GroomerHomeFetchAllDataEvent extends GroomerHomeEvent {
  const GroomerHomeFetchAllDataEvent();
}

final class GroomerHomeFetchProfileEvent extends GroomerHomeEvent {
  const GroomerHomeFetchProfileEvent();
}

final class GroomerHomeUpdateProfileEvent extends GroomerHomeEvent {
  final String? firstName;
  final String? lastName;
  final String? mobile;
  final String? highlights;
  final bool? multiBookingEnabled;
  final int? slotBookingLimit;

  const GroomerHomeUpdateProfileEvent({
    this.firstName,
    this.lastName,
    this.mobile,
    this.highlights,
    this.multiBookingEnabled,
    this.slotBookingLimit,
  });

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        mobile,
        highlights,
        multiBookingEnabled,
        slotBookingLimit,
      ];
}

final class GroomerHomeApproveBookingEvent extends GroomerHomeEvent {
  final int bookingId;

  const GroomerHomeApproveBookingEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

final class GroomerHomeRejectBookingEvent extends GroomerHomeEvent {
  final int bookingId;

  const GroomerHomeRejectBookingEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

final class GroomerHomeStartBookingEvent extends GroomerHomeEvent {
  final int bookingId;

  const GroomerHomeStartBookingEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

final class GroomerHomeCompleteBookingEvent extends GroomerHomeEvent {
  final int bookingId;

  const GroomerHomeCompleteBookingEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

final class GroomerHomeApproveCancellationEvent extends GroomerHomeEvent {
  final int bookingId;

  const GroomerHomeApproveCancellationEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

final class GroomerHomeRejectCancellationEvent extends GroomerHomeEvent {
  final int bookingId;

  const GroomerHomeRejectCancellationEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

final class GroomerHomeSelectDateEvent extends GroomerHomeEvent {
  final DateTime date;

  const GroomerHomeSelectDateEvent(this.date);

  @override
  List<Object?> get props => [date];
}

final class GroomerHomeSwitchTabEvent extends GroomerHomeEvent {
  final int tabIndex;

  const GroomerHomeSwitchTabEvent(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}

final class GroomerHomeMarkNotificationReadEvent extends GroomerHomeEvent {
  final int notificationId;

  const GroomerHomeMarkNotificationReadEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

final class GroomerHomeMarkAllNotificationsReadEvent extends GroomerHomeEvent {
  const GroomerHomeMarkAllNotificationsReadEvent();
}

final class GroomerHomeLogoutEvent extends GroomerHomeEvent {
  const GroomerHomeLogoutEvent();
}

final class GroomerHomeConnectSocketEvent extends GroomerHomeEvent {
  final String? token;
  final String? serverUrl;

  const GroomerHomeConnectSocketEvent({this.token, this.serverUrl});

  @override
  List<Object?> get props => [token, serverUrl];
}

final class GroomerHomeRealtimeNotificationReceivedEvent extends GroomerHomeEvent {
  final AppNotification notification;

  const GroomerHomeRealtimeNotificationReceivedEvent(this.notification);

  @override
  List<Object?> get props => [notification];
}

final class GroomerHomeSocketConnectionChangedEvent extends GroomerHomeEvent {
  final bool isConnected;

  const GroomerHomeSocketConnectionChangedEvent(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}

final class GroomerHomeSaveScheduleEvent extends GroomerHomeEvent {
  final List<StoreServiceHour>? serviceHours;
  final List<GroomerWorkingHour>? groomerHours;

  const GroomerHomeSaveScheduleEvent({
    this.serviceHours,
    this.groomerHours,
  });

  @override
  List<Object?> get props => [serviceHours, groomerHours];
}

final class GroomerHomeCreateBookingForUserEvent extends GroomerHomeEvent {
  final int userId;
  final int petId;
  final int serviceId;
  final int? packageId;
  final List<int>? addOnIds;
  final int? groomerId;
  final String bookingDate;
  final String startTime;
  final String endTime;

  const GroomerHomeCreateBookingForUserEvent({
    required this.userId,
    required this.petId,
    required this.serviceId,
    this.packageId,
    this.addOnIds,
    this.groomerId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [
        userId,
        petId,
        serviceId,
        packageId,
        addOnIds,
        groomerId,
        bookingDate,
        startTime,
        endTime,
      ];
}

final class GroomerHomeSearchCustomersEvent extends GroomerHomeEvent {
  final String? query;

  const GroomerHomeSearchCustomersEvent({this.query});

  @override
  List<Object?> get props => [query];
}

final class GroomerHomeGetCustomerPetsEvent extends GroomerHomeEvent {
  final int userId;

  const GroomerHomeGetCustomerPetsEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

final class GroomerHomeGetSalonGroomersEvent extends GroomerHomeEvent {
  const GroomerHomeGetSalonGroomersEvent();
}

final class GroomerHomeGetBookingServicesEvent extends GroomerHomeEvent {
  const GroomerHomeGetBookingServicesEvent();
}

final class GroomerHomeCheckAvailabilityEvent extends GroomerHomeEvent {
  final DateTime date;
  final int? groomerId;
  final int? serviceId;
  final int? packageId;
  final List<int>? addOnIds;

  const GroomerHomeCheckAvailabilityEvent({
    required this.date,
    this.groomerId,
    this.serviceId,
    this.packageId,
    this.addOnIds,
  });

  @override
  List<Object?> get props => [date, groomerId, serviceId, packageId, addOnIds];
}

final class GroomerHomeResetBookingDialogEvent extends GroomerHomeEvent {
  const GroomerHomeResetBookingDialogEvent();
}


