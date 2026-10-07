import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/offers/models/offer_model.dart';
import 'package:shear_heaven_pet_spa/src/offers/repo/offer_repository.dart';

part 'offer_event.dart';
part 'offer_state.dart';

class OfferBloc extends Bloc<OfferEvent, OfferState> {
  OfferBloc({required OfferRepository repository})
      : _repository = repository,
        super(OfferState.initial) {
    on<InitializeOffers>(_onInitializeOffers);
    on<FetchOffers>(_onFetchOffers);
    on<ValidatePromoCode>(_onValidatePromoCode);
    on<ApplyOfferEvent>(_onApplyOffer);
    on<RemoveOfferEvent>(_onRemoveOffer);
  }

  final OfferRepository _repository;
  final _log = Logger();

  Future<void> _onInitializeOffers(
    InitializeOffers event,
    Emitter<OfferState> emit,
  ) async {
    _log.d('OfferBloc::_onInitializeOffers::Initializing offers');
    try {
      emit(state.copyWith(status: () => OfferStatus.loading));
      final offers = await _repository.getOffers();
      emit(state.copyWith(
        status: () => OfferStatus.loaded,
        message: () => 'Offers loaded',
        offers: () => offers,
      ));
    } catch (e) {
      _log.e('OfferBloc::_onInitializeOffers::Error: $e');
      emit(state.copyWith(
        status: () => OfferStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchOffers(
    FetchOffers event,
    Emitter<OfferState> emit,
  ) async {
    _log.d('OfferBloc::_onFetchOffers::Fetching offers');
    try {
      emit(state.copyWith(status: () => OfferStatus.loading));
      final offers = await _repository.getOffers(
        clientId: event.clientId,
        regionId: event.regionId,
        storeId: event.storeId,
      );
      emit(state.copyWith(
        status: () => OfferStatus.loaded,
        message: () => 'Offers fetched',
        offers: () => offers,
      ));
    } catch (e) {
      _log.e('OfferBloc::_onFetchOffers::Error: $e');
      emit(state.copyWith(
        status: () => OfferStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onValidatePromoCode(
    ValidatePromoCode event,
    Emitter<OfferState> emit,
  ) async {
    _log.d('OfferBloc::_onValidatePromoCode::Validating promo: ${event.promoCode}');
    try {
      emit(state.copyWith(status: () => OfferStatus.validating));
      final result = await _repository.validatePromo(
        promoCode: event.promoCode,
        orderAmount: event.orderAmount,
        clientId: event.clientId,
        regionId: event.regionId,
        storeId: event.storeId,
      );

      if (result.success) {
        emit(state.copyWith(
          status: () => OfferStatus.success,
          message: () => result.message,
          validatedPromo: () => result,
        ));
      } else {
        emit(state.copyWith(
          status: () => OfferStatus.failure,
          message: () => result.message,
          validatedPromo: () => result,
        ));
      }
    } catch (e) {
      _log.e('OfferBloc::_onValidatePromoCode::Error: $e');
      emit(state.copyWith(
        status: () => OfferStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  void _onApplyOffer(
    ApplyOfferEvent event,
    Emitter<OfferState> emit,
  ) {
    _log.d('OfferBloc::_onApplyOffer::Applying offer ${event.offer.title}');
    emit(state.copyWith(
      status: () => OfferStatus.success,
      message: () => 'Offer applied',
      appliedOffer: () => event.offer,
    ));
  }

  void _onRemoveOffer(
    RemoveOfferEvent event,
    Emitter<OfferState> emit,
  ) {
    _log.d('OfferBloc::_onRemoveOffer::Removing applied offer');
    emit(state.copyWith(
      status: () => OfferStatus.loaded,
      message: () => 'Offer removed',
      appliedOffer: () => null,
      validatedPromo: () => null,
    ));
  }
}
