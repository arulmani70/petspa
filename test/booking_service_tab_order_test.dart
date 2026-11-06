import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_service_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class _MockApiRepository extends ApiRepository {
  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/service-packages') {
      return {
        'success': true,
        'message': 'Catalog loaded',
        'data': {
          'ClientID': 'SHEAR-001',
          'RegionId': 'DWG-001',
          'StoreId': 'SHEAR-001',
          'Breeds': [],
          'Main Services': [
            {
              'MainServiceId': 'SRV-GROOMING',
              'ServiceMasterId': 193,
              'Name': 'Grooming',
              'Description': 'Full groom service',
              'Price': r'$75.00',
              'TimeinMinutes': '60',
            },
            {
              'MainServiceId': 'SRV-BATHING',
              'ServiceMasterId': 194,
              'Name': 'Bathing',
              'Description': 'Full bath service',
              'Price': r'$40.00',
              'TimeinMinutes': '30',
            },
          ],
          'Packages': [
            {
              'PackageId': 'PXX-001',
              'PackageMasterId': 1,
              'PackageName': 'Special Package',
              'Price': r'$80.00',
              'TimeinMinutes': '60',
            },
          ],
          'AddOns': [
            {
              'AddOnId': 'A0001',
              'ServiceMasterId': 114,
              'Name': 'Flea Bath',
              'Price': r'$14.00',
              'TimeinMinutes': '30',
            },
          ],
          'Walk In Services': [
            {
              'WalkInServiceId': 'W0001',
              'ServiceMasterId': 126,
              'Name': 'Nail Trim',
              'Price': r'$18.00',
              'TimeinMinutes': '15',
            },
          ],
        },
      };
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingDraft draft;
  late ServiceRepository serviceRepo;
  late _MockApiRepository apiRepo;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();
    await session.saveClientId('SHEAR-001');
    await session.saveRegionId('DWG-001');
    await session.saveStoreId('SHEAR-001');

    apiRepo = _MockApiRepository();
    await apiRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);

    serviceRepo = ServiceRepository();
    GetIt.I.registerSingleton<ServiceRepository>(serviceRepo);

    draft = BookingDraft();
    GetIt.I.registerSingleton<BookingDraft>(draft);
  });

  tearDown(() {
    draft.reset();
  });

  group('Select Services Tab Order & Service Loading Tests', () {
    test('ServiceRepository parses Main Services from API catalog', () async {
      final result = await serviceRepo.getBookingServices();

      expect(result.packages, isNotEmpty);
      expect(result.packages.first.name, equals('Special Package'));

      // Main Services must be loaded into breeds/services with live images
      expect(result.breeds, isNotEmpty);
      expect(result.breeds.length, equals(2));
      expect(result.breeds[0].name, equals('Grooming'));
      expect(result.breeds[0].id, equals(193));
      expect(result.breeds[0].imageUrl, contains('svc_full_grooming.png'));
      expect(result.breeds[1].name, equals('Bathing'));
      expect(result.breeds[1].id, equals(194));
      expect(result.breeds[1].imageUrl, contains('svc_bath_blowdry.png'));

      expect(result.addOns, isNotEmpty);
      expect(result.walkIn, isNotEmpty);
    });

    testWidgets('Shows Packages tab first, followed by Services tab even with a real pet selected', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Set a real pet in draft
      draft.setPet({
        'id': 1,
        'pet_name': 'Max',
        'breed': 'Golden Retriever',
        'weight': 'Large',
      });

      final bloc = ServiceBloc(repository: serviceRepo)..add(const InitializeServices());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ServiceBloc>.value(
            value: bloc,
            child: const BookingServicePageMobile(),
          ),
        ),
      );

      // Settle loading state
      await tester.pumpAndSettle();

      // Find the tabs
      final packagesTab = find.text('Packages');
      final servicesTab = find.text('Services');
      final addOnsTab = find.text('Add-Ons');
      final walkInTab = find.text('Walk-In');

      expect(packagesTab, findsOneWidget);
      expect(servicesTab, findsOneWidget);
      expect(addOnsTab, findsOneWidget);
      expect(walkInTab, findsNothing); // Walk-In tab should not be displayed in Select Service

      // Verify Tab Order: Packages (x < Services x < Add-Ons x)
      final packagesOffset = tester.getTopLeft(packagesTab);
      final servicesOffset = tester.getTopLeft(servicesTab);
      final addOnsOffset = tester.getTopLeft(addOnsTab);

      // Packages is before Services
      expect(packagesOffset.dx, lessThan(servicesOffset.dx));
      // Services is before Add-Ons
      expect(servicesOffset.dx, lessThan(addOnsOffset.dx));

      // Tap on the Services tab
      await tester.tap(servicesTab);
      await tester.pumpAndSettle();

      // Ensure Grooming service card is displayed
      expect(find.text('Grooming'), findsOneWidget);
      expect(find.text('Bathing'), findsOneWidget);

      // Tapping Grooming sets it in the draft
      await tester.tap(find.text('Grooming'));
      await tester.pumpAndSettle();

      expect(draft.service, isNotNull);
      expect(draft.service!['name'], equals('Grooming'));
      expect(draft.service!['serviceId'], equals(193));
      expect(draft.isPackageSelected, isFalse);
    });

    test('ServiceRepository.liveServiceImageUrl and resolveImageUrl produce live URLs', () {
      expect(
        ServiceRepository.liveServiceImageUrl('Grooming'),
        equals('https://pcmdev.shearheavenpetspa.com/assets/images/common/svc_full_grooming.png'),
      );
      expect(
        ServiceRepository.liveServiceImageUrl('Bathing'),
        equals('https://pcmdev.shearheavenpetspa.com/assets/images/common/svc_bath_blowdry.png'),
      );
      expect(
        ServiceRepository.liveServiceImageUrl('Grooming and Bathing'),
        equals('https://pcmdev.shearheavenpetspa.com/assets/images/home/promo_dog.png'),
      );
      expect(
        ServiceRepository.resolveImageUrl('assets/images/common/svc_full_grooming.png'),
        equals('assets/images/common/svc_full_grooming.png'),
      );
      expect(
        ServiceRepository.resolveImageUrl('/assets/images/common/svc_spa.png'),
        equals('https://pcmdev.shearheavenpetspa.com/assets/images/common/svc_spa.png'),
      );
    });

    testWidgets('Step 2 of 4 Add-Ons tab renders on narrow 320px screen without right side overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      draft.setPet({
        'id': 1,
        'pet_name': 'Max',
        'breed': 'Golden Retriever',
        'weight': 'Large',
      });

      final bloc = ServiceBloc(repository: serviceRepo)..add(const InitializeServices());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ServiceBloc>.value(
            value: bloc,
            child: const BookingServicePageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addOnsTab = find.text('Add-Ons');
      expect(addOnsTab, findsOneWidget);

      await tester.tap(addOnsTab);
      await tester.pumpAndSettle();

      expect(find.text('Flea Bath'), findsOneWidget);
      // Tapping add-on selects it in draft
      await tester.tap(find.text('Flea Bath'));
      await tester.pumpAndSettle();

      expect(draft.addOns.length, equals(1));
    });
  });
}
