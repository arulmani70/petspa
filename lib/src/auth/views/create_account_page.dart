import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/create_account_page_mobile.dart';

class CreateAccountPage extends StatelessWidget {
  const CreateAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const CreateAccountPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const CreateAccountPageMobile()),
        Condition.smallerThan(name: TABLET, value: const CreateAccountPageMobile()),
      ],
    ).value;
  }
}
