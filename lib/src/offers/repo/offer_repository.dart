import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/offers/models/offer_model.dart';

class OfferRepository {
  final Logger _log = Logger();
  List<OfferModel> _cachedOffers = [];

  List<OfferModel> get cachedOffers => List.unmodifiable(_cachedOffers);

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

      List<OfferModel> offers = [];

      if (response != null) {
        dynamic rawList;
        if (response['data'] != null && response['data'] is List) {
          rawList = response['data'];
        } else if (response is List) {
          rawList = response;
        }

        if (rawList is List) {
          offers = rawList
              .whereType<Map>()
              .map((item) => OfferModel.fromJson(Map<String, dynamic>.from(item)))
              .where((o) => o.isActive)
              .toList();
          _cachedOffers = offers;
          _log.d('OfferRepository::getOffers::Fetched ${offers.length} active offers');
          return offers;
        }
      }

      _log.w('OfferRepository::getOffers::Empty or invalid response from /api/offers');
      return [];
    } catch (e) {
      _log.e('OfferRepository::getOffers::Error fetching offers: $e');
      rethrow;
    }
  }

  /// Validates a promo code via POST /api/offers/validate-promo
  Future<PromoValidationResult> validatePromo({
    required String promoCode,
    dynamic offerId,
    double? serviceAmount,
    double? packageAmount,
    double? orderAmount,
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

      // If offerId was not provided directly, attempt to resolve it from cached offers
      dynamic resolvedOfferId = offerId;
      if (resolvedOfferId == null) {
        if (_cachedOffers.isEmpty) {
          try {
            await getOffers(clientId: cId, regionId: rId, storeId: sId);
          } catch (_) {}
        }
        for (final o in _cachedOffers) {
          if (o.promoCode.trim().toUpperCase() == trimmedCode.toUpperCase()) {
            resolvedOfferId = int.tryParse(o.id) ?? o.id;
            break;
          }
        }
      } else {
        resolvedOfferId = int.tryParse(resolvedOfferId.toString()) ?? resolvedOfferId;
      }

      final double sAmt = serviceAmount ?? 0.0;
      final double pAmt = packageAmount ?? 0.0;
      final double totalAmt = orderAmount ?? ((sAmt + pAmt) > 0 ? (sAmt + pAmt) : 0.0);

      final payload = <String, dynamic>{
        if (resolvedOfferId != null) 'offerId': resolvedOfferId, // ignore: use_null_aware_elements
        'couponCode': trimmedCode.toUpperCase(),
        'promoCode': trimmedCode.toUpperCase(),
        'serviceAmount': sAmt,
        'packageAmount': pAmt,
        'orderAmount': totalAmt,
        'clientId': cId,
        'regionId': rId,
        'storeId': sId,
        'ClientID': cId,
        'RegionId': rId,
        'StoreId': sId,
      };

      _log.d('OfferRepository::validatePromo::Validating promo: $trimmedCode on order $totalAmt (s=$sAmt, p=$pAmt)');

      final response = await ServicesLocator.apiRepository.post(
        '/api/offers/validate-promo',
        payload,
      );

      if (response != null) {
        final result = PromoValidationResult.fromJson(
          response,
          defaultPromoCode: trimmedCode.toUpperCase(),
          originalAmount: totalAmt,
        );
        _log.d('OfferRepository::validatePromo::Result valid=${result.success} msg=${result.message} discount=${result.discountAmount}');
        return result;
      }

      return PromoValidationResult(
        success: false,
        message: 'Could not validate promo code. Please try again.',
        promoCode: trimmedCode,
      );
    } catch (e) {
      _log.e('OfferRepository::validatePromo::Error validating promo: $e');

      String errorMessage = 'Could not validate promo code.';
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map) {
          if (resData['message'] != null) {
            errorMessage = resData['message'].toString();
          } else if (resData['error'] is Map && resData['error']['message'] != null) {
            errorMessage = resData['error']['message'].toString();
          }
        }
      }

      return PromoValidationResult(
        success: false,
        message: errorMessage,
        promoCode: promoCode,
      );
    }
  }
}
