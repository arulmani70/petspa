import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/home/views/home_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class _FakeAuthRepo extends AuthRepository {
  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => {'id': 1, 'name': 'Alexander'};
}

class _FakePetRepo extends PetRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => [];
}

class _FakeServiceRepoWithApiImages extends ServiceRepository {
  static const mockWalkIn = [
    ServiceItem(
      id: 101,
      isPackage: false,
      isAddOn: false,
      name: 'Nail Trim',
      description: 'Carefully trimmed and smoothed nails.',
      price: 18.0,
      priceDisplay: '\$18.00',
      durationMinutes: 15,
      imageUrl: 'http://localhost:3464/services_img/svc_nail_trim.png',
    ),
    ServiceItem(
      id: 102,
      isPackage: false,
      isAddOn: false,
      name: 'Nail Grind',
      description: 'Precision nail grinding.',
      price: 24.0,
      priceDisplay: '\$24.00',
      durationMinutes: 20,
      imageUrl: 'https://devapi.shearheavenpetspa.com/services_img/svc_nail_trim.png',
    ),
    ServiceItem(
      id: 103,
      isPackage: false,
      isAddOn: false,
      name: 'Anal Glands',
      description: 'Gentle and hygienic expression.',
      price: 12.0,
      priceDisplay: '\$12.00',
      durationMinutes: 15,
      imageUrl: '/services_img/svc_ear_clean.png',
    ),
    ServiceItem(
      id: 104,
      isPackage: false,
      isAddOn: false,
      name: 'Face And Feet Trim',
      description: 'Precision trimming.',
      price: 20.0,
      priceDisplay: '\$20.00',
      durationMinutes: 20,
      imageUrl: 'https://api.shearheavenpetspa.com/services_img/svc_hair_trim.png',
    ),
  ];

  @override
  Future<BookingServicesResult> getBookingServices() async {
    return const BookingServicesResult(
      breeds: [],
      packages: [],
      addOns: [],
      walkIn: mockWalkIn,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServiceRepository image URL resolution tests', () {
    test('resolveImageUrl rewrites localhost, 127.0.0.1, and 10.0.2.2 to BASE_URL', () {
      final base = Constants.app.BASE_URL;
      expect(
        ServiceRepository.resolveImageUrl('http://localhost:3464/services_img/svc_nail_trim.png'),
        equals('$base/services_img/svc_nail_trim.png'),
      );
      expect(
        ServiceRepository.resolveImageUrl('http://127.0.0.1:8000/services_img/svc_bath_blowdry.png'),
        equals('$base/services_img/svc_bath_blowdry.png'),
      );
      expect(
        ServiceRepository.resolveImageUrl('http://10.0.2.2:3464/services_img/svc_full_grooming.png'),
        equals('$base/services_img/svc_full_grooming.png'),
      );
    });

    test('resolveImageUrl resolves relative paths', () {
      final base = Constants.app.BASE_URL;
      expect(
        ServiceRepository.resolveImageUrl('/services_img/svc_nail_trim.png'),
        equals('$base/services_img/svc_nail_trim.png'),
      );
      expect(
        ServiceRepository.resolveImageUrl('services_img/svc_spa.png'),
        equals('$base/services_img/svc_spa.png'),
      );
    });

    test('resolveImageUrl preserves valid remote and asset URLs', () {
      expect(
        ServiceRepository.resolveImageUrl('https://devapi.shearheavenpetspa.com/services_img/svc_nail_trim.png'),
        equals('https://devapi.shearheavenpetspa.com/services_img/svc_nail_trim.png'),
      );
      expect(
        ServiceRepository.resolveImageUrl('assets/images/common/svc_nail_trim.png'),
        equals('assets/images/common/svc_nail_trim.png'),
      );
      expect(ServiceRepository.resolveImageUrl(null), isNull);
      expect(ServiceRepository.resolveImageUrl(''), isNull);
      expect(ServiceRepository.resolveImageUrl('null'), isNull);
    });

    test('liveServiceImageUrl returns BASE_URL services_img endpoints', () {
      final base = Constants.app.BASE_URL;
      expect(
        ServiceRepository.liveServiceImageUrl('Nail Trim'),
        equals('$base/services_img/svc_nail_trim.png'),
      );
      expect(
        ServiceRepository.liveServiceImageUrl('Bath & Blow Dry'),
        equals('$base/services_img/svc_bath_blowdry.png'),
      );
      expect(
        ServiceRepository.liveServiceImageUrl('Full Grooming'),
        equals('$base/services_img/svc_full_grooming.png'),
      );
      expect(
        ServiceRepository.liveServiceImageUrl('Ear Clean'),
        equals('$base/services_img/svc_ear_clean.png'),
      );
      expect(
        ServiceRepository.liveServiceImageUrl('Teeth Brushing'),
        equals('$base/services_img/svc_teeth_brush.png'),
      );
      expect(
        ServiceRepository.liveServiceImageUrl('Puppy Bath'),
        equals('$base/services_img/svc_puppy.png'),
      );
      expect(
        ServiceRepository.liveServiceImageUrl('De-Shedding Treatment'),
        equals('$base/services_img/svc_deshed.png'),
      );
    });
  });

  group('Customer Home Page Popular Services Image Display', () {
    setUpAll(() async {
      if (!serviceLocator.isRegistered<SessionService>()) {
        serviceLocator.registerSingleton<SessionService>(SessionService());
      }
      if (!serviceLocator.isRegistered<AuthRepository>()) {
        serviceLocator.registerSingleton<AuthRepository>(_FakeAuthRepo());
      }
      if (!serviceLocator.isRegistered<PetRepository>()) {
        serviceLocator.registerSingleton<PetRepository>(_FakePetRepo());
      }
      if (serviceLocator.isRegistered<ServiceRepository>()) {
        serviceLocator.unregister<ServiceRepository>();
      }
      serviceLocator.registerSingleton<ServiceRepository>(_FakeServiceRepoWithApiImages());
    });

    tearDownAll(() {
      if (serviceLocator.isRegistered<ServiceRepository>()) {
        serviceLocator.unregister<ServiceRepository>();
      }
      serviceLocator.registerSingleton<ServiceRepository>(ServiceRepository());
    });

    testWidgets('Popular services display API response images with resolved network URLs', (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => ResponsiveBreakpoints(
          breakpoints: const [
            Breakpoint(start: 0, end: 450, name: MOBILE),
            Breakpoint(start: 451, end: 800, name: TABLET),
            Breakpoint(start: 801, end: 1920, name: DESKTOP),
          ],
          child: child!,
        ),
        home: const HomePage(),
      ));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Popular Services'), 200, scrollable: scrollable);
      await tester.pumpAndSettle();

      // Verify all 4 popular service titles appear
      expect(find.text('Nail Trim'), findsOneWidget);
      expect(find.text('Nail Grind'), findsOneWidget);
      expect(find.text('Anal Glands'), findsOneWidget);
      expect(find.text('Face And Feet Trim'), findsOneWidget);

      // Verify that Image.network is used for the services with resolved URLs
      final networkImages = find.byType(Image).evaluate().where((element) {
        final widget = element.widget as Image;
        return widget.image is NetworkImage;
      }).toList();

      expect(networkImages.length, equals(4));

      final base = Constants.app.BASE_URL;
      final urls = networkImages.map((e) => ((e.widget as Image).image as NetworkImage).url).toList();
      expect(urls[0], equals('$base/services_img/svc_nail_trim.png'));
      expect(urls[1], equals('https://devapi.shearheavenpetspa.com/services_img/svc_nail_trim.png'));
      expect(urls[2], equals('$base/services_img/svc_ear_clean.png'));
      expect(urls[3], equals('https://api.shearheavenpetspa.com/services_img/svc_hair_trim.png'));
    });
  });
}
