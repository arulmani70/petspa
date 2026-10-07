import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_header.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_progress.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/mobile/widgets/pet_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetCard Border Tests', () {
    testWidgets('Selected PetCard has black border with width 2', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetCard(
              name: 'Buddy',
              breed: 'Golden Retriever',
              weight: '25kg',
              age: '3 yrs',
              selected: true,
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.top.color, equals(Colors.black));
      expect(border.top.width, equals(2.0));
    });

    testWidgets('Unselected PetCard has subtle border with width 1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetCard(
              name: 'Buddy',
              breed: 'Golden Retriever',
              weight: '25kg',
              age: '3 yrs',
              selected: false,
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.top.color, equals(const Color(0xFFE4E9EC)));
      expect(border.top.width, equals(1.0));
    });
  });

  group('BookingHeader Spacing Tests', () {
    testWidgets('BookingHeader has consistent top/bottom padding and progress layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingHeader(
              title: 'Select Service',
              step: 2,
              subtitle: 'Step 2 of 4 — Choose a Service',
            ),
          ),
        ),
      );

      final headerContainerFinder = find.byType(BookingHeader);
      expect(headerContainerFinder, findsOneWidget);

      final innerContainerFinder = find.descendant(
        of: headerContainerFinder,
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(innerContainerFinder);
      expect(container.padding, equals(const EdgeInsets.fromLTRB(17, 14, 17, 20)));

      final progressFinder = find.byType(BookingProgress);
      expect(progressFinder, findsOneWidget);
      expect(find.text('Step 2 of 4 — Choose a Service'), findsOneWidget);
    });
  });
}
