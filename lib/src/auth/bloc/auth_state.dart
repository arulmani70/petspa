part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, otpSent, otpVerified }

class AuthState extends Equatable {
  final AuthStatus status;
  final String message;
  final Map<String, dynamic>? user;
  final String? userType;
  final bool mustChangePassword;
  final String? otpSentTo;
  final bool otpVerified;

  const AuthState({
    required this.status,
    required this.message,
    this.user,
    this.userType,
    this.mustChangePassword = false,
    this.otpSentTo,
    this.otpVerified = false,
  });

  static const AuthState initial = AuthState(status: AuthStatus.initial, message: '');

  AuthState copyWith({
    AuthStatus Function()? status,
    String Function()? message,
    Map<String, dynamic>? Function()? user,
    String? Function()? userType,
    bool Function()? mustChangePassword,
    String? Function()? otpSentTo,
    bool Function()? otpVerified,
  }) {
    return AuthState(
      status: status != null ? status() : this.status,
      message: message != null ? message() : this.message,
      user: user != null ? user() : this.user,
      userType: userType != null ? userType() : this.userType,
      mustChangePassword: mustChangePassword != null ? mustChangePassword() : this.mustChangePassword,
      otpSentTo: otpSentTo != null ? otpSentTo() : this.otpSentTo,
      otpVerified: otpVerified != null ? otpVerified() : this.otpVerified,
    );
  }

  @override
  List<Object?> get props => [
        status,
        message,
        otpVerified,
        user ?? {},
        userType,
        mustChangePassword,
        otpSentTo ?? '',
      ];
}
