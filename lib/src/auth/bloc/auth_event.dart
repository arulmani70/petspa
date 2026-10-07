part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class LoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const LoginSubmitted({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class RegisterSubmitted extends AuthEvent {
  final String name;
  final String email;
  final String phone;
  final String password;

  const RegisterSubmitted({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  @override
  List<Object> get props => [name, email, phone, password];
}

class SendOtpSubmitted extends AuthEvent {
  final String email;

  const SendOtpSubmitted({required this.email});

  @override
  List<Object> get props => [email];
}

class VerifyOtpSubmitted extends AuthEvent {
  final String code;

  const VerifyOtpSubmitted({required this.code});

  @override
  List<Object> get props => [code];
}

class ResetPasswordSubmitted extends AuthEvent {
  final String email;
  final String code;
  final String newPassword;

  const ResetPasswordSubmitted({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  @override
  List<Object> get props => [email, code, newPassword];
}

class ForgotPasswordSubmitted extends AuthEvent {
  final String email;

  const ForgotPasswordSubmitted({required this.email});

  @override
  List<Object> get props => [email];
}

class LogoutSubmitted extends AuthEvent {
  const LogoutSubmitted();
}

class DeleteAccountSubmitted extends AuthEvent {
  const DeleteAccountSubmitted();
}

