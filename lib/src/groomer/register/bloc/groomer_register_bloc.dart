import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/repo/groomer_register_repository.dart';

part 'groomer_register_event.dart';
part 'groomer_register_state.dart';

class GroomerRegisterBloc extends Bloc<GroomerRegisterEvent, GroomerRegisterState> {
  final GroomerRegisterRepository repository;
  final Logger log = Logger();

  GroomerRegisterBloc({required this.repository}) : super(GroomerRegisterState.initial) {
    on<GroomerRegisterInitialEvent>(_onInitial);
    on<GroomerRegisterSetupAccountEvent>(_onSetupAccount);
    on<GroomerRegisterUpdateProfileEvent>(_onUpdateProfile);
  }

  void _onInitial(
    GroomerRegisterInitialEvent event,
    Emitter<GroomerRegisterState> emit,
  ) {
    emit(GroomerRegisterState.initial);
  }

  Future<void> _onSetupAccount(
    GroomerRegisterSetupAccountEvent event,
    Emitter<GroomerRegisterState> emit,
  ) async {
    emit(state.copyWith(
      status: () => GroomerRegisterStatus.loading,
      errorMessage: () => null,
    ));

    try {
      final success = await repository.setupAccount(
        tempLoginId: event.tempLoginId,
        tempPassword: event.tempPassword,
        email: event.email,
        password: event.password,
        confirmPassword: event.confirmPassword,
      );

      if (success != null) {
        await ServicesLocator.sessionService.clearTempGroomerCredentials();
        if ((event.fullName != null && event.fullName!.isNotEmpty) ||
            (event.phone != null && event.phone!.isNotEmpty) ||
            (event.photoPath != null && event.photoPath!.isNotEmpty)) {
          final names = (event.fullName ?? '').split(' ');
          final firstName = names.isNotEmpty ? names.first : '';
          final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
          await repository.updateProfile(
            firstName: firstName.isNotEmpty ? firstName : null,
            lastName: lastName.isNotEmpty ? lastName : null,
            mobile: event.phone,
            photoPath: event.photoPath,
          );
        }

        emit(state.copyWith(
          status: () => GroomerRegisterStatus.success,
          successMessage: () => 'Account setup completed successfully.',
        ));
      } else {
        emit(state.copyWith(
          status: () => GroomerRegisterStatus.failure,
          errorMessage: () => 'Failed to complete setup. Please try again.',
        ));
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception:', '').trim();
      emit(state.copyWith(
        status: () => GroomerRegisterStatus.failure,
        errorMessage: () => err.isNotEmpty ? err : 'Setup failed. Please try again.',
      ));
    }
  }

  Future<void> _onUpdateProfile(
    GroomerRegisterUpdateProfileEvent event,
    Emitter<GroomerRegisterState> emit,
  ) async {
    emit(state.copyWith(
      status: () => GroomerRegisterStatus.loading,
      errorMessage: () => null,
    ));

    try {
      final updated = await repository.updateProfile(
        firstName: event.firstName,
        lastName: event.lastName,
        mobile: event.mobile,
        highlights: event.highlights,
        multiBookingEnabled: event.multiBookingEnabled,
        slotBookingLimit: event.slotBookingLimit,
        photoPath: event.photoPath,
      );

      if (updated != null) {
        emit(state.copyWith(
          status: () => GroomerRegisterStatus.success,
          successMessage: () => 'Profile updated successfully.',
        ));
      } else {
        emit(state.copyWith(
          status: () => GroomerRegisterStatus.failure,
          errorMessage: () => 'Failed to update profile.',
        ));
      }
    } catch (e) {
      final err = e.toString().replaceAll('Exception:', '').trim();
      emit(state.copyWith(
        status: () => GroomerRegisterStatus.failure,
        errorMessage: () => err.isNotEmpty ? err : 'Failed to update profile.',
      ));
    }
  }
}
