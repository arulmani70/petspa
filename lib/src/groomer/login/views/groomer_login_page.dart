import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/bloc/groomer_login_bloc.dart';
import 'mobile/groomer_login_page_mobile.dart';

class GroomerLoginPage extends StatelessWidget {
  const GroomerLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    const mobileView = GroomerLoginPageMobile();

    Widget child;
    try {
      child = ResponsiveValue<Widget>(
        context,
        defaultValue: mobileView,
        conditionalValues: [
          Condition.equals(name: TABLET, value: mobileView),
          Condition.smallerThan(name: TABLET, value: mobileView),
        ],
      ).value;
    } catch (_) {
      child = mobileView;
    }

    try {
      context.read<GroomerLoginBloc>();
      return child;
    } catch (_) {
      return BlocProvider<GroomerLoginBloc>(
        create: (_) => GroomerLoginBloc(repository: ServicesLocator.groomerLoginRepository),
        child: child,
      );
    }
  }
}
