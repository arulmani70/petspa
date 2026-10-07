part of 'groomer_register_bloc.dart';

enum GroomerRegisterStatus { initial, loading, success, failure }

class GroomerRegisterState extends Equatable {
  final GroomerRegisterStatus status;
  final String? errorMessage;
  final String? successMessage;

  const GroomerRegisterState({
    required this.status,
    this.errorMessage,
    this.successMessage,
  });

  static const initial = GroomerRegisterState(
    status: GroomerRegisterStatus.initial,
  );

  GroomerRegisterState copyWith({
    GroomerRegisterStatus Function()? status,
    String? Function()? errorMessage,
    String? Function()? successMessage,
  }) {
    return GroomerRegisterState(
      status: status != null ? status() : this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      successMessage: successMessage != null ? successMessage() : this.successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        successMessage,
      ];
}
