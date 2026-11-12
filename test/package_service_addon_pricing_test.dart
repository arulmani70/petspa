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

class _MockApiRepositoryComboPricing extends ApiRepository {
  Map<String, dynamic>? lastAvailabilityPayload;

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/offers') {
      return {'success': true, 'data': []};
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/availability') {
      lastAvailabilityPayload = Map<String, dynamic>.from(data);
      return {
        'success': true,
        'data': {
          'totalDurationMinutes': 150,
          'totalPrice': 169.0,
          'packageSubtotal': 80.0,
          'serviceSubtotal': 75.0,
          'salesTax': 13.73,
          'taxRate': 0.0812426,
          'totalWithTax': 182.73,
          'stateName': 'TX',
          'availableSlots': [
            {'startTime': '10:00', 'endTime': '12:30', 'groomerId': 1, 'groomerName': 'Merisa Brown'}
          ],
        }
      };
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Package + Service + Add-On Pricing Tests', () {
    test('BookingDraft calculates accurate total when Package, Service, and Add-on are selected', () {
      final draft = BookingDraft();

      // 1. Select Spa Package ($80)
      draft.setPackage({
        'id': 1,
        'packageId': 1,
        'package_name': 'Deluxe Spa Package',
        'price': 80.0,
      });

      // 2. Select Standalone Service ($75)
      draft.setService({
        'id': 193,
        'serviceId': 193,
        'service_name': 'Full Grooming',
        'price': 75.0,
      });

      // 3. Select Add-on ($14)
      draft.toggleAddOn({
        'id': 1,
        'name': 'Flea & Tick Bath',
        'price': 14.0,
      });

      // Verify client-side calculated pricing
      expect(draft.packageSubtotal, 80.0);
      expect(draft.standaloneServicePrice, 75.0);
      expect(draft.addOnsTotal, 14.0);
      expect(draft.serviceSubtotal, 89.0); // service (75) + add-ons (14)
      expect(draft.estimatedTotal, 169.0); // package (80) + service (75) + add-ons (14)
      expect(draft.totalPrice, 169.0);

      // Simulate API availability response
      draft.apiPackageSubtotal = 80.0;
      draft.apiServiceSubtotal = 75.0;
      draft.apiTotalPrice = 169.0;
      draft.apiSalesTax = 13.73;
      draft.apiTaxRate = 0.0812426;
      draft.apiTotalWithTax = 182.73;
      draft.apiStateName = 'TX';

      // Verify draft getters after API response
      expect(draft.packageSubtotal, 80.0);
      expect(draft.standaloneServicePrice, 75.0);
      expect(draft.addOnsTotal, 14.0);
      expect(draft.serviceSubtotal, 89.0);
      expect(draft.estimatedTotal, 169.0);
      expect(draft.totalPrice, 169.0);
      expect(draft.totalWithTax, 182.73);

      // Verify discount calculation
      draft.applyOffer({
        'promoCode': 'OFFER10',
        'discountAmount': 10.0,
      });
      expect(draft.discountAmount, 10.0);
      expect(draft.discountedTotalPrice, 159.0);

      // Removing add-on clears stale API fields
      draft.toggleAddOn({
        'id': 1,
        'name': 'Flea & Tick Bath',
        'price': 14.0,
      });
      expect(draft.addOns.isEmpty, isTrue);
      expect(draft.addOnsTotal, 0.0);
      expect(draft.apiTotalPrice, isNull);
      expect(draft.estimatedTotal, 155.0); // 80 + 75
      expect(draft.totalPrice, 155.0);
    });

    test('BookingRepository routes serviceId to extraServiceId when packageId is present', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});

      final session = SessionService();
      await session.initialize();
      await session.saveClientId('SHEAR-001');
      await session.saveRegionId('DWG-001');
      await session.saveStoreId('SHEAR-001');

      final mockApi = _MockApiRepositoryComboPricing();
      await mockApi.initialize();

      GetIt.I.allowReassignment = true;
      GetIt.I.registerSingleton<SessionService>(session);
      GetIt.I.registerSingleton<ApiRepository>(mockApi);

      final repo = BookingRepository();
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await repo.getAvailability(
        date: dateStr,
        serviceId: 193,
        packageId: 1,
        addOnIds: [1],
      );

      final payload = mockApi.lastAvailabilityPayload;
      expect(payload, isNotNull);
      expect(payload!['packageId'], 1);
      expect(payload['serviceId'], isNull, reason: 'serviceId must be null when package is selected');
      expect(payload['extraServiceId'], 193, reason: 'extraServiceId must hold the extra service');
      expect(payload['addOnIds'], [1]);
    });

    testWidgets('BookingReviewPageMobile displays all items and sums total accurately', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});

      final session = SessionService();
      await session.initialize();
      await session.saveClientId('SHEAR-001');
      await session.saveRegionId('DWG-001');
      await session.saveStoreId('SHEAR-001');

      final mockApi = _MockApiRepositoryComboPricing();
      await mockApi.initialize();

      final draft = BookingDraft();
      draft.setPet({'id': '10', 'pet_name': 'Rocky', 'breed': 'Golden Retriever', 'weight': 'small'});
      draft.setPackage({'id': 1, 'packageId': 1, 'package_name': 'Deluxe Spa Package', 'price': 80.0});
      draft.setService({'id': 193, 'serviceId': 193, 'service_name': 'Full Grooming', 'price': 75.0});
      draft.toggleAddOn({'id': 1, 'name': 'Flea & Tick Bath', 'price': 14.0});
      draft.setDate(DateTime.now());
      draft.setSelectedSlot({'startTime': '10:00', 'endTime': '12:30', 'groomerId': 1, 'groomerName': 'Merisa Brown'});

      GetIt.I.allowReassignment = true;
      GetIt.I.registerSingleton<SessionService>(session);
      GetIt.I.registerSingleton<ApiRepository>(mockApi);
      GetIt.I.registerSingleton<BookingDraft>(draft);
      GetIt.I.registerSingleton<StoreRepository>(StoreRepository());
      GetIt.I.registerSingleton<BookingRepository>(BookingRepository());
      GetIt.I.registerSingleton<OfferRepository>(OfferRepository());

      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingReviewPageMobile(),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Package row
      expect(find.text('Deluxe Spa Package'), findsAtLeastNWidgets(1));
      expect(find.text('\$80.00'), findsOneWidget);

      // 2. Verify Standalone Service row
      expect(find.text('Full Grooming'), findsAtLeastNWidgets(1));
      expect(find.text('\$75.00'), findsOneWidget);

      // 3. Verify Add-on row
      expect(find.text('+ Flea & Tick Bath'), findsOneWidget);
      expect(find.text('\$14.00'), findsOneWidget);

      // 4. Verify Subtotal row
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('\$169.00'), findsOneWidget);

      // 5. Verify Tax row
      expect(find.text('Tax (TX)'), findsOneWidget);
      expect(find.text('\$13.73'), findsOneWidget);

      // 6. Verify Total row
      expect(find.text('Appointment total'), findsOneWidget);
      expect(find.text('\$182.73'), findsOneWidget);
    });
  });
}
