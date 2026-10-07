part of 'groomer_register_bloc.dart';

sealed class GroomerRegisterEvent extends Equatable {
  const GroomerRegisterEvent();

  @override
  List<Object?> get props => [];
}

final class GroomerRegisterInitialEvent extends GroomerRegisterEvent {
  const GroomerRegisterInitialEvent();
}

final class GroomerRegisterSetupAccountEvent extends GroomerRegisterEvent {
  final String tempLoginId;
  final String tempPassword;
  final String email;
  final String password;
  final String confirmPassword;
  final String? fullName;
  final String? phone;
  final String? photoPath;

  const GroomerRegisterSetupAccountEvent({
    required this.tempLoginId,
    required this.tempPassword,
    required this.email,
    required this.password,
    required this.confirmPassword,
    this.fullName,
    this.phone,
    this.photoPath,
  });

  @override
  List<Object?> get props => [
        tempLoginId,
        tempPassword,
        email,
        password,
        confirmPassword,
        fullName,
        phone,
        photoPath,
      ];
}

final class GroomerRegisterUpdateProfileEvent extends GroomerRegisterEvent {
  final String? firstName;
  final String? lastName;
  final String? mobile;
  final String? highlights;
  final bool? multiBookingEnabled;
  final int? slotBookingLimit;
  final String? photoPath;

  const GroomerRegisterUpdateProfileEvent({
    this.firstName,
    this.lastName,
    this.mobile,
    this.highlights,
    this.multiBookingEnabled,
    this.slotBookingLimit,
    this.photoPath,
  });

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        mobile,
        highlights,
        multiBookingEnabled,
        slotBookingLimit,
        photoPath,
      ];
}
