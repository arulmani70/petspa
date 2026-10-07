import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/bloc/groomer_register_bloc.dart';
import 'mobile/groomer_register_page_mobile.dart';

class GroomerRegisterPage extends StatelessWidget {
  final String? tempLoginId;
  final String? tempPassword;

  const GroomerRegisterPage({
    super.key,
    this.tempLoginId,
    this.tempPassword,
  });

  @override
  Widget build(BuildContext context) {
    final mobileView = GroomerRegisterPageMobile(
      tempLoginId: tempLoginId,
      tempPassword: tempPassword,
    );

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
      context.read<GroomerRegisterBloc>();
      return child;
    } catch (_) {
      return BlocProvider<GroomerRegisterBloc>(
        create: (_) => GroomerRegisterBloc(repository: ServicesLocator.groomerRegisterRepository),
        child: child,
      );
    }
  }
}
