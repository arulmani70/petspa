import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/otp_page_mobile.dart';

class OtpPage extends StatelessWidget {
  const OtpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const OtpPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const OtpPageMobile()),
        Condition.smallerThan(name: TABLET, value: const OtpPageMobile()),
      ],
    ).value;
  }
}
