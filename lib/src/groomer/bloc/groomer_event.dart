part of 'groomer_bloc.dart';

sealed class GroomerEvent extends Equatable {
  const GroomerEvent();

  @override
  List<Object?> get props => [];
}

class GroomerLoginEvent extends GroomerEvent {
  final String email;
  final String password;

  const GroomerLoginEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class GroomerSetupAccountEvent extends GroomerEvent {
  final String tempLoginId;
  final String tempPassword;
  final String email;
  final String password;
  final String confirmPassword;

  const GroomerSetupAccountEvent({
    required this.tempLoginId,
    required this.tempPassword,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [
        tempLoginId,
        tempPassword,
        email,
        password,
        confirmPassword,
      ];
}

class GroomerFetchAllDataEvent extends GroomerEvent {
  const GroomerFetchAllDataEvent();
}

class GroomerFetchProfileEvent extends GroomerEvent {
  const GroomerFetchProfileEvent();
}

class GroomerUpdateProfileEvent extends GroomerEvent {
  final String? firstName;
  final String? lastName;
  final String? mobile;
  final bool? multiBookingEnabled;
  final int? slotBookingLimit;

  const GroomerUpdateProfileEvent({
    this.firstName,
    this.lastName,
    this.mobile,
    this.multiBookingEnabled,
    this.slotBookingLimit,
  });

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        mobile,
        multiBookingEnabled,
        slotBookingLimit,
      ];
}

class GroomerFetchBookingsEvent extends GroomerEvent {
  const GroomerFetchBookingsEvent();
}

class GroomerApproveBookingEvent extends GroomerEvent {
  final int bookingId;

  const GroomerApproveBookingEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class GroomerRejectBookingEvent extends GroomerEvent {
  final int bookingId;

  const GroomerRejectBookingEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class GroomerStartBookingEvent extends GroomerEvent {
  final int bookingId;

  const GroomerStartBookingEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class GroomerCompleteBookingEvent extends GroomerEvent {
  final int bookingId;

  const GroomerCompleteBookingEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class GroomerApproveCancellationEvent extends GroomerEvent {
  final int bookingId;

  const GroomerApproveCancellationEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class GroomerRejectCancellationEvent extends GroomerEvent {
  final int bookingId;

  const GroomerRejectCancellationEvent(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class GroomerSelectDateEvent extends GroomerEvent {
  final DateTime date;

  const GroomerSelectDateEvent(this.date);

  @override
  List<Object?> get props => [date];
}

class GroomerSwitchTabEvent extends GroomerEvent {
  final int tabIndex;

  const GroomerSwitchTabEvent(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}

class GroomerMarkNotificationReadEvent extends GroomerEvent {
  final int notificationId;

  const GroomerMarkNotificationReadEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class GroomerMarkAllNotificationsReadEvent extends GroomerEvent {
  const GroomerMarkAllNotificationsReadEvent();
}

class GroomerLogoutEvent extends GroomerEvent {
  const GroomerLogoutEvent();
}

class GroomerCreateBookingForUserEvent extends GroomerEvent {
  final int userId;
  final int petId;
  final int serviceId;
  final int? packageId;
  final List<int>? addOnIds;
  final int? groomerId;
  final String bookingDate;
  final String startTime;
  final String endTime;

  const GroomerCreateBookingForUserEvent({
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
