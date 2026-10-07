import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/splash_screens_mobile.dart';

class SplashScreens extends StatelessWidget {
  const SplashScreens({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const SplashScreensMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const SplashScreensMobile()),
        Condition.smallerThan(name: TABLET, value: const SplashScreensMobile()),
      ],
    ).value;
  }
}
