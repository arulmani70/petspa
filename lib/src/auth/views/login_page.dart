import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/login_page_mobile.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const LoginPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const LoginPageMobile()),
        Condition.smallerThan(name: TABLET, value: const LoginPageMobile()),
      ],
    ).value;
  }
}

