import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/groomer_home_page.dart';

class _MockGroomerHomeRepo extends GroomerHomeRepository {
  @override
  Future<GroomerUser?> getProfile() async => const GroomerUser(
        id: 1,
        groomerCode: 'GR-001',
        firstName: 'Sarah',
        lastName: 'Jenkins',
        email: 'sarah@shearheaven.com',
        mobile: '1234567890',
        role: 'groomer',
      );

  @override
  Future<List<GroomerBooking>> getUpcomingBookings() async => [];

  @override
  Future<List<GroomerBooking>> getPendingBookings() async => [];

  @override
  Future<List<GroomerBooking>> getPastBookings() async => [];

  @override
  Future<List<GroomerBooking>> getCancelledBookings() async => [];

  @override
  Future<List<GroomerBooking>> getCancellationRequests() async => [];

  @override
  Future<List<StoreServiceHour>> getServiceHours({
    String? clientId,
    String? regionId,
    String? storeId,
  }) async => [];

  @override
  Future<List<StoreHoliday>> getHolidays({
    String? clientId,
    String? regionId,
    String? storeId,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async => [];

  @override
  Future<List<GroomerWorkingHour>> getGroomerHours({
    String? groomerCode,
    String? clientId,
    String? regionId,
    String? storeId,
  }) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
    if (serviceLocator.isRegistered<GroomerHomeRepository>()) {
      serviceLocator.unregister<GroomerHomeRepository>();
    }
    serviceLocator.registerSingleton<GroomerHomeRepository>(_MockGroomerHomeRepo());
  });

  testWidgets('Groomer app bar displays user name first and greeting second in small font', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
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
      home: const GroomerHomePage(),
    ));
    await tester.pumpAndSettle();

    // Verify User name is displayed first (Hi, Sarah)
    expect(find.text('Hi, Sarah'), findsOneWidget);

    // Verify Greeting is displayed on the second line (Good Morning / Good Afternoon / Good Evening)
    final hour = DateTime.now().hour;
    final expectedGreeting = hour < 12
        ? 'Good Morning'
        : (hour < 17 ? 'Good Afternoon' : 'Good Evening');
    expect(find.text(expectedGreeting), findsOneWidget);

    // Verify greeting text font size is 12.5 and color is grey #6B7280
    final greetingText = tester.widget<Text>(find.text(expectedGreeting));
    expect(greetingText.style?.fontSize, equals(12.5));
    expect(greetingText.style?.color, equals(const Color(0xFF6B7280)));

    // Verify user name text font size is 16 and bold
    final nameText = tester.widget<Text>(find.text('Hi, Sarah'));
    expect(nameText.style?.fontSize, equals(16));
    expect(nameText.style?.fontWeight, equals(FontWeight.w700));
  });
}
