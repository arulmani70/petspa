import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/chat/bloc/chat_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'mobile/chat_page_mobile.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    const mobileView = ChatPageMobile();

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
      context.read<ChatBloc>();
      return child;
    } catch (_) {
      return BlocProvider<ChatBloc>(
        create: (_) => ChatBloc(repository: ServicesLocator.chatRepository),
        child: child,
      );
    }
  }
}
