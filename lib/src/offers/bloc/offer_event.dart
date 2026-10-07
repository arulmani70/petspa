part of 'offer_bloc.dart';

sealed class OfferEvent extends Equatable {
  const OfferEvent();

  @override
  List<Object?> get props => [];
}

class InitializeOffers extends OfferEvent {
  const InitializeOffers();
}

class FetchOffers extends OfferEvent {
  final String? clientId;
  final String? regionId;
  final String? storeId;

  const FetchOffers({this.clientId, this.regionId, this.storeId});

  @override
  List<Object?> get props => [clientId, regionId, storeId];
}

class ValidatePromoCode extends OfferEvent {
  final String promoCode;
  final double orderAmount;
  final String? clientId;
  final String? regionId;
  final String? storeId;

  const ValidatePromoCode({
    required this.promoCode,
    required this.orderAmount,
    this.clientId,
    this.regionId,
    this.storeId,
  });

  @override
  List<Object?> get props => [promoCode, orderAmount, clientId, regionId, storeId];
}

class ApplyOfferEvent extends OfferEvent {
  final OfferModel offer;

  const ApplyOfferEvent(this.offer);

  @override
  List<Object?> get props => [offer];
}

class RemoveOfferEvent extends OfferEvent {
  const RemoveOfferEvent();
}
