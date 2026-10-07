part of 'groomer_login_bloc.dart';

sealed class GroomerLoginEvent extends Equatable {
  const GroomerLoginEvent();

  @override
  List<Object?> get props => [];
}

final class GroomerLoginInitialEvent extends GroomerLoginEvent {
  const GroomerLoginInitialEvent();
}

final class GroomerLoginSubmittedEvent extends GroomerLoginEvent {
  final String email;
  final String password;

  const GroomerLoginSubmittedEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

final class GroomerLoginLogoutEvent extends GroomerLoginEvent {
  const GroomerLoginLogoutEvent();
}
