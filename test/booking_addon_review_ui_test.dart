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

    final apiRepo = ApiRepository();
    await apiRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);

    draft = BookingDraft();
    draft.setPet({
      'id': 1,
      'pet_name': 'Max',
      'breed': 'Golden Retriever',
      'weight': 'Large',
      'age': 3,
    });
    draft.setService({
      'id': 193,
      'serviceId': 193,
      'name': 'Grooming',
      'service_name': 'Grooming',
      'price': 75.0,
      'durationMinutes': 60,
      'description': 'Full groom service',
    });
    draft.date = DateTime(2026, 11, 6);
    draft.timeSlot = '10:00';
    draft.endTime = '11:00';
    draft.groomer = {
      'id': 1,
      'name': 'Merisa Brown',
    };
    draft.apiDurationMinutes = 90;
    draft.apiTotalPrice = 89.0;

    // Add an add-on
    draft.toggleAddOn({
      'id': 114,
      'addOnId': 114,
      'name': 'Flea Bath',
      'service_name': 'Flea Bath',
      'price': 14.0,
      'priceDisplay': r'$14.00',
      'duration': '30 min',
      'durationMinutes': 30,
      'description': 'Special flea and tick medicated bath treatment for pets with skin sensitivity.',
    });

    GetIt.I.registerSingleton<BookingDraft>(draft);
    GetIt.I.registerSingleton<StoreRepository>(StoreRepository());
    GetIt.I.registerSingleton<BookingRepository>(BookingRepository());
    GetIt.I.registerSingleton<OfferRepository>(OfferRepository());
  });

  tearDown(() {
    draft.reset();
  });

  testWidgets('Renders BookingReviewPageMobile with Selected Add-ons without UI overflow or errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // Typical iPhone size
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.text('Selected Add-ons'), findsOneWidget);
    expect(find.text('Flea Bath'), findsWidgets);
    expect(find.text('+ Flea Bath'), findsOneWidget);
    expect(find.text('Appointment total'), findsOneWidget);
  });

  testWidgets('Renders on narrow 320px screen with multiple add-ons without overflows', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Add a second add-on with a long title and description
    draft.toggleAddOn({
      'id': 115,
      'addOnId': 115,
      'name': 'De-Matting Treatment Extra Care',
      'service_name': 'De-Matting Treatment Extra Care',
      'price': 25.0,
      'priceDisplay': r'$25.00',
      'duration': '45 min',
      'durationMinutes': 45,
      'description': 'Deep conditioning and gentle detangling coat remedy to restore natural pet luster and shine.',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.text('Selected Add-ons'), findsOneWidget);
    expect(find.text('Flea Bath'), findsWidgets);
    expect(find.text('De-Matting Treatment Extra Care'), findsWidgets);
    expect(find.text('+ De-Matting Treatment Extra Care'), findsOneWidget);
  });

  testWidgets('Renders with long duration and price format like "\$18 & up" on 320px screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    draft.toggleAddOn({
      'id': 116,
      'addOnId': 116,
      'name': 'Hypoallergenic Medicated Spa Soak',
      'service_name': 'Hypoallergenic Medicated Spa Soak',
      'price': 18.0,
      'priceDisplay': r'$18 & up',
      'duration': '45-60 min',
      'durationMinutes': 60,
      'description': 'Soothing oatmeal and aloe treatment designed for pets experiencing seasonal skin irritation.',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.text('Selected Add-ons'), findsOneWidget);
    expect(find.text('Hypoallergenic Medicated Spa Soak'), findsWidgets);
  });

  testWidgets('Renders with applied coupon and add-ons without overflow on narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    draft.applyOffer({
      'id': 'offer-1',
      'title': 'Grand Opening Special',
      'promoCode': 'SAVE15',
      'code': 'SAVE15',
      'discountAmount': 15.0,
      'discountedTotalPrice': 74.0,
      'description': '15% off any grooming service',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.text('Selected Add-ons'), findsOneWidget);
    expect(find.text('Coupon discount'), findsOneWidget);
  });

  testWidgets('Renders on scaled font (1.3x) without RenderFlex overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: BookingReviewPageMobile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.text('Selected Add-ons'), findsOneWidget);
  });

  testWidgets('Renders real API catalogue add-on with multi-size pricing string without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Clear and add real raw string from GET /api/service-packages AddOns:
    // Name: 'Flea Bath', Price: '$14.00', Sufix: 'small / $18 medium / $22 large'
    draft.addOns.clear();
    draft.toggleAddOn({
      'id': 114,
      'addOnId': 'A0001',
      'name': 'Flea Bath Special Medicated Treatment',
      'service_name': 'Flea Bath Special Medicated Treatment',
      'price': 14.0,
      'priceDisplay': r'$14.00small / $18 medium / $22 large',
      'duration': '30 min',
      'durationMinutes': 30,
      'description': 'Flea and tick medicated relief bath.',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: BookingReviewPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review & Confirm'), findsOneWidget);
    expect(find.text('Selected Add-ons'), findsOneWidget);
    // Should format cleanly to $14 rather than overflowing with the 38-char suffix string
    expect(find.text(r'$14'), findsWidgets);
  });
}
