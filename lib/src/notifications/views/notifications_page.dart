import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/notifications/bloc/notification_bloc.dart';
import 'mobile/notifications_page_mobile.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const mobileView = NotificationsPageMobile();

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
      context.read<NotificationBloc>();
      return child;
    } catch (_) {
      return BlocProvider<NotificationBloc>(
        create: (_) => NotificationBloc(repository: ServicesLocator.notificationRepository),
        child: child,
      );
    }
  }
}
