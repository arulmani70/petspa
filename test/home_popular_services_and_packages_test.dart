import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
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

class _FakeServiceRepo extends ServiceRepository {
  static const mockWalkIn = [
    ServiceItem(
      id: 1,
      isPackage: false,
      isAddOn: false,
      name: 'Nail Trimming',
      description: '', // Empty description to test fallback
      price: 15.0,
      priceDisplay: '\$15.00',
      durationMinutes: 15,
    ),
    ServiceItem(
      id: 2,
      isPackage: false,
      isAddOn: false,
      name: 'Ear Cleaning',
      description: 'Hygienic ear check & gentle cleansing',
      price: 12.0,
      priceDisplay: '\$12.00',
      durationMinutes: 15,
    ),
    ServiceItem(
      id: 3,
      isPackage: false,
      isAddOn: false,
      name: 'Teeth Brushing',
      description: '',
      price: 10.0,
      priceDisplay: '\$10.00',
      durationMinutes: 10,
    ),
    ServiceItem(
      id: 4,
      isPackage: false,
      isAddOn: false,
      name: 'Full Grooming',
      description: 'Full head-to-paw grooming & styling',
      price: 45.0,
      priceDisplay: '\$45.00',
      durationMinutes: 60,
    ),
  ];

  static const mockPackages = [
    ServiceItem(
      id: 10,
      isPackage: true,
      isAddOn: false,
      name: 'Small Breed Spa',
      description: 'Complete luxury package for small dogs',
      price: 60.0,
      priceDisplay: '\$60.00',
      durationMinutes: 60,
    ),
    ServiceItem(
      id: 11,
      isPackage: true,
      isAddOn: false,
      name: 'Medium Breed Spa',
      description: 'Pampering bath and haircut',
      price: 80.0,
      priceDisplay: '\$80.00',
      durationMinutes: 75,
    ),
    ServiceItem(
      id: 12,
      isPackage: true,
      isAddOn: false,
      name: 'Large Breed Spa',
      description: 'Full treatment for large pets',
      price: 110.0,
      priceDisplay: '\$110.00',
      durationMinutes: 90,
    ),
  ];

  @override
  Future<List<Map<String, dynamic>>> getAllServices() async => [];

  @override
  Future<List<Map<String, dynamic>>> getAllPackages() async => [];

  @override
  Future<BookingServicesResult> getBookingServices() async =>
      const BookingServicesResult(
        breeds: [],
        packages: mockPackages,
        addOns: [],
        walkIn: mockWalkIn,
      );
}

void main() {
  setUpAll(() {
    if (!serviceLocator.isRegistered<SessionService>()) {
      serviceLocator.registerSingleton<SessionService>(SessionService());
    }
    if (!serviceLocator.isRegistered<AuthRepository>()) {
      serviceLocator.registerSingleton<AuthRepository>(_FakeAuthRepo());
    }
    if (!serviceLocator.isRegistered<PetRepository>()) {
      serviceLocator.registerSingleton<PetRepository>(_FakePetRepo());
    }
    if (!serviceLocator.isRegistered<ServiceRepository>()) {
      serviceLocator.registerSingleton<ServiceRepository>(_FakeServiceRepo());
    }
  });

  testWidgets('Popular services display titles and short descriptions below titles', (tester) async {
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

    // Verify Popular Services title
    expect(find.text('Popular Services'), findsOneWidget);

    // Verify service card titles
    expect(find.text('Nail Trimming'), findsOneWidget);
    expect(find.text('Ear Cleaning'), findsOneWidget);
    expect(find.text('Teeth Brushing'), findsOneWidget);
    expect(find.text('Full Grooming'), findsOneWidget);

    // Verify short descriptions below titles (including fallbacks)
    expect(find.text('Safe and gentle paw nail trimming'), findsOneWidget);
    expect(find.text('Hygienic ear check & gentle cleansing'), findsOneWidget);
    expect(find.text('Oral hygiene & breath freshening'), findsOneWidget);
    expect(find.text('Full head-to-paw grooming & styling'), findsOneWidget);
  });

  testWidgets('Popular package all cards display package_banner.png background', (tester) async {
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
    await tester.scrollUntilVisible(find.text('Popular Packages'), 200, scrollable: scrollable);
    await tester.pumpAndSettle();

    expect(find.text('Popular Packages'), findsOneWidget);
    expect(find.text('Small Breed Spa'), findsOneWidget);
    expect(find.text('Medium Breed Spa'), findsOneWidget);
    expect(find.text('Large Breed Spa'), findsOneWidget);

    final imageFinder = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/packages/package_banner.png');
    expect(imageFinder, findsNWidgets(3));
  });
}
