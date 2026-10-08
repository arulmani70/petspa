import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_service_page.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

import 'package:get_it/get_it.dart';

class MockServiceRepository extends ServiceRepository {
  @override
  Future<BookingServicesResult> getBookingServices() async {
    return BookingServicesResult(
      breeds: [
        ServiceItem(
          id: 1, isPackage: false, isAddOn: false,
          name: 'Breed 1', description: '',
          price: 10, priceDisplay: r'$10', durationMinutes: 10,
        ),
      ],
      packages: [
        ServiceItem(
          id: 1, isPackage: true, isAddOn: false,
          name: 'Package 1', description: '',
          price: 10, priceDisplay: r'$10', durationMinutes: 10,
        ),
      ],
      addOns: [
        ServiceItem(
          id: 1, isPackage: false, isAddOn: true,
          name: 'Addon 1', description: '',
          price: 10, priceDisplay: r'$10', durationMinutes: 10,
        ),
      ],
      walkIn: [],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    GetIt.instance.allowReassignment = true;
    
    final sessionService = SessionService();
    await sessionService.initialize();
    await sessionService.saveClientId('client_1');
    await sessionService.saveRegionId('region_1');
    await sessionService.saveStoreId('store_1');
    GetIt.instance.registerSingleton<SessionService>(sessionService);

    GetIt.instance.registerSingleton<ServiceRepository>(MockServiceRepository());
    GetIt.instance.registerSingleton<BookingDraft>(BookingDraft());
  });

  Widget buildTestWidget() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const BookingServicePage(),
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
    );
  }

  testWidgets('Breed section is visible for new bookings', (WidgetTester tester) async {
    final draft = ServicesLocator.bookingDraft;
    draft.reset(); // newBooking state

    await tester.pumpWidget(buildTestWidget());
    
    // Wait for the async _loadData to complete
    await tester.pumpAndSettle();

    // The text 'Breed' should exist
    expect(find.text('Breed'), findsWidgets);
    expect(find.text('Packages'), findsWidgets);
    expect(find.textContaining('Add-On'), findsWidgets);
  });

  testWidgets('Breed section is visible when pet is pre-selected', (WidgetTester tester) async {
    final draft = ServicesLocator.bookingDraft;
    draft.setPet({'pet_id': '123', 'pet_name': 'Teddy'}); // existingPet state

    await tester.pumpWidget(buildTestWidget());
    
    // Wait for the async _loadData to complete
    await tester.pumpAndSettle();

    // The Breed tab should still be available for breed selection
    expect(find.text('Breed'), findsWidgets);
    expect(find.text('Packages'), findsWidgets);
    expect(find.textContaining('Add-On'), findsWidgets);
  });

  testWidgets('Breed section remains accessible on state change', (WidgetTester tester) async {
    final draft = ServicesLocator.bookingDraft;
    draft.reset(); // start with newBooking

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Breed should be visible
    expect(find.text('Breed'), findsWidgets);

    // Simulate pre-selecting a pet dynamically
    draft.setPet({'pet_id': '123', 'pet_name': 'Teddy'});
    
    // Pump frames so ListenableBuilder reacts
    await tester.pumpAndSettle();

    // Breed tab remains accessible
    expect(find.text('Breed'), findsWidgets);
    expect(find.text('Packages'), findsWidgets);

    // Simulate resetting the pet
    draft.reset();
    
    await tester.pumpAndSettle();
    
    // Breed should remain visible
    expect(find.text('Breed'), findsWidgets);
  });
}
