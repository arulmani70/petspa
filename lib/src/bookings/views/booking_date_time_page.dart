import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/booking_date_time_page_mobile.dart';

class BookingDateTimePage extends StatelessWidget {
  const BookingDateTimePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const BookingDateTimePageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const BookingDateTimePageMobile()),
        Condition.smallerThan(name: TABLET, value: const BookingDateTimePageMobile()),
      ],
    ).value;
  }
}
