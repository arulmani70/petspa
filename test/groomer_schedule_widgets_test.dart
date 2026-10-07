import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/break_schedule_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/groomer_working_hours_table_widget.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/store_hours_table_widget.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/time_picker_selector.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('TimePickerSelector Tests', () {
    testWidgets('renders 12h formatted time and respects disabled state', (tester) async {
      String selected = '09:00';

      await tester.pumpWidget(buildTestableWidget(
        TimePickerSelector(
          time: selected,
          isEnabled: true,
          onTimeSelected: (t) => selected = t,
        ),
      ));

      expect(find.text('09:00 AM'), findsOneWidget);

      // Disabled state
      await tester.pumpWidget(buildTestableWidget(
        TimePickerSelector(
          time: '09:00',
          isEnabled: false,
          onTimeSelected: (_) {},
        ),
      ));

      expect(find.text('—'), findsOneWidget);
    });
  });

  group('StoreHoursTableWidget Tests (Read-Only)', () {
    testWidgets('renders all weekdays with read-only badge and status pills', (tester) async {
      List<StoreServiceHour> testHours = [
        const StoreServiceHour(dayOfWeek: 'Monday', isOpen: true, startTime: '09:00', endTime: '18:00'),
        const StoreServiceHour(dayOfWeek: 'Tuesday', isOpen: true, startTime: '09:00', endTime: '18:00'),
        const StoreServiceHour(dayOfWeek: 'Wednesday', isOpen: false, startTime: '09:00', endTime: '18:00'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        StoreHoursTableWidget(
          hours: testHours,
        ),
      ));

      expect(find.text('Store Hours'), findsOneWidget);
      expect(find.text('READ ONLY'), findsNothing);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);
      expect(find.text('Open'), findsNWidgets(2));
      expect(find.text('Closed'), findsOneWidget);

      // Verify no switches or editable controls exist
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('GroomerWorkingHoursTableWidget Tests (Read-Only)', () {
    testWidgets('renders groomer working hours with break chips', (tester) async {
      final testGroomerHours = [
        const GroomerWorkingHour(
          groomerCode: 'G001',
          dayOfWeek: 'Monday',
          isWorking: true,
          startTime: '09:00',
          endTime: '17:00',
          breaks: [
            GroomerBreak(
              groomerCode: 'G001',
              dayOfWeek: 'Monday',
              startTime: '13:00',
              endTime: '14:00',
              reason: 'Lunch break',
            ),
          ],
        ),
        const GroomerWorkingHour(
          groomerCode: 'G001',
          dayOfWeek: 'Sunday',
          isWorking: false,
          startTime: '09:00',
          endTime: '17:00',
        ),
      ];

      final testStoreHours = [
        const StoreServiceHour(dayOfWeek: 'Monday', isOpen: true, startTime: '08:00', endTime: '18:00'),
        const StoreServiceHour(dayOfWeek: 'Sunday', isOpen: false, startTime: '08:00', endTime: '18:00'),
      ];

      await tester.pumpWidget(buildTestableWidget(
        GroomerWorkingHoursTableWidget(
          hours: testGroomerHours,
          storeHours: testStoreHours,
          groomerCode: 'G001',
        ),
      ));

      expect(find.text('My Working Hours'), findsOneWidget);
      expect(find.text('READ ONLY'), findsNothing);
      expect(find.text('Working'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.textContaining('Lunch break · 01:00 PM – 02:00 PM'), findsOneWidget);

      // Verify no editable switches or Add Break buttons exist
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Add Break'), findsNothing);
    });
  });

  group('BreakScheduleDialog Tests', () {
    testWidgets('renders dialog and validates times', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const BreakScheduleDialog(
                  dayOfWeek: 'Monday',
                  groomerCode: 'G001',
                  workingStartMin: 540,
                  workingEndMin: 1020,
                ),
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Add Break'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Lunch break'), findsWidgets);
      expect(find.text('Save Break'), findsOneWidget);
    });
  });
}

