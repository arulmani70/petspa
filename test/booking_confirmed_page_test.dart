import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_confirmed_page_mobile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingDraft draft;

  setUp(() {
    draft = BookingDraft();
    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<BookingDraft>(draft);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  group('BookingConfirmedPageMobile Tests', () {
    testWidgets('renders pet image, name, breed, and confirmation details when pet photo is present', (tester) async {
      draft.lastBooking = {
        'booking_id': 'BKG-999',
        'status': 'confirmed',
        'total_price': 85.0,
        'total_duration_minutes': 60,
        'pet_name': 'Milo',
        'pet_breed': 'Golden Retriever',
        'pet_photo': 'https://shear-heaven-api.genzcodershub.com/uploads/milo.png',
        'service_name': 'Full Grooming',
        'date_label': 'Oct 15, 2026',
        'time_label': '10:00 AM',
        'groomer_name': 'Sarah',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingConfirmedPageMobile(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify confirmed text and pet name
      expect(find.text('Booking Confirmed'), findsOneWidget);
      expect(find.text("Milo's appointment is all set. See you at the salon!"), findsOneWidget);
      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Breed: Golden Retriever'), findsOneWidget);
      expect(find.text('Full Grooming'), findsOneWidget);
      expect(find.text('Oct 15, 2026 · 10:00 AM'), findsOneWidget);

      // Verify that Image.network is rendered for pet photo
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('renders fallback icon when pet photo is absent', (tester) async {
      draft.lastBooking = {
        'booking_id': 'BKG-1000',
        'status': 'confirmed',
        'total_price': 50.0,
        'total_duration_minutes': 30,
        'pet_name': 'Bella',
        'pet_breed': 'Poodle',
        'pet_photo': null,
        'service_name': 'Bath & Blow Dry',
        'date_label': 'Oct 16, 2026',
        'time_label': '02:00 PM',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingConfirmedPageMobile(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Booking Confirmed'), findsOneWidget);
      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Breed: Poodle'), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsOneWidget);
    });

    testWidgets('renders asset pet image when pet photo is an asset path', (tester) async {
      draft.lastBooking = {
        'booking_id': 'BKG-1001',
        'status': 'confirmed',
        'total_price': 50.0,
        'total_duration_minutes': 30,
        'pet_name': 'Charlie',
        'pet_breed': 'Beagle',
        'pet_photo': 'assets/images/common/offer_1.png',
        'service_name': 'Bath & Blow Dry',
        'date_label': 'Oct 17, 2026',
        'time_label': '11:00 AM',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingConfirmedPageMobile(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Breed: Beagle'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });
  });
}
