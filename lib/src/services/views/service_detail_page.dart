import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';
import 'mobile/service_detail_page_mobile.dart';

class ServiceDetailPage extends StatelessWidget {
  final String serviceId;
  final Map<String, dynamic>? service;
  const ServiceDetailPage({super.key, required this.serviceId, this.service});

  @override
  Widget build(BuildContext context) {
    final pageKey = ValueKey('svc_detail_${serviceId}_${service?['id']}_${service?['name']}');
    final mobileWidget = ServiceDetailPageMobile(
      key: pageKey,
      serviceId: serviceId,
      initialService: service,
    );

    return BlocProvider(
      key: ValueKey('svc_bloc_${serviceId}_${service?['id']}_${service?['name']}'),
      create: (context) {
        ServiceRepository repo;
        try {
          repo = ServicesLocator.serviceRepository;
        } catch (_) {
          repo = ServiceRepository();
        }
        return ServiceBloc(
          repository: repo,
        )..add(GetServiceDetail(serviceId, initialService: service));
      },
      child: Builder(
        builder: (context) {
          try {
            return ResponsiveValue<Widget>(
              context,
              defaultValue: mobileWidget,
              conditionalValues: [
                Condition.equals(
                  name: TABLET,
                  value: mobileWidget,
                ),
                Condition.smallerThan(
                  name: TABLET,
                  value: mobileWidget,
                ),
              ],
            ).value;
          } catch (_) {
            return mobileWidget;
          }
        },
      ),
    );
  }
}

