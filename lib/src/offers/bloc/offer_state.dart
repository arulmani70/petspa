part of 'offer_bloc.dart';

enum OfferStatus { initial, loading, loaded, validating, success, failure }

class OfferState extends Equatable {
  final OfferStatus status;
  final String message;
  final List<OfferModel> offers;
  final PromoValidationResult? validatedPromo;
  final OfferModel? appliedOffer;

  const OfferState({
    required this.status,
    required this.message,
    required this.offers,
    this.validatedPromo,
    this.appliedOffer,
  });

  static const OfferState initial = OfferState(
    status: OfferStatus.initial,
    message: '',
    offers: [],
  );

  OfferState copyWith({
    OfferStatus Function()? status,
    String Function()? message,
    List<OfferModel> Function()? offers,
    PromoValidationResult? Function()? validatedPromo,
    OfferModel? Function()? appliedOffer,
  }) {
    return OfferState(
      status: status != null ? status() : this.status,
      message: message != null ? message() : this.message,
      offers: offers != null ? offers() : this.offers,
      validatedPromo: validatedPromo != null ? validatedPromo() : this.validatedPromo,
      appliedOffer: appliedOffer != null ? appliedOffer() : this.appliedOffer,
    );
  }

  @override
  List<Object?> get props => [status, message, offers, validatedPromo, appliedOffer];
}
