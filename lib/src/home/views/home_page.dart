import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/home_page_mobile.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const HomePageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const HomePageMobile()),
        Condition.smallerThan(name: TABLET, value: const HomePageMobile()),
      ],
    ).value;
  }
}
