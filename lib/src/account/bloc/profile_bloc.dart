import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required AuthRepository repository})
      : _repository = repository,
        super(ProfileState.initial) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<SaveProfileEvent>(_onSaveProfile);
    on<ChangePasswordEvent>(_onChangePassword);
  }

  final AuthRepository _repository;
  final _log = Logger();

  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    _log.d('ProfileBloc::_onLoadProfile::Loading profile');
    try {
      emit(state.copyWith(status: () => ProfileStatus.loading));
      final data = await _repository.getProfile();
      final verified = data['emailVerified'] == true;
      emit(state.copyWith(
        status: () => ProfileStatus.loaded,
        message: () => 'Profile loaded',
        profileData: () => data,
        emailVerified: () => verified,
      ));
    } catch (e) {
      _log.e('ProfileBloc::_onLoadProfile::Error: $e');
      final user = ServicesLocator.sessionService.getSessionUser() ?? {};
      emit(state.copyWith(
        status: () => ProfileStatus.loaded,
        message: () => '',
        profileData: () => user,
      ));
    }
  }

  Future<void> _onSaveProfile(
    SaveProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    _log.d('ProfileBloc::_onSaveProfile::Saving profile name=${event.name} photoPath=${event.photoPath}');
    try {
      emit(state.copyWith(status: () => ProfileStatus.saving));
      final data = await _repository.updateProfilePut(
        name: event.name,
        mobile: event.mobile,
        photoPath: event.photoPath,
      );

      if (data.isNotEmpty) {
        final updated = Map<String, dynamic>.from(state.profileData)
          ..addAll(data)
          ..['name'] = event.name
          ..['mobile'] = event.mobile;
        if (event.photoPath != null && event.photoPath!.isNotEmpty) {
          final newPhoto = data['profilePicture'] ?? data['profilePictureUrl'] ?? data['photoUrl'] ?? data['avatar'] ?? event.photoPath;
          updated['profilePicture'] = newPhoto;
          updated['profilePictureUrl'] = newPhoto;
        }
        emit(state.copyWith(
          status: () => ProfileStatus.success,
          message: () => 'Profile updated successfully!',
          profileData: () => updated,
        ));
      } else {
        emit(state.copyWith(
          status: () => ProfileStatus.failure,
          message: () => 'Failed to save profile.',
        ));
      }
    } catch (e) {
      _log.e('ProfileBloc::_onSaveProfile::Error: $e');
      emit(state.copyWith(
        status: () => ProfileStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onChangePassword(
    ChangePasswordEvent event,
    Emitter<ProfileState> emit,
  ) async {
    _log.d('ProfileBloc::_onChangePassword::Changing password');
    try {
      emit(state.copyWith(status: () => ProfileStatus.saving));
      final email = state.profileData['email']?.toString() ??
          ServicesLocator.sessionService.getSessionUser()?['email']?.toString() ??
          '';
      final resp = await _repository.resetPassword(
        email: email,
        otp: event.otp,
        password: event.newPassword,
        confirmPassword: event.newPassword,
      );
      if (resp['success'] == true) {
        emit(state.copyWith(
          status: () => ProfileStatus.success,
          message: () => 'Password updated successfully.',
        ));
      } else {
        emit(state.copyWith(
          status: () => ProfileStatus.failure,
          message: () => 'Failed to update password.',
        ));
      }
    } catch (e) {
      _log.e('ProfileBloc::_onChangePassword::Error: $e');
      emit(state.copyWith(
        status: () => ProfileStatus.failure,
        message: () => e.toString(),
      ));
    }
  }
}
