import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';

void main() {
  group('Pet Booking Duplicate Warning & Prevention Tests', () {
    const String testDate = '2026-10-25';

    test('Scenario 1: Same pet + same date/time + different groomers -> Warning only, slot is NOT disabled', () {
      final existingBookings = [
        {
          'bookingId': 101,
          'bookingDate': testDate,
          'startTime': '10:00',
          'endTime': '11:00',
          'groomerId': 1, // Groomer 1 (e.g. Sarah)
          'petId': 5,     // Pet 5 (e.g. Max)
          'petName': 'Max',
          'status': 'confirmed',
        }
      ];

      // Slot is NOT blocked/disabled in the UI grid for a DIFFERENT groomer (Groomer 2)
      final isSlotBlocked = BookingDateUtils.isSlotAlreadyBookedByUser(
        slotDate: testDate,
        slotStartTime: '10:00',
        slotEndTime: '11:00',
        slotGroomerId: 2,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );
      expect(isSlotBlocked, isFalse,
          reason: 'Slot must NOT be disabled when booking with a different groomer');

      // However, the conflict is detected so that a warning dialog can be presented to customer
      final conflictBooking = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '10:00',
        slotEndTime: '11:00',
        slotGroomerId: 2,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );
      expect(conflictBooking, isNotNull,
          reason: 'Conflict with another groomer must be detected to trigger warning');
      expect(conflictBooking?['bookingId'], equals(101));
    });

    test('Scenario 2: Same pet + same date + different non-overlapping time slots -> Allow booking without warning', () {
      final existingBookings = [
        {
          'bookingId': 101,
          'bookingDate': testDate,
          'startTime': '10:00',
          'endTime': '11:00',
          'groomerId': 1,
          'petId': 5,
          'petName': 'Max',
          'status': 'confirmed',
        }
      ];

      // Attempting to book SAME pet (ID 5) with Groomer 2 at later non-overlapping slot (14:00 - 15:00)
      final isSlotBlocked = BookingDateUtils.isSlotAlreadyBookedByUser(
        slotDate: testDate,
        slotStartTime: '14:00',
        slotEndTime: '15:00',
        slotGroomerId: 2,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );
      expect(isSlotBlocked, isFalse);

      final conflictBooking = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '14:00',
        slotEndTime: '15:00',
        slotGroomerId: 2,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );
      expect(conflictBooking, isNull,
          reason: 'No warning should appear for non-overlapping slots');
    });

    test('Scenario 3: Different pets + same date/time + different groomers -> Allow bookings without warning', () {
      final existingBookings = [
        {
          'bookingId': 101,
          'bookingDate': testDate,
          'startTime': '10:00',
          'endTime': '11:00',
          'groomerId': 1,
          'petId': 5, // Pet 5 (Max)
          'petName': 'Max',
          'status': 'confirmed',
        }
      ];

      // Attempting to book DIFFERENT pet (Pet 8, Bella) with Groomer 2 at same time (10:00 - 11:00)
      final isSlotBlocked = BookingDateUtils.isSlotAlreadyBookedByUser(
        slotDate: testDate,
        slotStartTime: '10:00',
        slotEndTime: '11:00',
        slotGroomerId: 2,
        targetPetId: 8,
        targetPetName: 'Bella',
        userBookings: existingBookings,
      );
      expect(isSlotBlocked, isFalse);

      final conflictBooking = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '10:00',
        slotEndTime: '11:00',
        slotGroomerId: 2,
        targetPetId: 8,
        targetPetName: 'Bella',
        userBookings: existingBookings,
      );
      expect(conflictBooking, isNull,
          reason: 'Different pets can be booked simultaneously without conflict');
    });

    test('Scenario 4: Existing booking cancelled -> Allow a new booking in that slot without warning', () {
      final existingBookings = [
        {
          'bookingId': 102,
          'bookingDate': testDate,
          'startTime': '10:00',
          'endTime': '11:00',
          'groomerId': 1,
          'petId': 5,
          'petName': 'Max',
          'status': 'cancelled',
        },
        {
          'bookingId': 103,
          'bookingDate': testDate,
          'startTime': '10:00',
          'endTime': '11:00',
          'groomerId': 3,
          'petId': 5,
          'petName': 'Max',
          'status': 'rejected',
        }
      ];

      final conflictBooking = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '10:00',
        slotEndTime: '11:00',
        slotGroomerId: 2,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );

      expect(conflictBooking, isNull,
          reason: 'Cancelled or rejected bookings must not trigger duplicate pet warning');
    });

    test('Scenario 5: Overlapping time ranges with different start times -> Detects warning for overlapping, allows adjacent', () {
      final existingBookings = [
        {
          'bookingId': 104,
          'bookingDate': testDate,
          'startTime': '10:00',
          'endTime': '11:30', // 90 min appointment with Groomer 1
          'groomerId': 1,
          'petId': 5,
          'petName': 'Max',
          'status': 'confirmed',
        }
      ];

      // Candidate A: 10:30 - 11:00 with Groomer 2 (inside the 10:00 - 11:30 window)
      final conflictInside = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '10:30',
        slotEndTime: '11:00',
        slotGroomerId: 2,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );
      expect(conflictInside, isNotNull, reason: '10:30-11:00 overlaps 10:00-11:30 and must trigger warning');

      // Candidate B: 09:30 - 10:30 with Groomer 2 (starts before, overlaps head)
      final conflictHead = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '09:30',
        slotEndTime: '10:30',
        slotGroomerId: 2,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );
      expect(conflictHead, isNotNull, reason: '09:30-10:30 overlaps 10:00-11:30 and must trigger warning');

      // Candidate C: 11:30 - 12:30 with Groomer 2 (adjacent, starts exactly when previous ends)
      final conflictAdjacent = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '11:30',
        slotEndTime: '12:30',
        slotGroomerId: 2,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );
      expect(conflictAdjacent, isNull, reason: '11:30-12:30 is adjacent and must not trigger warning');
    });

    test('Scenario 6: Nested pet structure in API response is correctly extracted for warning check', () {
      final existingBookings = [
        {
          'bookingId': 105,
          'bookingDate': testDate,
          'startTime': '11:00',
          'endTime': '12:00',
          'groomerId': 1,
          'pet': {
            'id': 9,
            'name': 'Charlie',
            'breed': 'Golden Retriever',
          },
          'status': 'pending',
        }
      ];

      // Test matching by petId = 9 with Groomer 2
      final conflictById = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '11:00',
        slotEndTime: '12:00',
        slotGroomerId: 2,
        targetPetId: 9,
        targetPetName: 'Charlie',
        userBookings: existingBookings,
      );
      expect(conflictById, isNotNull);

      // Test with different pet
      final noConflictOtherPet = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
        slotDate: testDate,
        slotStartTime: '11:00',
        slotEndTime: '12:00',
        slotGroomerId: 2,
        targetPetId: 10,
        targetPetName: 'Rocky',
        userBookings: existingBookings,
      );
      expect(noConflictOtherPet, isNull);
    });

    test('Scenario 7: Exact warning message constant matches expected specification', () {
      expect(
        BookingDateUtils.duplicatePetBookingWarningMessage,
        equals('This pet already has a booking with another groomer during this time slot. Do you want to continue?'),
      );
    });

    test('Scenario 8: Same pet + same date/time + SAME groomer -> Hard-blocked', () {
      final existingBookings = [
        {
          'bookingId': 106,
          'bookingDate': testDate,
          'startTime': '10:00',
          'endTime': '11:00',
          'groomerId': 1,
          'petId': 5,
          'petName': 'Max',
          'status': 'confirmed',
        }
      ];

      // Same groomer (Groomer 1) -> hard-blocked
      final isSlotBlocked = BookingDateUtils.isSlotAlreadyBookedByUser(
        slotDate: testDate,
        slotStartTime: '10:00',
        slotEndTime: '11:00',
        slotGroomerId: 1,
        targetPetId: 5,
        targetPetName: 'Max',
        userBookings: existingBookings,
      );
      expect(isSlotBlocked, isTrue,
          reason: 'Same pet cannot book the SAME groomer in the exact same slot');
    });

    testWidgets('Scenario 9: Warning dialog displays expected message, Cancel dismisses, Continue confirms', (WidgetTester tester) async {
      bool? userChoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    userChoice = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Booking Notice'),
                        content: const Text(
                          BookingDateUtils.duplicatePetBookingWarningMessage,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // 1. Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // 2. Verify dialog content and buttons
      expect(find.text('Booking Notice'), findsOneWidget);
      expect(
        find.text('This pet already has a booking with another groomer during this time slot. Do you want to continue?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // 3. Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(userChoice, isFalse);

      // 4. Open dialog again and tap Continue
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(userChoice, isTrue);
    });
  });
}
