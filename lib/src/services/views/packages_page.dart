import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/packages_page_mobile.dart';

class PackagesPage extends StatelessWidget {
  const PackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const PackagesPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const PackagesPageMobile()),
        Condition.smallerThan(name: TABLET, value: const PackagesPageMobile()),
      ],
    ).value;
  }
}
