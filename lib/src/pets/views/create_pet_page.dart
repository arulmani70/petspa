import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/create_pet_page_mobile.dart';

class CreatePetPage extends StatelessWidget {
  final Map<String, dynamic>? initialPetData;
  const CreatePetPage({super.key, this.initialPetData});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: CreatePetPageMobile(initialPetData: initialPetData),
      conditionalValues: [
        Condition.equals(name: TABLET, value: CreatePetPageMobile(initialPetData: initialPetData)),
        Condition.smallerThan(name: TABLET, value: CreatePetPageMobile(initialPetData: initialPetData)),
      ],
    ).value;
  }
}
