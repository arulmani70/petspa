import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/offers/repos/offer_repository.dart';

class _MockApiRepository extends ApiRepository {
  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/offers') {
      return {
        'success': true,
        'message': 'Offers retrieved successfully',
        'data': [
          {
            'id': 1,
            'promoCode': 'PAWSOME50',
            'title': '50% off Full Grooming',
            'description': 'Enjoy 50% discount on complete grooming package',
            'discountType': 'percentage',
            'discountValue': 50,
            'minOrderAmount': 50,
            'maxDiscountAmount': 100,
            'isActive': true,
          },
          {
            'id': 2,
            'promoCode': 'SAVE10',
            'title': '\$10 Off Any Service',
            'description': 'Flat \$10 discount for all pet services',
            'discountType': 'fixed',
            'discountValue': 10,
            'minOrderAmount': 30,
            'isActive': true,
          }
        ]
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/offers/validate-promo') {
      final code = data['promoCode']?.toString();
      final orderAmount = (data['orderAmount'] as num?)?.toDouble() ?? 100.0;

      if (code == 'PAWSOME50') {
        return {
          'success': true,
          'message': 'Promo code applied successfully',
          'data': {
            'promoCode': 'PAWSOME50',
            'discountAmount': 50.0,
            'discountType': 'percentage',
            'discountValue': 50,
            'finalAmount': orderAmount - 50.0,
            'description': '50% off Full Grooming',
          }
        };
      } else if (code == 'SAVE10') {
        return {
          'success': true,
          'message': 'Promo code applied successfully',
          'data': {
            'promoCode': 'SAVE10',
            'discountAmount': 10.0,
            'discountType': 'fixed',
            'discountValue': 10,
            'finalAmount': orderAmount - 10.0,
            'description': '\$10 Off Any Service',
          }
        };
      } else {
        return {
          'success': false,
          'message': 'Promo code not found',
        };
      }
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfferRepository offerRepo;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();
    await session.saveClientId('SHEAR-001');
    await session.saveRegionId('DWG-001');
    await session.saveStoreId('SHEAR-001');

    final apiRepo = _MockApiRepository();
    await apiRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);

    offerRepo = OfferRepository();
    await offerRepo.initialize();
    GetIt.I.registerSingleton<OfferRepository>(offerRepo);
  });

  group('OfferRepository Tests', () {
    test('getOffers fetches and parses available active offers from GET /api/offers', () async {
      final offers = await offerRepo.getOffers();
      expect(offers.length, 2);
      expect(offers[0].promoCode, 'PAWSOME50');
      expect(offers[0].discountType, 'percentage');
      expect(offers[0].discountValue, 50.0);
      expect(offers[0].calculateDiscount(100.0), 50.0);

      expect(offers[1].promoCode, 'SAVE10');
      expect(offers[1].discountType, 'fixed');
      expect(offers[1].discountValue, 10.0);
      expect(offers[1].calculateDiscount(50.0), 10.0);
    });

    test('validatePromo validates valid percentage promo code via POST /api/offers/validate-promo', () async {
      final result = await offerRepo.validatePromo(
        promoCode: 'PAWSOME50',
        orderAmount: 100.0,
      );

      expect(result.success, isTrue);
      expect(result.promoCode, 'PAWSOME50');
      expect(result.discountAmount, 50.0);
      expect(result.finalAmount, 50.0);
      expect(result.description, '50% off Full Grooming');
    });

    test('validatePromo validates valid fixed promo code via POST /api/offers/validate-promo', () async {
      final result = await offerRepo.validatePromo(
        promoCode: 'SAVE10',
        orderAmount: 64.0,
      );

      expect(result.success, isTrue);
      expect(result.promoCode, 'SAVE10');
      expect(result.discountAmount, 10.0);
      expect(result.finalAmount, 54.0);
    });

    test('validatePromo handles invalid promo code response gracefully', () async {
      final result = await offerRepo.validatePromo(
        promoCode: 'INVALIDCODE',
        orderAmount: 64.0,
      );

      expect(result.success, isFalse);
      expect(result.message, 'Promo code not found');
      expect(result.discountAmount, 0.0);
    });

    test('validatePromo handles empty promo input without network call', () async {
      final result = await offerRepo.validatePromo(
        promoCode: '   ',
        orderAmount: 64.0,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Please enter a valid promo code'));
    });
  });
}
