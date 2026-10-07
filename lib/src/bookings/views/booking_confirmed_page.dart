import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/booking_confirmed_page_mobile.dart';

class BookingConfirmedPage extends StatelessWidget {
  const BookingConfirmedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const BookingConfirmedPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const BookingConfirmedPageMobile()),
        Condition.smallerThan(name: TABLET, value: const BookingConfirmedPageMobile()),
      ],
    ).value;
  }
}
