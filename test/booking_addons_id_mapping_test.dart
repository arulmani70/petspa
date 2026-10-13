import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Add-on ID Mapping & BookingDraft Extraction Tests', () {
    test('Fallback add-ons have sequential IDs starting from 1 to 12', () {
      final fallback = BookingServicesResult.fallback();
      expect(fallback.addOns.length, equals(12));

      for (int i = 0; i < fallback.addOns.length; i++) {
        final addOn = fallback.addOns[i];
        expect(addOn.id, equals(i + 1),
            reason: 'Add-on ${addOn.name} should have ID ${i + 1}');
        expect(addOn.isAddOn, isTrue);
        expect(addOn.isPackage, isFalse);
      }
    });

    test('ServiceItem.toMap() formats add-on fields correctly', () {
      const item = ServiceItem(
        id: 2,
        code: 'A0002',
        isPackage: false,
        isAddOn: true,
        name: 'Teeth Brushing',
        description: 'Oral hygiene care',
        price: 16.0,
        priceDisplay: r'$16 & up',
        durationMinutes: 60,
      );

      final map = item.toMap();
      expect(map['id'], equals(2));
      expect(map['addOnId'], equals(2));
      expect(map['serviceId'], isNull,
          reason: 'serviceId should be null for add-ons');
      expect(map['isAddOn'], isTrue);
      expect(map['isPackage'], isFalse);
    });

    test('BookingDraft.extractAddOnIds extracts correct 1-based IDs', () {
      final draft = BookingDraft();

      const item1 = ServiceItem(
        id: 1,
        code: 'A0001',
        isPackage: false,
        isAddOn: true,
        name: 'Nail Grinding',
        description: 'Smooth round finish on nails',
        price: 18.0,
        priceDisplay: r'$18 & up',
        durationMinutes: 60,
      );

      const item2 = ServiceItem(
        id: 2,
        code: 'A0002',
        isPackage: false,
        isAddOn: true,
        name: 'Teeth Brushing',
        description: 'Oral hygiene care',
        price: 16.0,
        priceDisplay: r'$16 & up',
        durationMinutes: 60,
      );

      draft.toggleAddOn(item1.toMap());
      draft.toggleAddOn(item2.toMap());

      final extractedIds = draft.extractAddOnIds();
      expect(extractedIds, equals([1, 2]));
      expect(extractedIds.contains(15), isFalse,
          reason: 'Add-on 2 should be ID 2, NOT 15');
    });

    test('BookingDraft toggleAddOn adds and removes correctly', () {
      final draft = BookingDraft();

      const item2 = ServiceItem(
        id: 2,
        code: 'A0002',
        isPackage: false,
        isAddOn: true,
        name: 'Teeth Brushing',
        description: 'Oral hygiene care',
        price: 16.0,
        priceDisplay: r'$16 & up',
        durationMinutes: 60,
      );

      draft.toggleAddOn(item2.toMap());
      expect(draft.extractAddOnIds(), equals([2]));

      draft.toggleAddOn(item2.toMap());
      expect(draft.extractAddOnIds(), isEmpty);
    });
  });
}
