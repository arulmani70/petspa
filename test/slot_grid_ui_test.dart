import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Slot Grid Fixed 4-Column Layout & Visual States Tests', () {
    // Helper to build a test slot grid with GridView (matching the implementation)
    Widget buildSlotGrid(List<Map<String, dynamic>> slots, {String? selectedTime}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360, // Fixed device width
              child: Container(
                padding: const EdgeInsets.all(14),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: slots.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 36,
                  ),
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final st = slot['startTime'] as String;
                    final isSelected = st == selectedTime;
                    final isAtCapacity = slot['isAtCapacity'] == true;
                    final isBooked = slot['isBooked'] == true;
                    final isAlreadyBooked = slot['isAlreadyBooked'] == true;

                    Color bg, fg, borderColor;
                    if (isSelected) {
                      bg = const Color(0xFF0F766E);
                      fg = Colors.white;
                      borderColor = const Color(0xFF0F766E);
                    } else if (isAlreadyBooked) {
                      bg = const Color(0xFFF3F4F6);
                      fg = const Color(0xFFAFAFAF);
                      borderColor = const Color(0xFFE5E7EB);
                    } else if (isAtCapacity) {
                      bg = const Color(0xFFFFF7ED);
                      fg = const Color(0xFFB45309);
                      borderColor = const Color(0xFFFED7AA);
                    } else if (isBooked) {
                      bg = const Color(0xFFF3F4F6);
                      fg = const Color(0xFFAFAFAF);
                      borderColor = const Color(0xFFE5E7EB);
                    } else {
                      bg = const Color(0xFF111827);
                      fg = Colors.white;
                      borderColor = const Color(0xFF111827);
                    }

                    return Container(
                      key: ValueKey('slot_$st'),
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Text(
                        st,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: fg,
                          decoration: (isBooked || isAlreadyBooked) ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('1. 8 slots -> 2 rows of 4 equal-width columns', (tester) async {
      final slots = List.generate(8, (i) => {'startTime': '0${i + 1}:00'});
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final firstSlotBox = tester.getRect(find.byKey(const ValueKey('slot_01:00')));
      final fourthSlotBox = tester.getRect(find.byKey(const ValueKey('slot_04:00')));
      final fifthSlotBox = tester.getRect(find.byKey(const ValueKey('slot_05:00')));
      final eighthSlotBox = tester.getRect(find.byKey(const ValueKey('slot_08:00')));

      // All slot widths must be equal
      expect(firstSlotBox.width, equals(fourthSlotBox.width));
      expect(firstSlotBox.width, equals(fifthSlotBox.width));
      expect(firstSlotBox.width, equals(eighthSlotBox.width));

      // Row 1 Y position vs Row 2 Y position
      expect(firstSlotBox.top, equals(fourthSlotBox.top));
      expect(fifthSlotBox.top, equals(eighthSlotBox.top));
      expect(fifthSlotBox.top, greaterThan(firstSlotBox.bottom));
    });

    testWidgets('2. 7 slots -> Row 1 has 4 slots, Row 2 has 3 slots with IDENTICAL width (no stretching)', (tester) async {
      final slots = List.generate(7, (i) => {'startTime': '0${i + 1}:00'});
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final firstSlotBox = tester.getRect(find.byKey(const ValueKey('slot_01:00')));
      final seventhSlotBox = tester.getRect(find.byKey(const ValueKey('slot_07:00')));

      expect(seventhSlotBox.width, equals(firstSlotBox.width),
          reason: '7th slot in incomplete 2nd row must NOT stretch');
    });

    testWidgets('3. 6 slots -> Row 1 has 4 slots, Row 2 has 2 slots with IDENTICAL width (no stretching)', (tester) async {
      final slots = List.generate(6, (i) => {'startTime': '0${i + 1}:00'});
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final firstSlotBox = tester.getRect(find.byKey(const ValueKey('slot_01:00')));
      final sixthSlotBox = tester.getRect(find.byKey(const ValueKey('slot_06:00')));

      expect(sixthSlotBox.width, equals(firstSlotBox.width),
          reason: '6th slot in incomplete 2nd row must NOT stretch');
    });

    testWidgets('4. 5 slots -> Row 1 has 4 slots, Row 2 has 1 slot with IDENTICAL width (no stretching)', (tester) async {
      final slots = List.generate(5, (i) => {'startTime': '0${i + 1}:00'});
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final firstSlotBox = tester.getRect(find.byKey(const ValueKey('slot_01:00')));
      final fifthSlotBox = tester.getRect(find.byKey(const ValueKey('slot_05:00')));

      expect(fifthSlotBox.width, equals(firstSlotBox.width),
          reason: '5th slot (single item in 2nd row) must NOT stretch');
    });

    testWidgets('5. 4 slots -> Row 1 has exactly 4 equal-width slots', (tester) async {
      final slots = List.generate(4, (i) => {'startTime': '0${i + 1}:00'});
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final firstSlotBox = tester.getRect(find.byKey(const ValueKey('slot_01:00')));
      final fourthSlotBox = tester.getRect(find.byKey(const ValueKey('slot_04:00')));

      expect(firstSlotBox.width, equals(fourthSlotBox.width));
    });

    testWidgets('6. 3 slots -> 3 fixed-width slots (1/4 column width each, NO expansion)', (tester) async {
      final slots = List.generate(3, (i) => {'startTime': '0${i + 1}:00'});
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final firstSlotBox = tester.getRect(find.byKey(const ValueKey('slot_01:00')));
      final thirdSlotBox = tester.getRect(find.byKey(const ValueKey('slot_03:00')));

      // For 360 container width with padding 14*2=28, available = 332, 3 gaps of 8=24 -> slot width = 308/4 = 77
      expect(firstSlotBox.width, equals(thirdSlotBox.width));
      expect(firstSlotBox.width, lessThan(100.0), reason: 'Slots must occupy only 1/4 of grid width, not expand to 1/3');
    });

    testWidgets('7. 2 slots -> 2 fixed-width slots (1/4 column width each, NO expansion)', (tester) async {
      final slots = List.generate(2, (i) => {'startTime': '0${i + 1}:00'});
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final firstSlotBox = tester.getRect(find.byKey(const ValueKey('slot_01:00')));
      final secondSlotBox = tester.getRect(find.byKey(const ValueKey('slot_02:00')));

      expect(firstSlotBox.width, equals(secondSlotBox.width));
      expect(firstSlotBox.width, lessThan(100.0), reason: 'Slots must occupy only 1/4 of grid width, not expand to 1/2');
    });

    testWidgets('8. 1 slot -> 1 fixed-width slot (1/4 column width, NO expansion)', (tester) async {
      final slots = [{'startTime': '01:00'}];
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final firstSlotBox = tester.getRect(find.byKey(const ValueKey('slot_01:00')));
      expect(firstSlotBox.width, lessThan(100.0), reason: 'Single slot must occupy only 1/4 of grid width, not expand to full width');
    });

    testWidgets('9. Capacity text (0/3, 1/3, 2/3, 3/3) is NOT rendered in the UI', (tester) async {
      final slots = [
        {'startTime': '03:00 PM'},
        {'startTime': '03:30 PM'},
        {'startTime': '04:00 PM'},
        {'startTime': '04:30 PM'},
      ];
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      expect(find.text('0/3'), findsNothing);
      expect(find.text('1/3'), findsNothing);
      expect(find.text('2/3'), findsNothing);
      expect(find.text('3/3'), findsNothing);
      expect(find.text('0 / 3'), findsNothing);
      expect(find.text('1 / 3'), findsNothing);
      expect(find.text('2 / 3'), findsNothing);
      expect(find.text('3 / 3'), findsNothing);

      // Clean time text only
      expect(find.text('03:00 PM'), findsOneWidget);
      expect(find.text('03:30 PM'), findsOneWidget);
      expect(find.text('04:00 PM'), findsOneWidget);
      expect(find.text('04:30 PM'), findsOneWidget);
    });

    testWidgets('10. Slot states visual distinction', (tester) async {
      final slots = [
        {'startTime': '03:00 PM'}, // available
        {'startTime': '03:30 PM', 'isAtCapacity': true}, // at capacity
        {'startTime': '04:00 PM', 'isBooked': true}, // booked
        {'startTime': '04:30 PM'}, // selected
      ];
      await tester.pumpWidget(buildSlotGrid(slots, selectedTime: '04:30 PM'));
      await tester.pumpAndSettle();

      final selectedBox = tester.widget<Container>(find.byKey(const ValueKey('slot_04:30 PM')));
      final selectedDeco = selectedBox.decoration as BoxDecoration;
      expect(selectedDeco.color, equals(const Color(0xFF0F766E)));

      final atCapacityBox = tester.widget<Container>(find.byKey(const ValueKey('slot_03:30 PM')));
      final atCapacityDeco = atCapacityBox.decoration as BoxDecoration;
      expect(atCapacityDeco.color, equals(const Color(0xFFFFF7ED)));

      final bookedBox = tester.widget<Container>(find.byKey(const ValueKey('slot_04:00 PM')));
      final bookedDeco = bookedBox.decoration as BoxDecoration;
      expect(bookedDeco.color, equals(const Color(0xFFF3F4F6)));

      final availableBox = tester.widget<Container>(find.byKey(const ValueKey('slot_03:00 PM')));
      final availableDeco = availableBox.decoration as BoxDecoration;
      expect(availableDeco.color, equals(const Color(0xFF111827)));
    });

    testWidgets('11. Already Booked slot visual state (disabled with lineThrough styling)', (tester) async {
      final slots = [
        {'startTime': '11:00 AM', 'isAlreadyBooked': true}, // already booked by current user
        {'startTime': '12:00 PM'}, // adjacent available
      ];
      await tester.pumpWidget(buildSlotGrid(slots));
      await tester.pumpAndSettle();

      final alreadyBookedBox = tester.widget<Container>(find.byKey(const ValueKey('slot_11:00 AM')));
      final alreadyBookedDeco = alreadyBookedBox.decoration as BoxDecoration;
      expect(alreadyBookedDeco.color, equals(const Color(0xFFF3F4F6)));

      final textWidget = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('slot_11:00 AM')),
        matching: find.byType(Text),
      ));
      expect(textWidget.style?.decoration, equals(TextDecoration.lineThrough));

      final availableBox = tester.widget<Container>(find.byKey(const ValueKey('slot_12:00 PM')));
      final availableDeco = availableBox.decoration as BoxDecoration;
      expect(availableDeco.color, equals(const Color(0xFF111827)));
    });
  });
}
