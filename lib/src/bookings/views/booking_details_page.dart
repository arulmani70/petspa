import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/booking_details_page_mobile.dart';

class BookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic>? bookingData;

  const BookingDetailsPage({
    super.key,
    this.bookingData,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: BookingDetailsPageMobile(bookingData: bookingData),
      conditionalValues: [
        Condition.equals(name: TABLET, value: BookingDetailsPageMobile(bookingData: bookingData)),
        Condition.smallerThan(name: TABLET, value: BookingDetailsPageMobile(bookingData: bookingData)),
      ],
    ).value;
  }
}
