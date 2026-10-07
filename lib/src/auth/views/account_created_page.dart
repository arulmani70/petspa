import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/account_created_page_mobile.dart';

class AccountCreatedPage extends StatelessWidget {
  const AccountCreatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const AccountCreatedPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const AccountCreatedPageMobile()),
        Condition.smallerThan(name: TABLET, value: const AccountCreatedPageMobile()),
      ],
    ).value;
  }
}
