import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/content_model.dart';
import 'package:shear_heaven_pet_spa/src/account/models/store_contact_info_model.dart';
import 'package:shear_heaven_pet_spa/src/content/repo/content_repository.dart';

part 'content_event.dart';
part 'content_state.dart';

class ContentBloc extends Bloc<ContentEvent, ContentState> {
  ContentBloc({required ContentRepository repository})
      : _repository = repository,
        super(ContentState.initial) {
    on<FetchStoreContactInfo>(_onFetchStoreContactInfo);
    on<FetchAboutUsContent>(_onFetchAboutUsContent);
    on<FetchHelpSupportContent>(_onFetchHelpSupportContent);
    on<FetchPrivacyPolicyContent>(_onFetchPrivacyPolicyContent);
    on<FetchTermsConditionsContent>(_onFetchTermsConditionsContent);
    on<FetchAllCmsContent>(_onFetchAllCmsContent);
  }

  final ContentRepository _repository;
  final _log = Logger();

  Future<void> _onFetchStoreContactInfo(
    FetchStoreContactInfo event,
    Emitter<ContentState> emit,
  ) async {
    _log.d('ContentBloc::_onFetchStoreContactInfo::Fetching contact info');
    try {
      emit(state.copyWith(status: () => ContentStatus.loading));
      final info = await _repository.getStoreContactInfo();
      emit(state.copyWith(
        status: () => ContentStatus.loaded,
        message: () => 'Contact info fetched',
        contactInfo: () => info,
      ));
    } catch (e) {
      _log.e('ContentBloc::_onFetchStoreContactInfo::Error: $e');
      emit(state.copyWith(
        status: () => ContentStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchAboutUsContent(
    FetchAboutUsContent event,
    Emitter<ContentState> emit,
  ) async {
    _log.d('ContentBloc::_onFetchAboutUsContent::Fetching about us');
    try {
      emit(state.copyWith(status: () => ContentStatus.loading));
      final about = await _repository.getAboutUs();
      emit(state.copyWith(
        status: () => ContentStatus.loaded,
        message: () => 'About us fetched',
        aboutUs: () => about,
      ));
    } catch (e) {
      _log.e('ContentBloc::_onFetchAboutUsContent::Error: $e');
      emit(state.copyWith(
        status: () => ContentStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchHelpSupportContent(
    FetchHelpSupportContent event,
    Emitter<ContentState> emit,
  ) async {
    _log.d('ContentBloc::_onFetchHelpSupportContent::Fetching help & support');
    try {
      emit(state.copyWith(status: () => ContentStatus.loading));
      final help = await _repository.getHelpSupport();
      final contact = await _repository.getStoreContactInfo();
      emit(state.copyWith(
        status: () => ContentStatus.loaded,
        message: () => 'Help & support fetched',
        helpSupport: () => help,
        contactInfo: () => contact,
      ));
    } catch (e) {
      _log.e('ContentBloc::_onFetchHelpSupportContent::Error: $e');
      emit(state.copyWith(
        status: () => ContentStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchPrivacyPolicyContent(
    FetchPrivacyPolicyContent event,
    Emitter<ContentState> emit,
  ) async {
    _log.d('ContentBloc::_onFetchPrivacyPolicyContent::Fetching privacy policy');
    try {
      emit(state.copyWith(status: () => ContentStatus.loading));
      final privacy = await _repository.getPrivacyPolicy();
      emit(state.copyWith(
        status: () => ContentStatus.loaded,
        message: () => 'Privacy policy fetched',
        privacyPolicy: () => privacy,
      ));
    } catch (e) {
      _log.e('ContentBloc::_onFetchPrivacyPolicyContent::Error: $e');
      emit(state.copyWith(
        status: () => ContentStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchTermsConditionsContent(
    FetchTermsConditionsContent event,
    Emitter<ContentState> emit,
  ) async {
    _log.d('ContentBloc::_onFetchTermsConditionsContent::Fetching terms & conditions');
    try {
      emit(state.copyWith(status: () => ContentStatus.loading));
      final terms = await _repository.getTermsConditions();
      emit(state.copyWith(
        status: () => ContentStatus.loaded,
        message: () => 'Terms & conditions fetched',
        termsConditions: () => terms,
      ));
    } catch (e) {
      _log.e('ContentBloc::_onFetchTermsConditionsContent::Error: $e');
      emit(state.copyWith(
        status: () => ContentStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchAllCmsContent(
    FetchAllCmsContent event,
    Emitter<ContentState> emit,
  ) async {
    _log.d('ContentBloc::_onFetchAllCmsContent::Fetching all CMS content');
    try {
      emit(state.copyWith(status: () => ContentStatus.loading));
      final results = await Future.wait([
        _repository.getStoreContactInfo(),
        _repository.getAboutUs(),
        _repository.getHelpSupport(),
        _repository.getPrivacyPolicy(),
        _repository.getTermsConditions(),
      ]);

      emit(state.copyWith(
        status: () => ContentStatus.loaded,
        message: () => 'All CMS content fetched',
        contactInfo: () => results[0] as StoreContactInfo,
        aboutUs: () => results[1] as ContentModel,
        helpSupport: () => results[2] as ContentModel,
        privacyPolicy: () => results[3] as ContentModel,
        termsConditions: () => results[4] as ContentModel,
      ));
    } catch (e) {
      _log.e('ContentBloc::_onFetchAllCmsContent::Error: $e');
      emit(state.copyWith(
        status: () => ContentStatus.failure,
        message: () => e.toString(),
      ));
    }
  }
}
