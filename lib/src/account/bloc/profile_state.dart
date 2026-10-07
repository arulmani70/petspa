part of 'profile_bloc.dart';

enum ProfileStatus { initial, loading, loaded, saving, success, failure }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final String message;
  final Map<String, dynamic> profileData;
  final bool emailVerified;

  const ProfileState({
    required this.status,
    required this.message,
    required this.profileData,
    this.emailVerified = false,
  });

  static const ProfileState initial = ProfileState(
    status: ProfileStatus.initial,
    message: '',
    profileData: {},
    emailVerified: false,
  );

  ProfileState copyWith({
    ProfileStatus Function()? status,
    String Function()? message,
    Map<String, dynamic> Function()? profileData,
    bool Function()? emailVerified,
  }) {
    return ProfileState(
      status: status != null ? status() : this.status,
      message: message != null ? message() : this.message,
      profileData: profileData != null ? profileData() : this.profileData,
      emailVerified: emailVerified != null ? emailVerified() : this.emailVerified,
    );
  }

  @override
  List<Object?> get props => [status, message, profileData, emailVerified];
}
