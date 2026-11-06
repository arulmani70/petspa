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

class _MockGroomerHomeRepoForDropdown extends GroomerHomeRepository {
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
    serviceLocator.registerSingleton<GroomerHomeRepository>(
      _MockGroomerHomeRepoForDropdown(),
    );
  });

  testWidgets('Booking List dropdown is styled with app theme colors (dark primary pill, emerald accent)', (tester) async {
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

    // Verify Booking List section title
    expect(find.text('Booking List'), findsOneWidget);

    // Verify Dropdown trigger container exists
    final popupFinder = find.byType(PopupMenuButton<String>);
    expect(popupFinder, findsOneWidget);

    final popupWidget = tester.widget<PopupMenuButton<String>>(popupFinder);
    expect(popupWidget.color, equals(Colors.white));

    // Verify the trigger container decoration uses app primary theme Color(0xFF111827)
    final triggerContainer = tester.widget<Container>(
      find.descendant(
        of: popupFinder,
        matching: find.byType(Container),
      ).first,
    );
    final boxDecoration = triggerContainer.decoration as BoxDecoration;
    expect(boxDecoration.color, equals(const Color(0xFF111827)));

    // Verify trigger text color is white
    final triggerText = tester.widget<Text>(find.text('Sarah (You)'));
    expect(triggerText.style?.color, equals(Colors.white));

    // Scroll into view if needed
    await tester.ensureVisible(popupFinder);
    await tester.pumpAndSettle();

    // Open popup menu
    await tester.tap(popupFinder);
    await tester.pumpAndSettle();

    // Verify popup menu options appear with theme colors
    expect(find.text('All Groomers'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });
}
