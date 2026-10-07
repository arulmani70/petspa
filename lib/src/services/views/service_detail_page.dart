import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'mobile/service_detail_page_mobile.dart';

class ServiceDetailPage extends StatelessWidget {
  final String serviceId;
  const ServiceDetailPage({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    return ResponsiveValue<Widget>(
      context,
      defaultValue: ServiceDetailPageMobile(serviceId: serviceId),
      conditionalValues: [
        Condition.equals(name: TABLET, value: ServiceDetailPageMobile(serviceId: serviceId)),
        Condition.smallerThan(name: TABLET, value: ServiceDetailPageMobile(serviceId: serviceId)),
      ],
    ).value;
  }
}
