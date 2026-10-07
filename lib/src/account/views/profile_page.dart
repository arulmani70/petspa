import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/profile_page_mobile.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const ProfilePageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const ProfilePageMobile()),
        Condition.smallerThan(name: TABLET, value: const ProfilePageMobile()),
      ],
    ).value;
  }
}
