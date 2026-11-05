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

class _DropdownMockApiRepository extends ApiRepository {
  String? lastMilestoneKey;
  String? lastNotes;
  int milestonePostCount = 0;

  void reset() {
    lastMilestoneKey = null;
    lastNotes = null;
    milestonePostCount = 0;
  }

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path.contains('appointment-milestones')) {
      return {
        'success': true,
        'message': 'Milestones catalog',
        'data': {
          'milestones': [
            {
              'key': 'ready_for_check_in',
              'order': 1,
              'phase': 'pre_store',
              'action': 'ReadyForCheckIn',
              'status': 'ReadyForCheckIn',
              'groomerSelectable': false,
            },
            {
              'key': 'check_in_completed',
              'order': 2,
              'phase': 'in_store',
              'action': 'CheckInCompleted',
              'status': 'CheckedIn',
              'groomerSelectable': true,
            },
            {
              'key': 'bath_completed',
              'order': 3,
              'phase': 'in_store',
              'action': 'BathCompleted',
              'status': 'BathCompleted',
              'groomerSelectable': true,
            },
            {
              'key': 'grooming_completed',
              'order': 4,
              'phase': 'in_store',
              'action': 'GroomingCompleted',
              'status': 'GroomingCompleted',
              'groomerSelectable': true,
            },
            {
              'key': 'ready_for_checkout',
              'order': 5,
              'phase': 'in_store',
              'action': 'ReadyForCheckout',
              'status': 'ReadyForCheckout',
              'groomerSelectable': true,
            },
          ]
        }
      };
    }

    if (path.contains('/milestones')) {
      if (path.contains('/902')) {
        return {
          'success': true,
          'data': {
            'appointmentId': 902,
            'storeId': 'SHEAR-001',
            'currentMilestoneKey': 'ready_for_check_in',
            'serviceStage': 'confirmed',
            'milestones': [
              {'milestoneKey': 'ready_for_check_in', 'completed': true, 'groomerSelectable': false},
              {'milestoneKey': 'check_in_completed', 'completed': false, 'groomerSelectable': true},
            ],
          }
        };
      }

      return {
        'success': true,
        'data': {
          'appointmentId': 901,
          'storeId': 'SHEAR-001',
          'currentMilestoneKey': 'check_in_completed',
          'serviceStage': 'in_progress',
          'groomerMilestoneOptions': [
            {'key': 'bath_completed', 'label': 'Bath Completed', 'completed': false},
            {'key': 'grooming_completed', 'label': 'Grooming Completed', 'completed': false},
            {'key': 'ready_for_checkout', 'label': 'Ready for Checkout', 'completed': false},
          ],
          'milestones': [
            {'milestoneKey': 'check_in_completed', 'completed': true, 'groomerSelectable': true},
            {'milestoneKey': 'bath_completed', 'completed': false, 'groomerSelectable': true},
            {'milestoneKey': 'grooming_completed', 'completed': false, 'groomerSelectable': true},
            {'milestoneKey': 'ready_for_checkout', 'completed': false, 'groomerSelectable': true},
          ],
        }
      };
    }

    if (path.contains('shop-groomers')) {
      return {
        'success': true,
        'data': [
          {'id': 10, 'name': 'Groomer Alex'},
        ]
      };
    }

    return {'success': true, 'data': {}};
  }

  @override
  Future<Map<String, dynamic>?> post(
    String path,
    dynamic data, {
    Map<String, dynamic>? query,
  }) async {
    if (path.contains('/milestone')) {
      milestonePostCount++;
      if (data is Map) {
        lastMilestoneKey = data['milestoneKey']?.toString() ?? data['milestone']?.toString();
        lastNotes = data['notes']?.toString();
      }
      return {
        'success': true,
        'message': 'Milestone updated successfully.',
        'data': {
          'appointmentId': 901,
          'currentMilestoneKey': lastMilestoneKey,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'milestones': [
            {'milestoneKey': 'check_in_completed', 'completed': true},
            {'milestoneKey': lastMilestoneKey, 'completed': true},
          ],
        }
      };
    }
    return {'success': true, 'data': {}};
  }
}

late _DropdownMockApiRepository _mockApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();

    if (GetIt.I.isRegistered<ApiRepository>()) {
      GetIt.I.unregister<ApiRepository>();
    }
    _mockApi = _DropdownMockApiRepository();
    GetIt.I.registerSingleton<ApiRepository>(_mockApi);
  });

  setUp(() async {
    _mockApi.reset();
    await ServicesLocator.sessionService.clearSession();
    await ServicesLocator.sessionService.clearGroomerSession();
    await ServicesLocator.sessionService.saveGroomerUser({
      'id': 10,
      'name': 'Groomer Alex',
      'email': 'alex@groomer.com',
    });
  });


  group('Update Any Store Milestone Dropdown Tests', () {
    testWidgets('1. Displays "Update any store milestone" section with dropdown and Apply button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const checkedInBooking = GroomerBooking(
        bookingId: 901,
        storeId: 'SHEAR-001',
        status: 'in_progress',
        bookingDate: '2026-10-18',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rusty',
        customerName: 'Emma',
        serviceName: 'Full Grooming',
        groomerId: 10,
        milestoneRecord: GroomerMilestoneRecord(
          dynamicMilestones: {
            'check_in_completed': (completed: true, occurredAt: '2026-10-18T10:00:00Z', notes: null, action: null, status: null),
          },
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerMilestoneDialog(booking: checkedInBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Label and dropdown exist
      expect(find.text('Update any store milestone'), findsOneWidget);
      expect(find.text('Select milestone…'), findsOneWidget);

      // Apply button exists and is initially disabled
      final applyFinder = find.widgetWithText(ElevatedButton, 'Apply');
      expect(applyFinder, findsOneWidget);
      final applyButton = tester.widget<ElevatedButton>(applyFinder);
      expect(applyButton.onPressed, isNull);
    });

    testWidgets('2. Opening dropdown displays available store milestones and selecting enables Apply', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const checkedInBooking = GroomerBooking(
        bookingId: 901,
        storeId: 'SHEAR-001',
        status: 'in_progress',
        bookingDate: '2026-10-18',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rusty',
        customerName: 'Emma',
        serviceName: 'Full Grooming',
        groomerId: 10,
        milestoneRecord: GroomerMilestoneRecord(
          dynamicMilestones: {
            'check_in_completed': (completed: true, occurredAt: '2026-10-18T10:00:00Z', notes: null, action: null, status: null),
          },
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerMilestoneDialog(booking: checkedInBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the dropdown to open popup
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Available milestone options are present in the dropdown menu
      expect(find.widgetWithText(DropdownMenuItem<String>, 'Bath Completed'), findsWidgets);
      expect(find.widgetWithText(DropdownMenuItem<String>, 'Grooming Completed'), findsWidgets);
      expect(find.widgetWithText(DropdownMenuItem<String>, 'Ready for Checkout'), findsWidgets);

      // Select 'Bath Completed' from the opened menu (last item)
      await tester.tap(find.widgetWithText(DropdownMenuItem<String>, 'Bath Completed').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Now Bath Completed is selected in the dropdown
      expect(find.text('Bath Completed'), findsWidgets);

      // Apply button is now enabled
      final applyFinder = find.widgetWithText(ElevatedButton, 'Apply');
      final applyButton = tester.widget<ElevatedButton>(applyFinder);
      expect(applyButton.onPressed, isNotNull);
    });

    testWidgets('3. Applying milestone invokes API, shows toast, and updates UI reflection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      GroomerBooking? updatedResult;
      const checkedInBooking = GroomerBooking(
        bookingId: 901,
        storeId: 'SHEAR-001',
        status: 'in_progress',
        bookingDate: '2026-10-18',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rusty',
        customerName: 'Emma',
        serviceName: 'Full Grooming',
        groomerId: 10,
        milestoneRecord: GroomerMilestoneRecord(
          dynamicMilestones: {
            'check_in_completed': (completed: true, occurredAt: '2026-10-18T10:00:00Z', notes: null, action: null, status: null),
          },
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroomerMilestoneDialog(
              booking: checkedInBooking,
              onMilestoneSuccess: (b) => updatedResult = b,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter optional notes
      await tester.enterText(find.byType(TextField).first, 'Used hypoallergenic lavender shampoo');
      await tester.pumpAndSettle();

      // Select Bath Completed
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<String>, 'Bath Completed').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Tap Apply
      final applyFinder = find.widgetWithText(ElevatedButton, 'Apply');
      await tester.tap(applyFinder);
      await tester.pumpAndSettle();

      // Verify API was called with bath_completed and notes
      expect(_mockApi.milestonePostCount, equals(1));
      expect(_mockApi.lastMilestoneKey, equals('bath_completed'));
      expect(_mockApi.lastNotes, equals('Used hypoallergenic lavender shampoo'));

      // Verify callback was called
      expect(updatedResult, isNotNull);
      expect(updatedResult!.isBathCompleted, isTrue);

      // Verify dropdown reset to hint 'Select milestone…'
      expect(find.text('Select milestone…'), findsOneWidget);

      // Verify notes field was cleared
      final notesField = tester.widget<TextField>(find.byType(TextField).first);
      expect(notesField.controller?.text, isEmpty);
    });

    testWidgets('4. Does not display milestone dropdown when appointment is not checked in & check in button colors adhere to theme', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const customPrimary = Color(0xFF111827);
      const customOnPrimary = Colors.white;

      final customTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: customPrimary,
          primary: customPrimary,
          onPrimary: customOnPrimary,
        ),
        useMaterial3: true,
      );

      final todayStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
      final unCheckedInBooking = GroomerBooking(
        bookingId: 902,
        storeId: 'SHEAR-001',
        status: 'confirmed',
        bookingDate: todayStr,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Milo',
        customerName: 'Jack',
        serviceName: 'Bath',
        groomerId: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: customTheme,
          home: Scaffold(
            body: GroomerMilestoneDialog(booking: unCheckedInBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In check_in stage, Check In button is shown, dropdown is hidden
      final checkInFinder = find.widgetWithText(ElevatedButton, 'Check In');
      expect(checkInFinder, findsOneWidget);
      expect(find.text('Update any store milestone'), findsNothing);

      // Verify Check In button styling
      final checkInButton = tester.widget<ElevatedButton>(checkInFinder);
      final bg = checkInButton.style?.backgroundColor?.resolve({WidgetState.selected}) ??
          checkInButton.style?.backgroundColor?.resolve({});
      expect(bg, equals(customPrimary));

      final checkInText = tester.widget<Text>(find.descendant(of: checkInFinder, matching: find.byType(Text)));
      expect(checkInText.style?.color, equals(customOnPrimary));
      expect(checkInText.style?.fontFamily, contains('Parkinsans'));
    });

    testWidgets('5. Button colors, font color, and font family adhere strictly to app theme color', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const customPrimary = Color(0xFF111827);
      const customOnPrimary = Colors.white;

      final customTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: customPrimary,
          primary: customPrimary,
          onPrimary: customOnPrimary,
        ),
        useMaterial3: true,
      );

      final todayStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
      final booking = GroomerBooking(
        bookingId: 901,
        storeId: 'SHEAR-001',
        status: 'in_progress',
        serviceStage: 'in_progress',
        bookingDate: todayStr,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Bella',
        customerName: 'Sarah',
        serviceName: 'Full Grooming',
        groomerId: 10,
        milestoneRecord: const GroomerMilestoneRecord(
          dynamicMilestones: {
            'check_in_completed': (completed: true, occurredAt: '2026-10-18T10:00:00Z', notes: null, action: null, status: null),
          },
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: customTheme,
          home: Scaffold(
            body: GroomerMilestoneDialog(booking: booking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Apply button
      final applyButtonFinder = find.widgetWithText(ElevatedButton, 'Apply');
      expect(applyButtonFinder, findsOneWidget);

      final applyButton = tester.widget<ElevatedButton>(applyButtonFinder);
      final buttonStyle = applyButton.style!;

      // Background color matches theme.colorScheme.primary
      final bg = buttonStyle.backgroundColor?.resolve({WidgetState.selected}) ??
          buttonStyle.backgroundColor?.resolve({});
      expect(bg, equals(customPrimary));

      // Font family is Parkinsans
      final applyText = tester.widget<Text>(find.descendant(of: applyButtonFinder, matching: find.byType(Text)));
      expect(applyText.style?.fontFamily, contains('Parkinsans'));

      // Now select a milestone from the dropdown to enable the button
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownMenuItem<String>, 'Bath Completed').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      final enabledApplyText = tester.widget<Text>(find.descendant(of: applyButtonFinder, matching: find.byType(Text)));
      expect(enabledApplyText.style?.color, equals(customOnPrimary));
    });
  });
}
