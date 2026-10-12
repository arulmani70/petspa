import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  const testBooking = GroomerBooking(
    bookingId: 101,
    status: 'pending',
    bookingDate: '2026-10-15',
    startTime: '10:00 AM - 11:30 AM',
    endTime: '11:30 AM',
    petName: 'Bella',
    customerName: 'Sarah Jenkins',
    serviceName: 'Full Grooming & Spa Deluxe',
  );

  final screenSizes = [
    const Size(320, 568), // Smallest mobile (iPhone SE 1st gen)
    const Size(360, 800), // Standard Android
    const Size(375, 812), // iPhone X / Mini
    const Size(390, 844), // iPhone 12 / 13 / 14
    const Size(412, 915), // Large Android
  ];

  for (final size in screenSizes) {
    testWidgets('Groomer notification tile does not overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'New Booking Request #${testBooking.bookingId}',
                                    style: AppFonts.poppins(
                                      size: 13.5,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Pending Review',
                                    style: AppFonts.poppins(
                                      size: 11,
                                      color: const Color(0xFF9CA3AF),
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${testBooking.customerName} requested ${testBooking.serviceName} for ${testBooking.petName}.',
                              style: AppFonts.poppins(
                                size: 12.5,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFD97706)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Acceptance Deadline: Scheduled start (${testBooking.startTime})',
                                      style: AppFonts.poppins(
                                        size: 10.5,
                                        weight: FontWeight.w600,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () {},
                                  child: Text(
                                    'Approve',
                                    style: AppFonts.poppins(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () {},
                                  child: Text(
                                    'Reject',
                                    style: AppFonts.poppins(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Groomer cancellation tile does not overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          size: 18,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Cancellation Request #${testBooking.bookingId}',
                                    style: AppFonts.poppins(
                                      size: 13.5,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Action Required',
                                    style: AppFonts.poppins(
                                      size: 11,
                                      color: const Color(0xFFDC2626),
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${testBooking.customerName} requested to cancel booking for ${testBooking.petName} on ${testBooking.formattedBookingDate}.',
                              style: AppFonts.poppins(
                                size: 12.5,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () {},
                                  child: Text(
                                    'Approve Cancellation',
                                    style: AppFonts.poppins(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4B5563),
                                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  onPressed: () {},
                                  child: Text(
                                    'Reject',
                                    style: AppFonts.poppins(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Groomer notification metrics row does not overflow at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Widget buildMetricCard({
        required String label,
        required int count,
        required IconData icon,
        required Color color,
        required Color bgColor,
      }) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: count > 0 ? color.withValues(alpha: 0.35) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$count',
                      style: AppFonts.parkinsans(
                        size: 15,
                        weight: FontWeight.w700,
                        color: count > 0 ? color : const Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppFonts.poppins(
                  size: 10.5,
                  weight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: buildMetricCard(
                      label: 'Pending',
                      count: 12,
                      icon: Icons.hourglass_top_rounded,
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildMetricCard(
                      label: 'Cancellations',
                      count: 5,
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: buildMetricCard(
                      label: 'System Alerts',
                      count: 99,
                      icon: Icons.notifications_none_rounded,
                      color: const Color(0xFF0F766E),
                      bgColor: const Color(0xFFF0FDFA),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
