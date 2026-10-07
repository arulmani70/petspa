import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'mobile/groomer_home_page_mobile.dart';

class GroomerHomePage extends StatelessWidget {
  const GroomerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const mobileView = GroomerHomePageMobile();

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
      context.read<GroomerHomeBloc>();
      return child;
    } catch (_) {
      return BlocProvider<GroomerHomeBloc>(
        create: (_) => GroomerHomeBloc(repository: ServicesLocator.groomerHomeRepository),
        child: child,
      );
    }
  }
}
