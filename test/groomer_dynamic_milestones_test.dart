import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_milestone_dialog.dart';

class _MockApiRepository extends ApiRepository {
  String? lastGetPath;
  Map<String, dynamic>? lastGetQuery;
  int getCallCount = 0;

  String? lastPostPath;
  dynamic lastPostData;
  Map<String, dynamic>? lastPostQuery;
  int postCallCount = 0;

  void reset() {
    lastGetPath = null;
    lastGetQuery = null;
    getCallCount = 0;
    lastPostPath = null;
    lastPostData = null;
    lastPostQuery = null;
    postCallCount = 0;
  }

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    lastGetPath = path;
    lastGetQuery = query;
    getCallCount++;
    if (path.contains('appointment-milestones')) {
      return {
        'success': true,
        'message': 'Appointment milestone catalog retrieved',
        'data': {
          'version': '1.1',
          'source': 'store',
          'milestones': [
            {
              'key': 'ready_for_check_in',
              'order': 1,
              'phase': 'pre_store',
              'action': 'AutoReadyForCheckIn',
              'status': 'ReadyForCheckIn',
              'serviceStage': 'confirmed',
              'groomerSelectable': false,
            },
            {
              'key': 'check_in_completed',
              'order': 2,
              'phase': 'in_store',
              'action': 'CheckInCompleted',
              'status': 'DogServiceInProgress',
              'serviceStage': 'checked_in',
              'groomerSelectable': true,
              'requiresCheckInPayload': true,
            },
            {
              'key': 'bath_completed',
              'order': 3,
              'phase': 'in_store',
              'action': 'CheckInCompleted',
              'status': 'BathCompleted',
              'serviceStage': 'bath_completed',
              'groomerSelectable': true,
            },
            {
              'key': 'grooming_in_progress',
              'order': 4,
              'phase': 'in_store',
              'action': 'CheckInCompleted',
              'status': 'GroomingInProgress',
              'serviceStage': 'bath_completed',
              'groomerSelectable': true,
            },
            {
              'key': 'grooming_completed',
              'order': 5,
              'phase': 'in_store',
              'action': 'CheckInCompleted',
              'status': 'GroomingCompleted',
              'serviceStage': 'grooming_completed',
              'groomerSelectable': true,
            },
            {
              'key': 'ready_for_checkout',
              'order': 6,
              'phase': 'in_store',
              'action': 'ServiceCompleted',
              'status': 'ReadyForCheckout',
              'serviceStage': 'ready_for_checkout',
              'groomerSelectable': true,
            },
            {
              'key': 'final_checkout',
              'order': 7,
              'phase': 'checkout',
              'action': 'EnterTipAndConfirm',
              'status': 'FinalCheckout',
              'serviceStage': 'ready_for_checkout',
              'groomerSelectable': false,
            },
            {
              'key': 'final_service_completed',
              'order': 8,
              'phase': 'checkout',
              'action': 'Checkout',
              'status': 'FinalServiceCompleted',
              'serviceStage': 'checkout_completed',
              'groomerSelectable': true,
              'requiresCheckoutPayload': true,
            },
            {
              'key': 'custom_step_9',
              'order': 9,
              'phase': 'in_store',
              'action': 'CustomStep',
              'status': 'welcome Back',
              'groomerSelectable': true,
            },
          ],
        },
      };
    }
    if (path.contains('/milestones')) {
      return {
        'success': true,
        'message': 'Appointment milestones retrieved',
        'data': {
          'appointmentId': 201,
          'storeId': 'SHEAR-001',
          'currentMilestoneKey': 'check_in_completed',
          'status': 'checked_in',
          'allowedNextKeys': ['bath_completed', 'grooming_in_progress', 'grooming_completed', 'ready_for_checkout'],
          'canSkipToReadyForCheckout': true,
          'milestones': [],
        },
      };
    }
    return {'success': true, 'data': {}};
  }

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPostPath = path;
    lastPostData = data;
    lastPostQuery = query;
    postCallCount++;
    final milestone = (data is Map) ? (data['milestone'] ?? data['milestoneKey']) : null;
    return {
      'success': true,
      'message': milestone == 'ready_for_checkout'
          ? 'Appointment marked as Ready for Checkout.'
          : 'Milestone updated successfully.',
      'data': {
        'status': milestone ?? 'ready_for_checkout',
        'milestone': milestone,
        'timestamp': '2026-10-17T11:00:00Z',
      },
    };
  }
}

late _MockApiRepository _mockApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();

    if (GetIt.I.isRegistered<ApiRepository>()) {
      GetIt.I.unregister<ApiRepository>();
    }
    _mockApi = _MockApiRepository();
    GetIt.I.registerSingleton<ApiRepository>(_mockApi);
  });

  setUp(() async {
    await ServicesLocator.sessionService.clearSession();
    await ServicesLocator.sessionService.clearGroomerSession();
    await ServicesLocator.sessionService.saveGroomerUser({
      'id': 10,
      'name': 'Groomer Alex',
      'email': 'alex@groomer.com',
    });
  });

  group('Dynamic Milestone Steps Based on Selected Services', () {
    // ─────────────────────────────────────────────────────────────────────────
    // Test 1: Single service requiring only specific milestones
    // ─────────────────────────────────────────────────────────────────────────
    test('1. Single service requiring only specific milestones', () {
      // Bath-Only Service: Small Dog Bathing (serviceId: 2)
      final bathBooking = const GroomerBooking(
        bookingId: 101,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '09:00 AM',
        endTime: '09:30 AM',
        petName: 'Milo',
        customerName: 'Alice',
        serviceId: 2,
        serviceName: 'Small Dog (Under 20 lbs) — Bathing',
        groomerId: 10,
      );

      expect(bathBooking.requiredMilestones, equals(['bath_completed']));
      expect(bathBooking.requiresBath, isTrue);
      expect(bathBooking.requiresGrooming, isFalse);
      expect(bathBooking.canCompleteBath, isTrue);
      expect(bathBooking.canCompleteGrooming, isFalse);

      // Grooming-Only Service: Small Dog Grooming (serviceId: 1)
      final groomingBooking = const GroomerBooking(
        bookingId: 102,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Luna',
        customerName: 'Bob',
        serviceId: 1,
        serviceName: 'Small Dog (Under 20 lbs) — Grooming',
        groomerId: 10,
      );

      expect(groomingBooking.requiredMilestones, equals(['grooming_completed']));
      expect(groomingBooking.requiresBath, isFalse);
      expect(groomingBooking.requiresGrooming, isTrue);
      expect(groomingBooking.canCompleteBath, isFalse);
      expect(groomingBooking.canCompleteGrooming, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 2: Multiple services sharing common milestones without duplicates
    // ─────────────────────────────────────────────────────────────────────────
    test('2. Multiple services sharing common milestones without duplicates', () {
      // Bath service (serviceId: 2) + Medicated Bath (addOnId: 7) + Flea Bath (addOnId: 4)
      final sharedBathBooking = const GroomerBooking(
        bookingId: 103,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        petName: 'Cooper',
        customerName: 'Charlie',
        serviceId: 2,
        serviceName: 'Small Dog (Under 20 lbs) — Bathing',
        addOnIds: [7, 4],
        addOns: ['Medicated Bath', 'Flea Bath'],
        groomerId: 10,
      );

      // Must combine without duplicate 'bath_completed'
      expect(sharedBathBooking.requiredMilestones, equals(['bath_completed']));
      expect(sharedBathBooking.requiredMilestones.length, 1);
      expect(sharedBathBooking.requiresBath, isTrue);
      expect(sharedBathBooking.requiresGrooming, isFalse);

      // Grooming service (serviceId: 1) + Scissoring (addOnId: 12) + Furminator (addOnId: 5)
      final sharedGroomingBooking = const GroomerBooking(
        bookingId: 104,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        petName: 'Bella',
        customerName: 'David',
        serviceId: 1,
        serviceName: 'Small Dog (Under 20 lbs) — Grooming',
        addOnIds: [12, 5],
        addOns: ['Scissoring', 'Furminator'],
        groomerId: 10,
      );

      // Must combine without duplicate 'grooming_completed'
      expect(sharedGroomingBooking.requiredMilestones, equals(['grooming_completed']));
      expect(sharedGroomingBooking.requiredMilestones.length, 1);
      expect(sharedGroomingBooking.requiresBath, isFalse);
      expect(sharedGroomingBooking.requiresGrooming, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 3: Different service combinations producing different milestone step lists
    // ─────────────────────────────────────────────────────────────────────────
    test('3. Different service combinations produce distinct, ordered milestone lists', () {
      // Combination A: Grooming & Bathing Service (serviceId: 3)
      final comboBooking = const GroomerBooking(
        bookingId: 105,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '01:00 PM',
        endTime: '02:30 PM',
        petName: 'Rocky',
        customerName: 'Emma',
        serviceId: 3,
        serviceName: 'Small Dog (Under 20 lbs) — Grooming & Bathing',
        groomerId: 10,
      );
      expect(comboBooking.requiredMilestones, equals(['bath_completed', 'grooming_completed']));

      // Combination B: Bath service (serviceId: 2) + Nail Grinding grooming add-on (addOnId: 1)
      final bathWithGroomAddon = const GroomerBooking(
        bookingId: 106,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        petName: 'Daisy',
        customerName: 'Frank',
        serviceId: 2,
        serviceName: 'Small Dog (Under 20 lbs) — Bathing',
        addOnIds: [1],
        addOns: ['Nail Grinding'],
        groomerId: 10,
      );
      expect(bathWithGroomAddon.requiredMilestones, equals(['bath_completed', 'grooming_completed']));

      // Combination C: Walk-in Hair Trimming (serviceId: 12)
      final trimBooking = const GroomerBooking(
        bookingId: 107,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '03:00 PM',
        endTime: '03:30 PM',
        petName: 'Max',
        customerName: 'Grace',
        serviceId: 12,
        serviceName: 'Hair Trimming',
        groomerId: 10,
      );
      expect(trimBooking.requiredMilestones, equals(['grooming_completed']));

      // Combination D: Package (packageId: 1 "Spa Package")
      final packageBooking = const GroomerBooking(
        bookingId: 108,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '04:00 PM',
        endTime: '05:30 PM',
        petName: 'Teddy',
        customerName: 'Hannah',
        serviceName: 'Spa Package',
        packageId: 1,
        packageName: 'Spa Package',
        groomerId: 10,
      );
      expect(packageBooking.requiredMilestones, equals(['bath_completed', 'grooming_completed']));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 4: Completing milestones sequentially, closing and reopening dialog preserves progress
    // ─────────────────────────────────────────────────────────────────────────
    test('4. Sequential completion and reopening dialog preserves milestone progress', () async {
      final initialBooking = const GroomerBooking(
        bookingId: 109,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '09:00 AM',
        endTime: '10:30 AM',
        petName: 'Charlie',
        customerName: 'Ian',
        serviceId: 3,
        serviceName: 'Small Dog (Under 20 lbs) — Grooming & Bathing',
        groomerId: 10,
      );

      expect(initialBooking.isBathCompleted, isFalse);
      expect(initialBooking.isGroomingCompleted, isFalse);
      expect(initialBooking.nextPendingMilestone, 'bath_completed');

      // Complete Bath milestone
      final bathResult = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: initialBooking.bookingId,
        milestone: 'bath_completed',
        notes: 'Hypoallergenic shampoo applied',
        booking: initialBooking,
      );

      expect(bathResult.success, isTrue);
      final bookingAfterBath = bathResult.updatedBooking!;
      expect(bookingAfterBath.isBathCompleted, isTrue);
      expect(bookingAfterBath.bathNotes, 'Hypoallergenic shampoo applied');
      expect(bookingAfterBath.isGroomingCompleted, isFalse);
      expect(bookingAfterBath.nextPendingMilestone, 'grooming_completed');
      expect(bookingAfterBath.canCompleteGrooming, isTrue);

      // Simulate closing and reopening dialog: progress persists on reopening
      final reopenedBooking = GroomerBooking.fromJson(bookingAfterBath.toJson());
      expect(reopenedBooking.isBathCompleted, isTrue);
      expect(reopenedBooking.bathNotes, 'Hypoallergenic shampoo applied');
      expect(reopenedBooking.completedRequiredMilestones, contains('bath_completed'));
      expect(reopenedBooking.pendingRequiredMilestones, equals(['grooming_completed']));

      // Complete Grooming milestone
      final groomingResult = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: reopenedBooking.bookingId,
        milestone: 'grooming_completed',
        notes: 'Teddy bear face trim complete',
        booking: reopenedBooking,
      );

      expect(groomingResult.success, isTrue);
      final bookingAfterGrooming = groomingResult.updatedBooking!;
      expect(bookingAfterGrooming.isBathCompleted, isTrue);
      expect(bookingAfterGrooming.isGroomingCompleted, isTrue);
      expect(bookingAfterGrooming.groomingNotes, 'Teddy bear face trim complete');
      expect(bookingAfterGrooming.areRequiredMilestonesCompleted, isTrue);
      expect(bookingAfterGrooming.nextPendingMilestone, isNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 5: Incomplete required milestones prevent Ready for Checkout
    // ─────────────────────────────────────────────────────────────────────────
    test('5. Incomplete required milestones prevent Ready for Checkout', () async {
      // Case 5A: Combo service with no milestones completed
      final incompleteCombo = const GroomerBooking(
        bookingId: 110,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '10:00 AM',
        endTime: '11:30 AM',
        petName: 'Bailey',
        customerName: 'Jack',
        serviceId: 3,
        serviceName: 'Small Dog (Under 20 lbs) — Grooming & Bathing',
        groomerId: 10,
      );

      expect(incompleteCombo.canMarkReadyForCheckout, isFalse);
      final res5A = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: incompleteCombo.bookingId,
        booking: incompleteCombo,
      );
      expect(res5A.success, isFalse);
      expect(res5A.message, contains('Bath and Grooming must be completed'));

      // Case 5B: Combo service with only Bath completed (Grooming pending)
      final bathDoneOnly = incompleteCombo.copyWith(
        status: 'bath_completed',
        milestoneRecord: const GroomerMilestoneRecord(bathCompleted: true),
      );

      expect(bathDoneOnly.canMarkReadyForCheckout, isFalse);
      final res5B = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: bathDoneOnly.bookingId,
        booking: bathDoneOnly,
      );
      expect(res5B.success, isFalse);
      expect(res5B.message, contains('Grooming must be completed'));

      // Case 5C: Bath-only service with Bath NOT completed
      final bathOnlyIncomplete = const GroomerBooking(
        bookingId: 111,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '11:00 AM',
        endTime: '11:30 AM',
        petName: 'Coco',
        customerName: 'Kate',
        serviceId: 2,
        serviceName: 'Small Dog (Under 20 lbs) — Bathing',
        groomerId: 10,
      );

      expect(bathOnlyIncomplete.canMarkReadyForCheckout, isFalse);
      final res5C = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: bathOnlyIncomplete.bookingId,
        booking: bathOnlyIncomplete,
      );
      expect(res5C.success, isFalse);
      expect(res5C.message, contains('Bath must be completed'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 6: Ready for Checkout eligibility unlocked as soon as all required milestones are completed
    // ─────────────────────────────────────────────────────────────────────────
    test('6. Ready for Checkout unlocked as soon as all required milestones are completed', () async {
      // 6A: Bath-only service after completing Bath
      final bathOnlyBooking = const GroomerBooking(
        bookingId: 112,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '01:00 PM',
        endTime: '01:30 PM',
        petName: 'Zoe',
        customerName: 'Leo',
        serviceId: 2,
        serviceName: 'Small Dog (Under 20 lbs) — Bathing',
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true),
        groomerId: 10,
      );

      expect(bathOnlyBooking.areRequiredMilestonesCompleted, isTrue);
      expect(bathOnlyBooking.canMarkReadyForCheckout, isTrue);

      final res6A = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: bathOnlyBooking.bookingId,
        booking: bathOnlyBooking,
      );
      expect(res6A.success, isTrue);
      expect(res6A.updatedBooking?.status, 'ready_for_checkout');

      // 6B: Grooming-only service after completing Grooming
      final groomingOnlyBooking = const GroomerBooking(
        bookingId: 113,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '02:00 PM',
        endTime: '02:45 PM',
        petName: 'Rusty',
        customerName: 'Mia',
        serviceId: 1,
        serviceName: 'Small Dog (Under 20 lbs) — Grooming',
        milestoneRecord: GroomerMilestoneRecord(groomingCompleted: true),
        groomerId: 10,
      );

      expect(groomingOnlyBooking.areRequiredMilestonesCompleted, isTrue);
      expect(groomingOnlyBooking.canMarkReadyForCheckout, isTrue);

      final res6B = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: groomingOnlyBooking.bookingId,
        booking: groomingOnlyBooking,
      );
      expect(res6B.success, isTrue);
      expect(res6B.updatedBooking?.status, 'ready_for_checkout');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 7: Missing or invalid service data falls back gracefully
    // ─────────────────────────────────────────────────────────────────────────
    test('7. Missing or invalid service data falls back gracefully to standard milestones', () {
      // Null serviceId and empty addOns
      final missingDataBooking = const GroomerBooking(
        bookingId: 114,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '03:00 PM',
        endTime: '04:00 PM',
        petName: 'Buddy',
        customerName: 'Noah',
        serviceName: 'General Appointment',
        groomerId: 10,
      );

      expect(missingDataBooking.requiredMilestones, equals(['bath_completed', 'grooming_completed']));
      expect(missingDataBooking.requiresBath, isTrue);
      expect(missingDataBooking.requiresGrooming, isTrue);

      // Unrecognized negative serviceId
      final invalidIdBooking = const GroomerBooking(
        bookingId: 115,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '04:00 PM',
        endTime: '05:00 PM',
        petName: 'Toby',
        customerName: 'Olivia',
        serviceId: -99,
        serviceName: 'Special Custom Service',
        groomerId: 10,
      );

      expect(invalidIdBooking.requiredMilestones, equals(['bath_completed', 'grooming_completed']));
      expect(invalidIdBooking.requiresBath, isTrue);
      expect(invalidIdBooking.requiresGrooming, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Widget Test: GroomerMilestoneDialog renders dynamic stages matching services
    // ─────────────────────────────────────────────────────────────────────────
    testWidgets('GroomerMilestoneDialog renders only applicable milestone stages', (tester) async {
      // Bath-Only booking
      final bathBooking = const GroomerBooking(
        bookingId: 201,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '09:00 AM',
        endTime: '09:30 AM',
        petName: 'Sparky',
        customerName: 'Paul',
        serviceId: 2,
        serviceName: 'Small Dog (Under 20 lbs) — Bathing',
        groomerId: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroomerMilestoneDialog(
              booking: bathBooking,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // For bath-only: Bath is present in the stage tracker, Grooming is NOT in the stage tracker
      expect(find.text('Bath Completed'), findsWidgets);
      expect(find.text('Confirm Bath Completed'), findsOneWidget);
      expect(find.text('Grooming Completed'), findsNothing);
      expect(find.text('Confirm Grooming Completed'), findsNothing);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 8: Store milestone catalog fetches and caches store-based configuration
    // ─────────────────────────────────────────────────────────────────────────
    test('8. Store milestone catalog fetches and caches store-based configuration', () async {
      _mockApi.reset();

      // First fetch with forceRefresh loads from API
      final catalog = await ServicesLocator.groomerHomeRepository.getMilestonesCatalog(
        storeId: 'SHEAR-001',
        forceRefresh: true,
      );
      expect(catalog.isNotEmpty, isTrue);
      expect(_mockApi.lastGetPath, contains('appointment-milestones'));
      expect(_mockApi.getCallCount, 1);

      // Verify returned configs
      expect(catalog.any((m) => m.key == 'check_in_completed'), isTrue);
      expect(catalog.any((m) => m.key == 'bath_completed'), isTrue);
      expect(catalog.any((m) => m.key == 'grooming_completed'), isTrue);
      expect(catalog.any((m) => m.key == 'ready_for_checkout'), isTrue);

      // Second call uses cached catalog (no extra network call)
      final cachedCatalog = await ServicesLocator.groomerHomeRepository.getMilestonesCatalog(storeId: 'SHEAR-001');
      expect(cachedCatalog.length, catalog.length);
      expect(_mockApi.getCallCount, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 9: In-store milestone filtering strictly excludes pre-store, customer actions, and final checkout
    // ─────────────────────────────────────────────────────────────────────────
    test('9. In-store milestone filtering strictly excludes pre-store, customer actions, and final checkout', () async {
      final catalog = await ServicesLocator.groomerHomeRepository.getMilestonesCatalog(storeId: 'SHEAR-001');

      // Pre-store milestone
      final preStore = catalog.firstWhere((m) => m.key == 'ready_for_check_in');
      expect(preStore.isInStoreAction, isFalse);
      expect(preStore.phase, 'pre_store');

      // Customer tip action
      final customerAction = catalog.firstWhere((m) => m.key == 'final_checkout');
      expect(customerAction.isInStoreAction, isFalse);
      expect(customerAction.isCustomerAction, isTrue);

      // Final checkout action
      final finalCheckout = catalog.firstWhere((m) => m.key == 'final_service_completed');
      expect(finalCheckout.isInStoreAction, isFalse);
      expect(finalCheckout.isFinalCheckoutAction, isTrue);

      // In-store actions
      final inStoreActions = catalog.where((m) => m.isInStoreAction).toList();
      final inStoreKeys = inStoreActions.map((m) => m.key).toList();
      expect(inStoreKeys, contains('check_in_completed'));
      expect(inStoreKeys, contains('bath_completed'));
      expect(inStoreKeys, contains('grooming_completed'));
      expect(inStoreKeys, contains('ready_for_checkout'));
      expect(inStoreKeys, contains('custom_step_9'));
      expect(inStoreKeys, isNot(contains('ready_for_check_in')));
      expect(inStoreKeys, isNot(contains('final_checkout')));
      expect(inStoreKeys, isNot(contains('final_service_completed')));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 10: Update Milestone API sends full contract payload
    // ─────────────────────────────────────────────────────────────────────────
    test('10. Update Milestone API sends storeId, milestoneKey, action, status, milestoneDateTime, and notes', () async {
      _mockApi.reset();
      const checkedInBooking = GroomerBooking(
        bookingId: 301,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rusty',
        customerName: 'Sam',
        serviceId: 2,
        serviceName: 'Small Dog (Under 20 lbs) — Bathing',
        storeId: 'SHEAR-001',
        groomerId: 10,
      );

      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: checkedInBooking.bookingId,
        milestone: 'bath_completed',
        action: 'CheckInCompleted',
        status: 'BathCompleted',
        notes: 'Organic lavender wash used',
        booking: checkedInBooking,
        storeId: 'SHEAR-001',
      );

      expect(res.success, isTrue);
      expect(_mockApi.lastPostPath, '/api/common/groomer/bookings/301/milestone');
      expect(_mockApi.lastPostData, isA<Map<String, dynamic>>());
      final payload = _mockApi.lastPostData as Map<String, dynamic>;
      expect(payload['storeId'], 'SHEAR-001');
      expect(payload['milestoneKey'], 'bath_completed');
      expect(payload['action'], 'CheckInCompleted');
      expect(payload['status'], 'BathCompleted');
      expect(payload['notes'], 'Organic lavender wash used');
      expect(payload['milestoneDateTime'], isNotNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 11: Mandatory check-in prevents updating service milestones when unverified
    // ─────────────────────────────────────────────────────────────────────────
    test('11. Mandatory check-in rule prevents updating service milestones before check-in is complete', () async {
      const confirmedBooking = GroomerBooking(
        bookingId: 302,
        status: 'confirmed',
        bookingDate: '2026-10-17',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        petName: 'Bella',
        customerName: 'Claire',
        serviceId: 2,
        serviceName: 'Small Dog (Under 20 lbs) — Bathing',
        storeId: 'SHEAR-001',
        groomerId: 10,
      );

      expect(confirmedBooking.isCheckedIn, isFalse);

      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: confirmedBooking.bookingId,
        milestone: 'bath_completed',
        action: 'CheckInCompleted',
        status: 'BathCompleted',
        booking: confirmedBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('Check-in must be completed before updating service milestones.'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 12: Skipping intermediate milestones sends skipMilestones: true in payload
    // ─────────────────────────────────────────────────────────────────────────
    test('12. Skipping intermediate milestones sends skipMilestones: true in payload', () async {
      _mockApi.reset();
      const inProgressBooking = GroomerBooking(
        bookingId: 303,
        status: 'in_progress',
        bookingDate: '2026-10-17',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        petName: 'Milo',
        customerName: 'Oliver',
        serviceId: 3,
        serviceName: 'Small Dog (Under 20 lbs) — Grooming & Bathing',
        storeId: 'SHEAR-001',
        groomerId: 10,
      );

      // Bath and grooming are pending, but groomer skips directly to ready for checkout
      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: inProgressBooking.bookingId,
        booking: inProgressBooking,
        skipMilestones: true,
        notes: 'Owner requested early pickup; skipping groom step',
      );

      expect(res.success, isTrue);
      expect(_mockApi.lastPostPath, '/api/common/groomer/bookings/303/milestone');
      final payload = _mockApi.lastPostData as Map<String, dynamic>;
      expect(payload['milestoneKey'], 'ready_for_checkout');
      expect(payload['payload'], isA<Map>());
      expect(payload['payload']['skipMilestones'], isTrue);
    });
  });
}
