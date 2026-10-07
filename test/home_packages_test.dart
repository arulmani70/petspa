import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/home/views/home_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => {'id': 1, 'name': 'Alexander'};
}

class _FakePetRepository extends PetRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => [];
}

class _FakeServiceRepository extends ServiceRepository {
  static const mockPackages = [
    ServiceItem(
      id: 10,
      isPackage: true,
      isAddOn: false,
      name: 'Small Breed',
      description: 'Package for small breeds',
      price: 60.0,
      priceDisplay: '\$60.00',
      durationMinutes: 60,
    ),
    ServiceItem(
      id: 11,
      isPackage: true,
      isAddOn: false,
      name: 'Medium Breed',
      description: 'Package for medium breeds',
      price: 80.0,
      priceDisplay: '\$80.00',
      durationMinutes: 75,
    ),
    ServiceItem(
      id: 12,
      isPackage: true,
      isAddOn: false,
      name: 'Large Breed',
      description: 'Package for large breeds',
      price: 100.0,
      priceDisplay: '\$100.00',
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
        walkIn: [],
      );
}

void main() {
  setUpAll(() {
    if (!serviceLocator.isRegistered<SessionService>()) {
      serviceLocator.registerSingleton<SessionService>(SessionService());
    }
    if (!serviceLocator.isRegistered<AuthRepository>()) {
      serviceLocator.registerSingleton<AuthRepository>(_FakeAuthRepository());
    }
    if (!serviceLocator.isRegistered<PetRepository>()) {
      serviceLocator.registerSingleton<PetRepository>(_FakePetRepository());
    }
    if (!serviceLocator.isRegistered<ServiceRepository>()) {
      serviceLocator.registerSingleton<ServiceRepository>(_FakeServiceRepository());
    }
  });

  testWidgets('home Popular Packages shows the Figma cards regardless of repo data', (tester) async {
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
    await tester.scrollUntilVisible(find.text('Medium Breed'), 200, scrollable: scrollable);
    await tester.pumpAndSettle();

    expect(find.text('Small Breed'), findsOneWidget);
    expect(find.text('Medium Breed'), findsOneWidget);
    expect(find.text('Large Breed'), findsOneWidget);
    expect(find.text('\$60.00'), findsOneWidget);
    expect(find.text('\$80.00'), findsOneWidget);
    expect(find.text('\$100.00'), findsOneWidget);
  });
}
