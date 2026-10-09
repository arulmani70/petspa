import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository repository})
      : _repository = repository,
        super(AuthState.initial) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<RegisterSubmitted>(_onRegisterSubmitted);
    on<SendOtpSubmitted>(_onSendOtpSubmitted);
    on<VerifyOtpSubmitted>(_onVerifyOtpSubmitted);
    on<ForgotPasswordSubmitted>(_onForgotPasswordSubmitted);
    on<ResetPasswordSubmitted>(_onResetPasswordSubmitted);
    on<LogoutSubmitted>(_onLogoutSubmitted);
    on<DeleteAccountSubmitted>(_onDeleteAccountSubmitted);
  }

  final AuthRepository _repository;
  final _log = Logger();

  Map<String, dynamic>? _pendingUser;

  Future<void> _onForgotPasswordSubmitted(ForgotPasswordSubmitted event, Emitter<AuthState> emit) async {
    _log.d("AuthBloc::_onForgotPasswordSubmitted::Forgot password for: ${event.email}");
    try {
      emit(state.copyWith(status: () => AuthStatus.loading));
      final exists = await _repository.forgotPasswordCheck(event.email);
      if (!exists) {
        emit(state.copyWith(
          status: () => AuthStatus.unauthenticated,
          message: () => 'No account found with this email address.',
        ));
        return;
      }

      emit(state.copyWith(
        status: () => AuthStatus.otpSent,
        message: () => 'OTP sent to your email',
        otpSentTo: () => event.email,
      ));
    } catch (e) {
      _log.e("AuthBloc::_onForgotPasswordSubmitted::Error: $e");
      emit(state.copyWith(status: () => AuthStatus.unauthenticated, message: () => e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoginSubmitted(LoginSubmitted event, Emitter<AuthState> emit) async {
    _log.d("AuthBloc::_onLoginSubmitted::Logging in: ${event.email}");
    try {
      emit(state.copyWith(status: () => AuthStatus.loading));
      final result = await _repository.login(email: event.email, password: event.password);
      final userType = result['userType']?.toString().toLowerCase() ?? 'customer';
      final mustChangePassword = result['mustChangePassword'] == true;
      final userPayload = (result['user'] is Map<String, dynamic>)
          ? result['user'] as Map<String, dynamic>
          : (result['groomer'] is Map<String, dynamic>
              ? result['groomer'] as Map<String, dynamic>
              : result);

      emit(state.copyWith(
        status: () => AuthStatus.authenticated,
        message: () => 'Login successful',
        user: () => userPayload,
        userType: () => userType,
        mustChangePassword: () => mustChangePassword,
      ));
    } catch (e) {
      _log.e("AuthBloc::_onLoginSubmitted::Error: $e");
      emit(state.copyWith(
        status: () => AuthStatus.unauthenticated,
        message: () => e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onRegisterSubmitted(RegisterSubmitted event, Emitter<AuthState> emit) async {
    _log.d("AuthBloc::_onRegisterSubmitted::Registering: ${event.email}");
    try {
      emit(state.copyWith(status: () => AuthStatus.loading));
      final user = await _repository.register(
        name: event.name,
        email: event.email,
        phone: event.phone,
        password: event.password,
      );
      _pendingUser = user;

      emit(state.copyWith(
        status: () => AuthStatus.otpSent,
        message: () => 'OTP sent to your email',
        user: () => user,
        otpSentTo: () => event.email,
      ));
    } catch (e) {
      _log.e("AuthBloc::_onRegisterSubmitted::Error: $e");
      emit(state.copyWith(status: () => AuthStatus.unauthenticated, message: () => e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onSendOtpSubmitted(SendOtpSubmitted event, Emitter<AuthState> emit) async {
    _log.d("AuthBloc::_onSendOtpSubmitted::Sending OTP to: ${event.email}");
    try {
      emit(state.copyWith(status: () => AuthStatus.loading));
      final otp = await _repository.sendOtp(event.email);
      _log.d("AuthBloc::_onSendOtpSubmitted::Demo OTP: $otp");
      emit(state.copyWith(
        status: () => AuthStatus.otpSent,
        message: () => 'OTP sent to your email',
        otpSentTo: () => event.email,
      ));
    } catch (e) {
      _log.e("AuthBloc::_onSendOtpSubmitted::Error: $e");
      emit(state.copyWith(status: () => AuthStatus.unauthenticated, message: () => e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onVerifyOtpSubmitted(VerifyOtpSubmitted event, Emitter<AuthState> emit) async {
    _log.d("AuthBloc::_onVerifyOtpSubmitted::Verifying OTP");
    try {
      emit(state.copyWith(status: () => AuthStatus.loading));
      final valid = await _repository.verifyOtp(event.code);

      if (!valid) {
        emit(state.copyWith(
          status: () => AuthStatus.otpSent,
          message: () => 'Invalid or expired OTP. Please try again.',
        ));
        return;
      }

      if (_pendingUser != null) {
        await _repository.completeRegistration(_pendingUser!);
      }

      emit(state.copyWith(
        status: () => AuthStatus.otpVerified,
        message: () => 'OTP verified successfully',
        otpVerified: () => true,
      ));
    } catch (e) {
      _log.e("AuthBloc::_onVerifyOtpSubmitted::Error: $e");
      emit(state.copyWith(status: () => AuthStatus.otpSent, message: () => e.toString()));
    }
  }

  Future<void> _onResetPasswordSubmitted(ResetPasswordSubmitted event, Emitter<AuthState> emit) async {
    _log.d("AuthBloc::_onResetPasswordSubmitted::Resetting password");
    try {
      emit(state.copyWith(status: () => AuthStatus.loading));
      await _repository.resetPassword(
        email          : event.email,
        otp            : event.code,
        password       : event.newPassword,
        confirmPassword: event.newPassword,
      );
      emit(state.copyWith(
        status : () => AuthStatus.unauthenticated,
        message: () => 'Password updated. Please log in.',
      ));
    } catch (e) {
      _log.e("AuthBloc::_onResetPasswordSubmitted::Error: $e");
      emit(state.copyWith(status: () => AuthStatus.unauthenticated, message: () => e.toString()));
    }
  }

  Future<void> _onLogoutSubmitted(LogoutSubmitted event, Emitter<AuthState> emit) async {
    _log.d("AuthBloc::_onLogoutSubmitted::Logging out");
    try {
      emit(state.copyWith(status: () => AuthStatus.loading));
      await _repository.logout();
      emit(state.copyWith(status: () => AuthStatus.unauthenticated, message: () => 'Logged out'));
    } catch (e) {
      _log.e("AuthBloc::_onLogoutSubmitted::Error: $e");
      emit(state.copyWith(status: () => AuthStatus.unauthenticated, message: () => e.toString()));
    }
  }

  Future<void> _onDeleteAccountSubmitted(DeleteAccountSubmitted event, Emitter<AuthState> emit) async {
    _log.d("AuthBloc::_onDeleteAccountSubmitted::Deleting account");
    try {
      emit(state.copyWith(status: () => AuthStatus.loading));
      await _repository.deleteAccount(
        password: event.password,
        confirm: event.confirm,
      );
      emit(state.copyWith(
        status: () => AuthStatus.unauthenticated,
        user: () => null,
        message: () => 'Account deleted successfully',
      ));
    } catch (e) {
      _log.e("AuthBloc::_onDeleteAccountSubmitted::Error: $e");
      emit(state.copyWith(
        status: () => AuthStatus.authenticated,
        message: () => e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }
}
