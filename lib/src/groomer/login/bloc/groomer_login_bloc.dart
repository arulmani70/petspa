import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/models/groomer_login_response.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/repo/groomer_login_repository.dart';

part 'groomer_login_event.dart';
part 'groomer_login_state.dart';

class GroomerLoginBloc extends Bloc<GroomerLoginEvent, GroomerLoginState> {
  final GroomerLoginRepository repository;
  final Logger log = Logger();

  GroomerLoginBloc({required this.repository}) : super(GroomerLoginState.initial) {
    on<GroomerLoginInitialEvent>(_onInitial);
    on<GroomerLoginSubmittedEvent>(_onLoginSubmitted);
    on<GroomerLoginLogoutEvent>(_onLogout);
  }

  void _onInitial(
    GroomerLoginInitialEvent event,
    Emitter<GroomerLoginState> emit,
  ) {
    emit(GroomerLoginState.initial);
  }

  Future<void> _onLoginSubmitted(
    GroomerLoginSubmittedEvent event,
    Emitter<GroomerLoginState> emit,
  ) async {
    emit(state.copyWith(
      status: () => GroomerLoginStatus.loading,
      errorMessage: () => null,
    ));

    try {
      final response = await repository.login(
        email: event.email,
        password: event.password,
      );

      if (response != null) {
        emit(state.copyWith(
          status: () => GroomerLoginStatus.success,
          loginResponse: () => response,
        ));
      } else {
        emit(state.copyWith(
          status: () => GroomerLoginStatus.failure,
          errorMessage: () => 'Invalid response from server. Please try again.',
        ));
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception:', '').trim();
      emit(state.copyWith(
        status: () => GroomerLoginStatus.failure,
        errorMessage: () => err.isNotEmpty ? err : 'Invalid credentials. Please try again.',
      ));
    }
  }

  Future<void> _onLogout(
    GroomerLoginLogoutEvent event,
    Emitter<GroomerLoginState> emit,
  ) async {
    await repository.logout();
    emit(GroomerLoginState.initial);
    Routes.redirectToLogin(isGroomer: true);
  }
}
