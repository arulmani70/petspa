import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/terms_condition_page_mobile.dart';

class TermsConditionPage extends StatelessWidget {
  const TermsConditionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const TermsConditionPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const TermsConditionPageMobile()),
        Condition.smallerThan(name: TABLET, value: const TermsConditionPageMobile()),
      ],
    ).value;
  }
}
