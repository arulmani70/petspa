import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/offers/bloc/offer_bloc.dart';
import 'mobile/offers_page_mobile.dart';

class OffersPage extends StatelessWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    const mobileView = OffersPageMobile();

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
      context.read<OfferBloc>();
      return child;
    } catch (_) {
      return BlocProvider<OfferBloc>(
        create: (_) => OfferBloc(repository: ServicesLocator.offerRepository),
        child: child,
      );
    }
  }
}
