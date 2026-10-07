import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/offers/models/offer_model.dart';

class OfferRepository {
  final Logger _log = Logger();

  Future<void> initialize() async {
    _log.d('OfferRepository::initialize::Initialized');
  }

  /// Fetches the list of active offers from GET /api/offers
  Future<List<OfferModel>> getOffers({
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final session = ServicesLocator.sessionService;
      final cId = clientId ?? session.clientId ?? 'SHEAR-001';
      final rId = regionId ?? session.regionId ?? 'DWG-001';
      final sId = storeId ?? session.storeId ?? 'SHEAR-001';

      _log.d('OfferRepository::getOffers::Fetching offers for store $sId');

      final queryParams = <String, dynamic>{
        if (cId.isNotEmpty) 'clientId': cId,
        if (rId.isNotEmpty) 'regionId': rId,
        if (sId.isNotEmpty) 'storeId': sId,
      };

      final response = await ServicesLocator.apiRepository.get(
        '/api/offers',
        query: queryParams,
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        final rawList = response['data'];
        if (rawList is List) {
          final offers = rawList
              .whereType<Map>()
              .map((item) => OfferModel.fromJson(Map<String, dynamic>.from(item)))
              .where((o) => o.isActive)
              .toList();
          _log.d('OfferRepository::getOffers::Fetched ${offers.length} active offers');
          return offers;
        }
      }

      _log.w('OfferRepository::getOffers::Empty or invalid response from /api/offers');
      return [];
    } catch (e) {
      _log.e('OfferRepository::getOffers::Error fetching offers: $e');
      return [];
    }
  }

  /// Validates a promo code via POST /api/offers/validate-promo
  Future<PromoValidationResult> validatePromo({
    required String promoCode,
    required double orderAmount,
    String? clientId,
    String? regionId,
    String? storeId,
  }) async {
    try {
      final session = ServicesLocator.sessionService;
      final cId = clientId ?? session.clientId ?? 'SHEAR-001';
      final rId = regionId ?? session.regionId ?? 'DWG-001';
      final sId = storeId ?? session.storeId ?? 'SHEAR-001';

      final trimmedCode = promoCode.trim();
      if (trimmedCode.isEmpty) {
        return PromoValidationResult(
          success: false,
          message: 'Please enter a valid promo code.',
          promoCode: promoCode,
        );
      }

      final payload = {
        'promoCode': trimmedCode,
        'orderAmount': orderAmount,
        'clientId': cId,
        'regionId': rId,
        'storeId': sId,
      };

      _log.d('OfferRepository::validatePromo::Validating promo: $trimmedCode on order $orderAmount');

      final response = await ServicesLocator.apiRepository.post(
        '/api/offers/validate-promo',
        payload,
      );

      if (response != null) {
        final result = PromoValidationResult.fromJson(
          response,
          defaultPromoCode: trimmedCode,
          originalAmount: orderAmount,
        );
        _log.d('OfferRepository::validatePromo::Result valid=${result.success} discount=${result.discountAmount}');
        return result;
      }

      return PromoValidationResult(
        success: false,
        message: 'Could not validate promo code. Please try again.',
        promoCode: trimmedCode,
      );
    } catch (e) {
      _log.e('OfferRepository::validatePromo::Error validating promo: $e');
      return PromoValidationResult(
        success: false,
        message: 'Network error while validating promo code.',
        promoCode: promoCode,
      );
    }
  }
}
