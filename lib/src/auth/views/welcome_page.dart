import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/welcome_page_mobile.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const WelcomePageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const WelcomePageMobile()),
        Condition.smallerThan(name: TABLET, value: const WelcomePageMobile()),
      ],
    ).value;
  }
}
