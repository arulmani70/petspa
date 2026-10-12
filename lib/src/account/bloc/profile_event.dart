part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfileEvent extends ProfileEvent {
  const LoadProfileEvent();
}

class SaveProfileEvent extends ProfileEvent {
  final String name;
  final String mobile;
  final String? photoPath;
  final String? gender;

  const SaveProfileEvent({
    required this.name,
    required this.mobile,
    this.photoPath,
    this.gender,
  });

  @override
  List<Object?> get props => [name, mobile, photoPath, gender];
}

class ChangePasswordEvent extends ProfileEvent {
  final String newPassword;
  final String otp;

  const ChangePasswordEvent({
    required this.newPassword,
    required this.otp,
  });

  @override
  List<Object?> get props => [newPassword, otp];
}
