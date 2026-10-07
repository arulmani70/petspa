import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';

void main() {
  group('BookingDraft State Detection Tests', () {
    test('Initial state with no pet should be newBooking', () {
      final draft = BookingDraft();
      expect(draft.pet, isNull);
      expect(draft.state, BookingState.newBooking);
    });

    test('State with valid pet should be existingPet', () {
      final draft = BookingDraft();
      draft.setPet({'pet_id': '123', 'pet_name': 'Teddy'});
      
      expect(draft.pet, isNotNull);
      expect(draft.state, BookingState.existingPet);
    });

    test('State reverts to newBooking if draft is reset', () {
      final draft = BookingDraft();
      draft.setPet({'pet_id': '123', 'pet_name': 'Teddy'});
      expect(draft.state, BookingState.existingPet);
      
      draft.reset();
      expect(draft.pet, isNull);
      expect(draft.state, BookingState.newBooking);
    });

    test('Invalid/null pet state handles safely', () {
      final draft = BookingDraft();
      draft.setPet(null);
      
      expect(draft.pet, isNull);
      expect(draft.state, BookingState.newBooking);
    });
  });
}
