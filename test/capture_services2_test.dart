import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
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
  static const mockServices = [
    ServiceItem(
      id: 1,
      isPackage: false,
      isAddOn: false,
      name: 'Full Grooming',
      description: 'Complete grooming service',
      price: 45.0,
      priceDisplay: '\$45.00',
      durationMinutes: 60,
    ),
    ServiceItem(
      id: 2,
      isPackage: false,
      isAddOn: false,
      name: 'Bath & Blow Dry',
      description: 'Clean bath & dry',
      price: 25.0,
      priceDisplay: '\$25.00',
      durationMinutes: 30,
    ),
    ServiceItem(
      id: 3,
      isPackage: false,
      isAddOn: false,
      name: 'Hair Trimming',
      description: 'Trim coat',
      price: 30.0,
      priceDisplay: '\$30.00',
      durationMinutes: 40,
    ),
    ServiceItem(
      id: 4,
      isPackage: false,
      isAddOn: false,
      name: 'Breed Styling',
      description: 'Style coat',
      price: 55.0,
      priceDisplay: '\$55.00',
      durationMinutes: 75,
    ),
  ];

  @override
  Future<BookingServicesResult> getBookingServices() async =>
      const BookingServicesResult(
        breeds: mockServices,
        packages: [],
        addOns: [],
        walkIn: [],
      );

  @override
  Future<List<Map<String, dynamic>>> getAllServices() async => [];
  @override
  Future<List<Map<String, dynamic>>> getAllPackages() async => [];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();

    final apiRepo = ApiRepository();
    await apiRepo.initialize();

    serviceLocator.allowReassignment = true;
    serviceLocator.registerSingleton<SessionService>(session);
    serviceLocator.registerSingleton<ApiRepository>(apiRepo);
    serviceLocator.registerSingleton<AuthRepository>(_FakeAuthRepository());
    serviceLocator.registerSingleton<PetRepository>(_FakePetRepository());
    serviceLocator.registerSingleton<ServiceRepository>(_FakeServiceRepository());
  });

  testWidgets('capture services grid', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
      home: const HomePage()));
    await GoogleFonts.pendingFonts();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: const HomePage()));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Full Grooming'), 200, scrollable: scrollable);
    await tester.pumpAndSettle();

    expect(find.text('Full Grooming'), findsOneWidget);
    expect(find.text('Hair Trimming'), findsOneWidget);
    expect(find.text('Bath & Blow Dry'), findsOneWidget);
    expect(find.text('Breed Styling'), findsOneWidget);
  });
}
