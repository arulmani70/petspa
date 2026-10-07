import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/privacy_policy_page_mobile.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const PrivacyPolicyPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const PrivacyPolicyPageMobile()),
        Condition.smallerThan(name: TABLET, value: const PrivacyPolicyPageMobile()),
      ],
    ).value;
  }
}
