import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_review_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/offers/bloc/offer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/offers/repo/offer_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/mobile/pet_select_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';

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
      }
    }
    return {'success': false, 'message': 'Invalid promo code'};
  }
}

class _FakePetRepository extends PetRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => [
        {
          'id': 1,
          'pet_name': 'Max',
          'breed': 'Golden Retriever',
          'weight': 'Standard',
        }
      ];
}

class _FakeServiceRepository extends ServiceRepository {
  @override
  Future<BookingServicesResult> getBookingServices() async => BookingServicesResult(
        breeds: [],
        packages: [],
        addOns: [],
        walkIn: [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingDraft draft;
  late OfferRepository offerRepo;

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

    offerRepo = OfferRepository();
    await offerRepo.initialize();
    GetIt.I.registerSingleton<OfferRepository>(offerRepo);

    draft = BookingDraft();
    draft.setPet({'id': 1, 'pet_name': 'Max', 'breed': 'Golden Retriever', 'weight': 'Standard'});
    draft.setService({'id': '1', 'service_name': 'Full Grooming', 'price': 100.0, 'description': 'Complete grooming'});
    draft.setDate(DateTime(2026, 9, 2));
    draft.setSelectedSlot({'startTime': '10:30', 'endTime': '11:30', 'groomerId': 1, 'groomerName': 'Alex'});
    draft.apiTotalPrice = 100.0;
    GetIt.I.registerSingleton<BookingDraft>(draft);

    final storeRepo = StoreRepository();
    GetIt.I.registerSingleton<StoreRepository>(storeRepo);

    final bookingRepo = BookingRepository();
    GetIt.I.registerSingleton<BookingRepository>(bookingRepo);

    GetIt.I.registerSingleton<PetRepository>(_FakePetRepository());
    GetIt.I.registerSingleton<ServiceRepository>(_FakeServiceRepository());
  });

  tearDown(() {
    draft.reset();
  });

  group('Booking Offers Lifecycle & Persistence Tests', () {
    testWidgets('Applied offer card displays in review page when promo code applied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OfferBloc>(
            create: (_) => OfferBloc(repository: offerRepo),
            child: const BookingReviewPageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter promo code PAWSOME50
      final inputFinder = find.widgetWithText(TextField, 'Enter promo code');
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'PAWSOME50');
      await tester.pumpAndSettle();

      // Tap Apply
      final applyButton = find.text('Apply');
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Verify Offer Card is visible
      expect(find.text('PAWSOME50 applied'), findsOneWidget);
      expect(find.text('50% off Full Grooming'), findsOneWidget);
      expect(draft.appliedPromoCode, 'PAWSOME50');
    });

    testWidgets('Navigating back from booking review cleans up applied offer state and card disappears', (tester) async {
      final router = GoRouter(
        initialLocation: '/booking-review',
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            builder: (context, state) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/booking-datetime',
            name: RouteNames.bookingDateTime,
            builder: (context, state) => const Scaffold(body: Text('Date Time Screen')),
          ),
          GoRoute(
            path: '/booking-review',
            name: RouteNames.bookingReview,
            builder: (context, state) => const BookingReviewPageMobile(),
          ),
        ],
      );

      await tester.pumpWidget(
        BlocProvider<OfferBloc>(
          create: (_) => OfferBloc(repository: offerRepo),
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Apply promo
      final inputFinder = find.widgetWithText(TextField, 'Enter promo code');
      await tester.enterText(inputFinder, 'PAWSOME50');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(draft.appliedPromoCode, 'PAWSOME50');
      expect(find.text('PAWSOME50 applied'), findsOneWidget);

      // Tap back button on BookingHeader to exit the review page
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify draft applied offer is reset upon exiting
      expect(draft.appliedOffer, isNull);
      expect(draft.appliedPromoCode, isNull);

      // Verify we arrived back on previous screen
      expect(find.text('Date Time Screen'), findsOneWidget);
      expect(find.text('PAWSOME50 applied'), findsNothing);
    });

    testWidgets('Exiting pet select page clears any stale booking offer state', (tester) async {
      // Simulate draft having an offer
      draft.applyOffer({
        'promoCode': 'OLDPROMO',
        'discountAmount': 20.0,
      });
      expect(draft.appliedOffer, isNotNull);

      final router = GoRouter(
        initialLocation: '/pet-select',
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            builder: (context, state) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/pet-select',
            name: RouteNames.petSelect,
            builder: (context, state) => const PetSelectPageMobile(),
          ),
        ],
      );

      final petBloc = PetBloc(repository: ServicesLocator.petRepository);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<PetBloc>.value(value: petBloc),
            BlocProvider<OfferBloc>(create: (_) => OfferBloc(repository: offerRepo)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Back out to Home Screen
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify draft offer is cleared
      expect(draft.appliedOffer, isNull);
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('Re-entering booking flow after exit does not show stale offer cards', (tester) async {
      // Set an offer
      draft.applyOffer({
        'promoCode': 'PAWSOME50',
        'discountAmount': 50.0,
        'description': '50% off Full Grooming',
      });
      // User exits flow
      draft.removeOffer();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OfferBloc>(
            create: (_) => OfferBloc(repository: offerRepo),
            child: const BookingReviewPageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No stale offer banner or card appears
      expect(find.text('PAWSOME50 applied'), findsNothing);
      expect(find.text('50% off Full Grooming'), findsNothing);
      expect(find.text('Remove'), findsNothing);
      expect(draft.appliedOffer, isNull);
    });

    testWidgets('Legitimate repository offers are preserved and unaffected by booking exit', (tester) async {
      final availableOffers = await offerRepo.getOffers();
      expect(availableOffers.length, 1);
      expect(availableOffers.first.promoCode, 'PAWSOME50');

      // Draft resets offer
      draft.removeOffer();

      // Available offers still exist in repository
      final availableOffersAfter = await offerRepo.getOffers();
      expect(availableOffersAfter.length, 1);
      expect(availableOffersAfter.first.promoCode, 'PAWSOME50');
    });
  });
}
