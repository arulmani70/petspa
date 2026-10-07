import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/help_support_page_mobile.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const HelpSupportPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const HelpSupportPageMobile()),
        Condition.smallerThan(name: TABLET, value: const HelpSupportPageMobile()),
      ],
    ).value;
  }
}
