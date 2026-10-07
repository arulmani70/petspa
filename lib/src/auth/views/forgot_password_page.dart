import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/forgot_password_page_mobile.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: const ForgotPasswordPageMobile(),
      conditionalValues: [
        Condition.equals(name: TABLET, value: const ForgotPasswordPageMobile()),
        Condition.smallerThan(name: TABLET, value: const ForgotPasswordPageMobile()),
      ],
    ).value;
  }
}
