import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shear_heaven_pet_spa/src/account/bloc/profile_bloc.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/bookings/bloc/booking_bloc.dart';
import 'package:shear_heaven_pet_spa/src/chat/bloc/chat_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/content/bloc/content_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/bloc/groomer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/bloc/groomer_login_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/bloc/groomer_register_bloc.dart';
import 'package:shear_heaven_pet_spa/src/notifications/bloc/notification_bloc.dart';
import 'package:shear_heaven_pet_spa/src/offers/bloc/offer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // Figma sets letterSpacing 0.0 on every text node; strip the M3 default
  // tracking (0.25/0.5) the theme would otherwise inherit.
  TextTheme _exactTextTheme(TextTheme t) => TextTheme(
        displayLarge: t.displayLarge?.copyWith(letterSpacing: 0),
        displayMedium: t.displayMedium?.copyWith(letterSpacing: 0),
        displaySmall: t.displaySmall?.copyWith(letterSpacing: 0),
        headlineLarge: t.headlineLarge?.copyWith(letterSpacing: 0),
        headlineMedium: t.headlineMedium?.copyWith(letterSpacing: 0),
        headlineSmall: t.headlineSmall?.copyWith(letterSpacing: 0),
        titleLarge: t.titleLarge?.copyWith(letterSpacing: 0),
        titleMedium: t.titleMedium?.copyWith(letterSpacing: 0),
        titleSmall: t.titleSmall?.copyWith(letterSpacing: 0),
        bodyLarge: t.bodyLarge?.copyWith(letterSpacing: 0),
        bodyMedium: t.bodyMedium?.copyWith(letterSpacing: 0),
        bodySmall: t.bodySmall?.copyWith(letterSpacing: 0),
        labelLarge: t.labelLarge?.copyWith(letterSpacing: 0),
        labelMedium: t.labelMedium?.copyWith(letterSpacing: 0),
        labelSmall: t.labelSmall?.copyWith(letterSpacing: 0),
      );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (context) => AuthBloc(repository: ServicesLocator.authRepository)),
        BlocProvider<PetBloc>(create: (context) => PetBloc(repository: ServicesLocator.petRepository)),
        BlocProvider<ServiceBloc>(create: (context) => ServiceBloc(repository: ServicesLocator.serviceRepository)),
        BlocProvider<BookingBloc>(create: (context) => BookingBloc(repository: ServicesLocator.bookingRepository)),
        BlocProvider<NotificationBloc>(create: (context) => NotificationBloc(repository: ServicesLocator.notificationRepository)),
        BlocProvider<OfferBloc>(create: (context) => OfferBloc(repository: ServicesLocator.offerRepository)),
        BlocProvider<ChatBloc>(create: (context) => ChatBloc(repository: ServicesLocator.chatRepository)),
        BlocProvider<ContentBloc>(create: (context) => ContentBloc(repository: ServicesLocator.contentRepository)),
        BlocProvider<ProfileBloc>(create: (context) => ProfileBloc(repository: ServicesLocator.authRepository)),
        BlocProvider<GroomerLoginBloc>(create: (context) => GroomerLoginBloc(repository: ServicesLocator.groomerLoginRepository)),
        BlocProvider<GroomerRegisterBloc>(create: (context) => GroomerRegisterBloc(repository: ServicesLocator.groomerRegisterRepository)),
        BlocProvider<GroomerHomeBloc>(create: (context) => GroomerHomeBloc(repository: ServicesLocator.groomerHomeRepository)),
        BlocProvider<GroomerBloc>(create: (context) => GroomerBloc(repository: ServicesLocator.groomerRepository)),
      ],
      child: MaterialApp.router(
        title: 'Shear Heaven Pet Spa',
        theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          secondary: Colors.grey.shade800,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        textTheme: _exactTextTheme(GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
        child: child!,
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: Routes().router,
    ),
    );
  }
}
