import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/my_bookings_page_mobile.dart';

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const MyBookingsPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const MyBookingsPageMobile()),
        Condition.smallerThan(name: TABLET, value: const MyBookingsPageMobile()),
      ],
    ).value;
  }
}
