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

  const SaveProfileEvent({
    required this.name,
    required this.mobile,
    this.photoPath,
  });

  @override
  List<Object?> get props => [name, mobile, photoPath];
}

class ChangePasswordEvent extends ProfileEvent {
  final String newPassword;

  const ChangePasswordEvent(this.newPassword);

  @override
  List<Object?> get props => [newPassword];
}
