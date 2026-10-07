import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/pet_select_page_mobile.dart';

class PetSelectPage extends StatelessWidget {
  const PetSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const PetSelectPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const PetSelectPageMobile()),
        Condition.smallerThan(name: TABLET, value: const PetSelectPageMobile()),
      ],
    ).value;
  }
}
