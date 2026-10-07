import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'mobile/booking_service_page_mobile.dart';

class BookingServicePage extends StatelessWidget {
  const BookingServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ServiceBloc(repository: ServicesLocator.serviceRepository)..add(const InitializeServices()),
      child: ResponsiveValue<Widget>(
        context,
        defaultValue: const BookingServicePageMobile(),
        conditionalValues: [
          Condition.equals(name: TABLET, value: const BookingServicePageMobile()),
          Condition.smallerThan(name: TABLET, value: const BookingServicePageMobile()),
        ],
      ).value,
    );
  }
}
