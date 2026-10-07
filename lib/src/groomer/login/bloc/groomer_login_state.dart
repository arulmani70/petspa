part of 'groomer_login_bloc.dart';

enum GroomerLoginStatus { initial, loading, success, failure }

class GroomerLoginState extends Equatable {
  final GroomerLoginStatus status;
  final GroomerLoginResponse? loginResponse;
  final String? errorMessage;

  const GroomerLoginState({
    required this.status,
    this.loginResponse,
    this.errorMessage,
  });

  static const initial = GroomerLoginState(
    status: GroomerLoginStatus.initial,
  );

  GroomerLoginState copyWith({
    GroomerLoginStatus Function()? status,
    GroomerLoginResponse? Function()? loginResponse,
    String? Function()? errorMessage,
  }) {
    return GroomerLoginState(
      status: status != null ? status() : this.status,
      loginResponse: loginResponse != null ? loginResponse() : this.loginResponse,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        loginResponse,
        errorMessage,
      ];
}
