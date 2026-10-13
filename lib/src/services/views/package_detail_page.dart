import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'mobile/package_detail_page_mobile.dart';

class PackageDetailPage extends StatelessWidget {
  final String packageId;
  final Map<String, dynamic>? package;
  const PackageDetailPage({super.key, required this.packageId, this.package});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ServiceBloc(
        repository: ServicesLocator.serviceRepository,
      )..add(GetPackageDetail(packageId, initialPackage: package)),
      child: ResponsiveValue<Widget>(
        context,
        defaultValue: PackageDetailPageMobile(packageId: packageId, initialPackage: package),
        conditionalValues: [
          Condition.equals(
            name: TABLET,
            value: PackageDetailPageMobile(packageId: packageId, initialPackage: package),
          ),
          Condition.smallerThan(
            name: TABLET,
            value: PackageDetailPageMobile(packageId: packageId, initialPackage: package),
          ),
        ],
      ).value,
    );
  }
}
