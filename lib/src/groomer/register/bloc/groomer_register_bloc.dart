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
        final trimmedFull = (event.fullName ?? '').trim();
        String? resolvedFirst = event.firstName?.trim();
        String? resolvedLast = event.lastName?.trim();

        if ((resolvedFirst == null || resolvedFirst.isEmpty) &&
            (resolvedLast == null || resolvedLast.isEmpty) &&
            trimmedFull.isNotEmpty) {
          final names = trimmedFull.split(RegExp(r'\s+'));
          resolvedFirst = names.first;
          resolvedLast = names.length > 1 ? names.sublist(1).join(' ') : names.first;
        }

        if ((resolvedFirst != null && resolvedFirst.isNotEmpty) ||
            (resolvedLast != null && resolvedLast.isNotEmpty) ||
            (event.phone != null && event.phone!.isNotEmpty) ||
            (event.photoPath != null && event.photoPath!.isNotEmpty)) {
          await repository.updateProfile(
            firstName: (resolvedFirst != null && resolvedFirst.isNotEmpty) ? resolvedFirst : null,
            lastName: (resolvedLast != null && resolvedLast.isNotEmpty) ? resolvedLast : null,
            mobile: event.phone,
            photoPath: event.photoPath,
          );
        }

        // Fetch fresh profile and persist
        await repository.getProfile();

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
