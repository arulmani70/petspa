import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/about_us_page_mobile.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const AboutUsPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const AboutUsPageMobile()),
        Condition.smallerThan(name: TABLET, value: const AboutUsPageMobile()),
      ],
    ).value;
  }
}
