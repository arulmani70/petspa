import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/services_page_mobile.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const ServicesPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const ServicesPageMobile()),
        Condition.smallerThan(name: TABLET, value: const ServicesPageMobile()),
      ],
    ).value;
  }
}
