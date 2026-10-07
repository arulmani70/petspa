import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_review_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/offers/repos/offer_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';

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
            'description': '50% discount on complete grooming package',
            'discountType': 'percentage',
            'discountValue': 50,
            'minOrderAmount': 50,
            'isActive': true,
          },
        ]
      };
    } else if (path == '/api/holidays') {
      return {'success': true, 'data': {'HolidayList': []}};
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/offers/validate-promo') {
      final code = data['promoCode']?.toString();
      if (code == 'PAWSOME50') {
        return {
          'success': true,
          'message': 'Promo code applied successfully',
          'data': {
            'promoCode': 'PAWSOME50',
            'discountAmount': 50.0,
            'discountType': 'percentage',
            'discountValue': 50,
            'finalAmount': 50.0,
            'description': '50% off Full Grooming',
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

  late BookingDraft draft;

  setUp(() async {
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

    final offerRepo = OfferRepository();
    await offerRepo.initialize();
    GetIt.I.registerSingleton<OfferRepository>(offerRepo);

    draft = BookingDraft();
    draft.setPet({'id': '1', 'pet_name': 'Teddy', 'breed': 'Shih Tzu', 'weight': '16kg', 'birth_date': '2024-03-10'});
    draft.setService({'id': '1', 'service_name': 'Full Grooming', 'price': 100.0, 'description': 'Complete grooming'});
    final nextWeekday = DateTime(2026, 9, 2); // Wednesday (guaranteed open weekday)
    draft.setDate(nextWeekday);
    draft.setSelectedSlot({'startTime': '10:30', 'endTime': '11:30', 'groomerId': 1, 'groomerName': 'Alex'});
    draft.apiTotalPrice = 100.0;
    GetIt.I.registerSingleton<BookingDraft>(draft);

    final storeRepo = StoreRepository();
    GetIt.I.registerSingleton<StoreRepository>(storeRepo);

    final bookingRepo = BookingRepository();
    GetIt.I.registerSingleton<BookingRepository>(bookingRepo);
  });

  testWidgets('Renders Have a promo code section, applies PAWSOME50 and removes it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Promo Code Header, Input, and View Offers link
    expect(find.text('Have a promo code?'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('View available offers'), findsOneWidget);

    // Enter promo code PAWSOME50
    final inputFinder = find.widgetWithText(TextField, 'Enter promo code');
    expect(inputFinder, findsOneWidget);
    await tester.enterText(inputFinder, 'PAWSOME50');
    await tester.pumpAndSettle();

    // Tap Apply button
    final applyButton = find.text('Apply');
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    // Verify Applied Offer Card
    expect(find.text('PAWSOME50 applied'), findsOneWidget);
    expect(find.text('50% off Full Grooming'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(draft.appliedPromoCode, 'PAWSOME50');
    expect(draft.discountAmount, 50.0);
    expect(draft.discountedTotalPrice, 50.0);

    // Tap Remove
    final removeButton = find.text('Remove');
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    // Verify Offer Card is gone and draft is reset
    expect(find.text('PAWSOME50 applied'), findsNothing);
    expect(draft.appliedOffer, isNull);
  });

  testWidgets('Opens Available Offers modal and applies offer from list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap View available offers
    final viewOffersLink = find.text('View available offers');
    await tester.tap(viewOffersLink);
    await tester.pumpAndSettle();

    // Verify Modal opens with Available Offers
    expect(find.text('Available Offers'), findsOneWidget);
    expect(find.text('PAWSOME50'), findsOneWidget);
    expect(find.text('50% off Full Grooming'), findsOneWidget);

    // Tap Apply in modal
    final modalApplyButton = find.widgetWithText(ElevatedButton, 'Apply');
    expect(modalApplyButton, findsOneWidget);
    await tester.tap(modalApplyButton);
    await tester.pumpAndSettle();

    // Verify modal closed and offer applied on main screen
    expect(find.text('PAWSOME50 applied'), findsOneWidget);
    expect(draft.appliedPromoCode, 'PAWSOME50');
  });

  testWidgets('Handles invalid promo code correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    // Enter invalid promo code
    final inputFinder = find.widgetWithText(TextField, 'Enter promo code');
    await tester.enterText(inputFinder, 'WRONGCODE');
    await tester.pumpAndSettle();

    // Tap Apply button
    final applyButton = find.text('Apply');
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    // Verify offer is not applied
    expect(find.text('WRONGCODE applied'), findsNothing);
    expect(draft.appliedOffer, isNull);
  });
}
