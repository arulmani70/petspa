import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/pet_select_page_mobile.dart';

class PetSelectPage extends StatelessWidget {
  final Map<String, dynamic>? initialBookingData;
  const PetSelectPage({super.key, this.initialBookingData});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: PetSelectPageMobile(initialBookingData: initialBookingData),
      conditionalValues: [
        Condition.equals(name: TABLET, value: PetSelectPageMobile(initialBookingData: initialBookingData)),
        Condition.smallerThan(name: TABLET, value: PetSelectPageMobile(initialBookingData: initialBookingData)),
      ],
    ).value;
  }
}
