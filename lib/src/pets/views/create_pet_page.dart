import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/create_pet_page_mobile.dart';

class CreatePetPage extends StatelessWidget {
  const CreatePetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const CreatePetPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const CreatePetPageMobile()),
        Condition.smallerThan(name: TABLET, value: const CreatePetPageMobile()),
      ],
    ).value;
  }
}
