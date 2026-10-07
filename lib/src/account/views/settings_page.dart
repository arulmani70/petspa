import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/settings_page_mobile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const SettingsPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const SettingsPageMobile()),
        Condition.smallerThan(name: TABLET, value: const SettingsPageMobile()),
      ],
    ).value;
  }
}
