import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/booking_review_page_mobile.dart';

class BookingReviewPage extends StatelessWidget {
  const BookingReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const BookingReviewPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const BookingReviewPageMobile()),
        Condition.smallerThan(name: TABLET, value: const BookingReviewPageMobile()),
      ],
    ).value;
  }
}
