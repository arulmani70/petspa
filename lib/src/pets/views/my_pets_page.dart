import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/my_pets_page_mobile.dart';

class MyPetsPage extends StatelessWidget {
  const MyPetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const MyPetsPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const MyPetsPageMobile()),
        Condition.smallerThan(name: TABLET, value: const MyPetsPageMobile()),
      ],
    ).value;
  }
}
