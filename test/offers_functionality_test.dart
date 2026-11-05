import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/offers/bloc/offer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/offers/models/offer_model.dart';
import 'package:shear_heaven_pet_spa/src/offers/repo/offer_repository.dart';
import 'package:shear_heaven_pet_spa/src/offers/views/mobile/offers_page_mobile.dart';

class _MockApiForOffers extends ApiRepository {
  List<Map<String, dynamic>> offersData = [
    {
      'id': 17,
      'title': '10% on services',
      'promoCode': 'V17XB2',
      'label': '10% on services',
      'appliesTo': 'service',
      'discountType': 'percentage',
      'discountValue': 10,
      'startDate': '2026-11-01',
      'endDate': '2026-12-31',
      'isActive': true,
    },
    {
      'id': 8,
      'title': '10% Discount on Services',
      'promoCode': 'SVC10P',
      'label': '10% on services',
      'appliesTo': 'service',
      'discountType': 'percentage',
      'discountValue': 10,
      'startDate': '2026-11-01',
      'endDate': '2026-12-31',
      'isActive': true,
    },
    {
      'id': 9,
      'title': '15% Off Spa Packages',
      'promoCode': 'PKG15P',
      'label': '15% on packages',
      'appliesTo': 'package',
      'discountType': 'percentage',
      'discountValue': 15,
      'startDate': '2026-11-01',
      'endDate': '2026-12-31',
      'isActive': true,
    },
  ];

  bool shouldFailGetOffers = false;
  Map<String, dynamic>? lastValidatePayload;

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/offers') {
      if (shouldFailGetOffers) {
        throw Exception('Network connection timed out');
      }
      return {
        'success': true,
        'message': 'Coupons retrieved successfully',
        'data': offersData,
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/offers/validate-promo') {
      lastValidatePayload = Map<String, dynamic>.from(data);
      final code = data['couponCode']?.toString() ?? data['promoCode']?.toString();
      final serviceAmt = (data['serviceAmount'] as num?)?.toDouble() ?? 0.0;
      final packageAmt = (data['packageAmount'] as num?)?.toDouble() ?? 0.0;

      if (code == 'PKG15P' && packageAmt <= 0.005) {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          response: Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 400,
            data: {
              'success': false,
              'message': 'This coupon is for packages, and this appointment has no package',
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'This coupon is for packages, and this appointment has no package',
              },
            },
          ),
        );
      }

      if (code == 'SVC10P' || code == 'V17XB2') {
        if (serviceAmt <= 0.005) {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 400,
              data: {
                'success': false,
                'message': 'This coupon is for services, and this appointment has no service',
                'error': {
                  'code': 'VALIDATION_ERROR',
                  'message': 'This coupon is for services, and this appointment has no service',
                },
              },
            ),
          );
        }

        final discount = serviceAmt * 0.10;
        final finalAmt = serviceAmt - discount + packageAmt;

        return {
          'success': true,
          'message': 'Coupon validated successfully',
          'data': {
            'valid': true,
            'isValid': true,
            'offerId': data['offerId'] ?? 8,
            'couponCode': code,
            'promoCode': code,
            'title': '10% Discount on Services',
            'label': '10% on services',
            'appliesTo': 'service',
            'discountType': 'percentage',
            'discountValue': 10,
            'discountAmount': discount,
            'finalAmount': finalAmt,
            'finalTotal': finalAmt,
          },
        };
      }

      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 404,
          data: {
            'success': false,
            'message': 'Coupon not found or has expired',
            'error': {
              'code': 'NOT_FOUND',
              'message': 'Coupon not found or has expired',
            },
          },
        ),
      );
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiForOffers mockApi;
  late OfferRepository offerRepo;
  late BookingDraft bookingDraft;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();
    await session.saveClientId('SHEAR-001');
    await session.saveRegionId('DWG-001');
    await session.saveStoreId('SHEAR-001');

    mockApi = _MockApiForOffers();
    await mockApi.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(mockApi);

    offerRepo = OfferRepository();
    await offerRepo.initialize();
    GetIt.I.registerSingleton<OfferRepository>(offerRepo);

    bookingDraft = BookingDraft();
    GetIt.I.registerSingleton<BookingDraft>(bookingDraft);
  });

  tearDown(() {
    bookingDraft.reset();
  });

  group('OfferModel & Parsing Tests', () {
    test('Parses API coupons matching Shear Heaven schema', () {
      final json = {
        'id': 17,
        'title': '10% on services',
        'promoCode': 'V17XB2',
        'label': '10% on services',
        'appliesTo': 'service',
        'discountType': 'percentage',
        'discountValue': 10,
        'startDate': '2026-11-01',
        'endDate': '2026-12-31',
      };

      final model = OfferModel.fromJson(json);
      expect(model.id, '17');
      expect(model.promoCode, 'V17XB2');
      expect(model.title, '10% on services');
      expect(model.label, '10% on services');
      expect(model.appliesTo, 'service');
      expect(model.appliesToText, 'Services only');
      expect(model.discountBadge, '10% OFF');
      expect(model.discountType, 'percentage');
      expect(model.discountValue, 10.0);
      expect(model.validUntil, '2026-12-31');
      expect(model.isExpired, isFalse);
    });

    test('Identifies expired offers and calculates discount correctly', () {
      final expiredJson = {
        'id': 99,
        'promoCode': 'EXPIRED10',
        'title': 'Past offer',
        'discountType': 'fixed',
        'discountValue': 15,
        'endDate': '2020-01-01',
      };

      final model = OfferModel.fromJson(expiredJson);
      expect(model.isExpired, isTrue);
      expect(model.discountBadge, '\$15 OFF');
      expect(model.formattedExpiry, 'Expired');
      expect(model.calculateDiscount(50.0), 15.0);
    });
  });

  group('OfferRepository API Integration Tests', () {
    test('getOffers fetches dynamic coupons from /api/offers', () async {
      final offers = await offerRepo.getOffers();
      expect(offers.length, 3);
      expect(offers[0].promoCode, 'V17XB2');
      expect(offers[1].promoCode, 'SVC10P');
      expect(offers[2].promoCode, 'PKG15P');
      expect(offerRepo.cachedOffers.length, 3);
    });

    test('validatePromo resolves offerId and sends exact Postman payload', () async {
      // First fetch to prime cache
      await offerRepo.getOffers();

      final result = await offerRepo.validatePromo(
        promoCode: 'SVC10P',
        serviceAmount: 100.0,
        packageAmount: 0.0,
      );

      expect(result.success, isTrue);
      expect(result.promoCode, 'SVC10P');
      expect(result.discountAmount, 10.0);
      expect(result.finalAmount, 90.0);
      expect(mockApi.lastValidatePayload?['couponCode'], 'SVC10P');
      expect(mockApi.lastValidatePayload?['offerId'], 8);
      expect(mockApi.lastValidatePayload?['serviceAmount'], 100.0);
      expect(mockApi.lastValidatePayload?['packageAmount'], 0.0);
      expect(mockApi.lastValidatePayload?['clientId'], 'SHEAR-001');
      expect(mockApi.lastValidatePayload?['storeId'], 'SHEAR-001');
    });

    test('validatePromo surfaces server rejection message for mismatched package coupons', () async {
      await offerRepo.getOffers();

      final result = await offerRepo.validatePromo(
        promoCode: 'PKG15P',
        serviceAmount: 60.0,
        packageAmount: 0.0, // No package booked
      );

      expect(result.success, isFalse);
      expect(
        result.message,
        'This coupon is for packages, and this appointment has no package',
      );
    });

    test('validatePromo surfaces 404 not found error message', () async {
      final result = await offerRepo.validatePromo(
        promoCode: 'UNKNOWN_CODE',
        serviceAmount: 50.0,
      );

      expect(result.success, isFalse);
      expect(result.message, 'Coupon not found or has expired');
    });
  });

  group('BookingDraft service/package amount helpers', () {
    test('Calculates serviceSubtotal and packageSubtotal accurately', () {
      // Standalone service
      bookingDraft.setService({'id': '10', 'service_name': 'Bath & Brush', 'price': 45.0});
      bookingDraft.toggleAddOn({'id': '20', 'service_name': 'Nail Trim', 'price': 15.0});

      expect(bookingDraft.isPackageSelected, isFalse);
      expect(bookingDraft.serviceSubtotal, 60.0);
      expect(bookingDraft.packageSubtotal, 0.0);

      // Package
      bookingDraft.setService({
        'id': '100',
        'isPackage': true,
        'package_name': 'Royal Spa Package',
        'price': 120.0,
      });

      expect(bookingDraft.isPackageSelected, isTrue);
      expect(bookingDraft.packageSubtotal, 120.0);
      expect(bookingDraft.serviceSubtotal, 15.0); // Only the add-on
    });

    test('Discounted total price updates with applied offer', () {
      bookingDraft.apiTotalPrice = 100.0;
      bookingDraft.applyOffer({
        'promoCode': 'SVC10P',
        'discountAmount': 10.0,
      });

      expect(bookingDraft.appliedPromoCode, 'SVC10P');
      expect(bookingDraft.discountAmount, 10.0);
      expect(bookingDraft.discountedTotalPrice, 90.0);

      bookingDraft.removeOffer();
      expect(bookingDraft.appliedPromoCode, isNull);
      expect(bookingDraft.discountAmount, isNull);
      expect(bookingDraft.discountedTotalPrice, 100.0);
    });
  });

  group('OffersPageMobile UI States', () {
    testWidgets('Renders dynamic offer cards from API with no static fallback cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OfferBloc>(
            create: (_) => OfferBloc(repository: offerRepo),
            child: const OffersPageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('3 offers available for your account'), findsOneWidget);

      // Check real coupons from mock API
      expect(find.text('V17XB2'), findsOneWidget);
      expect(find.text('SVC10P'), findsOneWidget);
      expect(find.text('PKG15P'), findsOneWidget);

      // Verify NO static hardcoded cards exist
      expect(find.text('PAWSOME50'), findsNothing);
      expect(find.text('SUMMERTRIM'), findsNothing);
      expect(find.text('FRIEND20'), findsNothing);
    });

    testWidgets('Renders empty state when API returns no offers', (tester) async {
      mockApi.offersData = [];

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OfferBloc>(
            create: (_) => OfferBloc(repository: offerRepo),
            child: const OffersPageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No offers available right now'), findsOneWidget);
      expect(find.text('Check back later for seasonal promotions, special packages, and exclusive discounts.'), findsOneWidget);
      expect(find.byIcon(Icons.local_offer_outlined), findsOneWidget);
    });

    testWidgets('Renders error state with retry button on network failure', (tester) async {
      mockApi.shouldFailGetOffers = true;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OfferBloc>(
            create: (_) => OfferBloc(repository: offerRepo),
            child: const OffersPageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load offers'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Now recover and tap retry
      mockApi.shouldFailGetOffers = false;
      mockApi.offersData = [
        {
          'id': 1,
          'title': 'Test Promo',
          'promoCode': 'RECOVER1',
          'discountType': 'percentage',
          'discountValue': 20,
          'isActive': true,
        }
      ];

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('RECOVER1'), findsOneWidget);
      expect(find.text('1 offer available for your account'), findsOneWidget);
    });
  });
}
