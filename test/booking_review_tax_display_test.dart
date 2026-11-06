import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_review_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/offers/repos/offer_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';

class _MockApiRepositoryWithTax extends ApiRepository {
  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/offers') {
      return {
        'success': true,
        'data': [
          {
            'id': 1,
            'promoCode': 'SAVE10',
            'title': '10 off',
            'discountAmount': 10.0,
            'isActive': true,
          }
        ]
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/availability') {
      return {
        'success': true,
        'data': {
          'totalDurationMinutes': 90,
          'totalPrice': 89.0,
          'subtotal': 89.0,
          'salesTax': 7.23,
          'taxRate': 0.08125,
          'totalWithTax': 96.23,
          'stateName': null,
        }
      };
    } else if (path == '/api/offers/validate-promo') {
      return {
        'success': true,
        'data': {
          'promoCode': 'SAVE10',
          'discountAmount': 10.0,
          'finalAmount': 79.0,
        }
      };
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingDraft draft;
  late _MockApiRepositoryWithTax mockApi;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();
    await session.saveClientId('SHEAR-001');
    await session.saveRegionId('DWG-001');
    await session.saveStoreId('SHEAR-001');

    mockApi = _MockApiRepositoryWithTax();
    await mockApi.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(mockApi);

    draft = BookingDraft();
    draft.setPet({'id': '10', 'pet_name': 'Rocky', 'breed': 'Red Poodle'});
    draft.setService({'id': '193', 'service_name': 'Full Grooming', 'price': 75.0});
    draft.toggleAddOn({'id': 114, 'name': 'Flea Bath', 'price': 14.0});
    draft.setDate(DateTime(2026, 11, 10));
    draft.setSelectedSlot({'startTime': '10:00', 'endTime': '11:30', 'groomerId': 1, 'groomerName': 'Merisa Brown'});

    GetIt.I.registerSingleton<BookingDraft>(draft);
    GetIt.I.registerSingleton<StoreRepository>(StoreRepository());
    GetIt.I.registerSingleton<BookingRepository>(BookingRepository());
    GetIt.I.registerSingleton<OfferRepository>(OfferRepository());
  });

  tearDown(() {
    draft.reset();
  });

  testWidgets('Amount Details displays Tax row and totalWithTax from draft availability', (tester) async {
    draft.apiTotalPrice = 89.0;
    draft.apiSalesTax = 7.23;
    draft.apiTaxRate = 0.08125;
    draft.apiTotalWithTax = 96.23;

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Amount Details header
    expect(find.text('Amount Details'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text(r'$89.00'), findsOneWidget);

    // Verify Tax row
    expect(find.text('Tax'), findsOneWidget);
    expect(find.text(r'$7.23'), findsOneWidget);

    // Verify Appointment total
    expect(find.text('Appointment total'), findsOneWidget);
    expect(find.text(r'$96.23'), findsOneWidget);
  });

  testWidgets('Amount Details displays Tax with state name when apiStateName is present', (tester) async {
    draft.apiTotalPrice = 89.0;
    draft.apiSalesTax = 7.23;
    draft.apiTaxRate = 0.08125;
    draft.apiTotalWithTax = 96.23;
    draft.apiStateName = 'NY';

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tax (NY)'), findsOneWidget);
    expect(find.text(r'$7.23'), findsOneWidget);
  });

  testWidgets('Amount Details recalculates tax and shows Total after coupon when coupon is applied', (tester) async {
    draft.apiTotalPrice = 89.0;
    draft.apiSalesTax = 7.23;
    draft.apiTaxRate = 0.08125;
    draft.apiTotalWithTax = 96.23;

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    final inputFinder = find.widgetWithText(TextField, 'Enter promo code');
    await tester.enterText(inputFinder, 'SAVE10');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Coupon discount'), findsOneWidget);
    expect(find.text('−\$10.00'), findsOneWidget);

    // Tax recalculated on $79.00 at 0.08125 = $6.42
    expect(find.text('Tax'), findsOneWidget);
    expect(find.text(r'$6.42'), findsOneWidget);

    // Total after coupon: $79.00 + $6.42 = $85.42
    expect(find.text('Total after coupon'), findsOneWidget);
    expect(find.text(r'$85.42'), findsOneWidget);
  });
}
