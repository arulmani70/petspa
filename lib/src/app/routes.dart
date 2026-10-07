import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/account/views/profile_page.dart';
import 'package:shear_heaven_pet_spa/src/account/views/settings_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/my_bookings_page.dart';
import 'package:shear_heaven_pet_spa/src/content/views/about_us_page.dart';
import 'package:shear_heaven_pet_spa/src/content/views/help_support_page.dart';
import 'package:shear_heaven_pet_spa/src/content/views/privacy_policy_page.dart';
import 'package:shear_heaven_pet_spa/src/content/views/terms_condition_page.dart';
import 'package:shear_heaven_pet_spa/src/notifications/views/notifications_page.dart';
import 'package:shear_heaven_pet_spa/src/offers/views/offers_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/welcome_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/splash_screens.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/login_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/create_account_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/forgot_password_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/otp_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/account_created_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_confirmed_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_review_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_service_page.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/file_not_found.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/splashscreen.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/groomer_home_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/views/groomer_login_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/views/groomer_register_page.dart';
import 'package:shear_heaven_pet_spa/src/home/views/home_page.dart';
import 'package:shear_heaven_pet_spa/src/home/views/gallery_page.dart';


import 'package:shear_heaven_pet_spa/src/chat/views/chat_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/create_pet_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/my_pets_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/pet_select_page.dart';
import 'package:shear_heaven_pet_spa/src/shell/main_shell.dart';
import 'package:shear_heaven_pet_spa/src/services/views/packages_page.dart';
import 'package:shear_heaven_pet_spa/src/services/views/service_detail_page.dart';
import 'package:shear_heaven_pet_spa/src/services/views/services_page.dart';

class Routes {
  final log = Logger();
  static final Logger _staticLog = Logger();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter _router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/${RouteNames.firstScreen}',
    routes: [
      GoRoute(
        name: RouteNames.firstScreen,
        path: '/${RouteNames.firstScreen}',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: RouteNames.welcome,
        path: '/${RouteNames.welcome}',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        name: RouteNames.splash,
        path: '/${RouteNames.splash}',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreens();
        },
      ),

      GoRoute(
        name: RouteNames.onboarding,
        path: '/${RouteNames.onboarding}',
        builder: (context, state) => const SplashScreens(),
      ),

      GoRoute(
        name: RouteNames.login,
        path: '/${RouteNames.login}',
        builder: (context, state) => const LoginPage(),
      ),

      GoRoute(
        name: RouteNames.signup,
        path: '/${RouteNames.signup}',
        builder: (context, state) => const CreateAccountPage(),
      ),

      GoRoute(
        name: RouteNames.forgotPassword,
        path: '/${RouteNames.forgotPassword}',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      GoRoute(
        name: RouteNames.otp,
        path: '/${RouteNames.otp}',
        builder: (context, state) => const OtpPage(),
      ),

      GoRoute(
        name: RouteNames.accountCreated,
        path: '/${RouteNames.accountCreated}',
        builder: (context, state) => const AccountCreatedPage(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.home,
                path: '/${RouteNames.home}',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.services,
                path: '/${RouteNames.services}',
                builder: (context, state) => const ServicesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.chat,
                path: '/${RouteNames.chat}',
                builder: (context, state) => const ChatPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.myBookings,
                path: '/${RouteNames.myBookings}',
                builder: (context, state) => const MyBookingsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: RouteNames.settings,
                path: '/${RouteNames.settings}',
                builder: (context, state) => const SettingsPage(),
              ),
              GoRoute(
                name: RouteNames.profile,
                path: '/${RouteNames.profile}',
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                name: RouteNames.aboutUs,
                path: '/${RouteNames.aboutUs}',
                builder: (context, state) => const AboutUsPage(),
              ),
              GoRoute(
                name: RouteNames.helpSupport,
                path: '/${RouteNames.helpSupport}',
                builder: (context, state) => const HelpSupportPage(),
              ),
              GoRoute(
                name: RouteNames.privacyPolicy,
                path: '/${RouteNames.privacyPolicy}',
                builder: (context, state) => const PrivacyPolicyPage(),
              ),
              GoRoute(
                name: RouteNames.termsCondition,
                path: '/${RouteNames.termsCondition}',
                builder: (context, state) => const TermsConditionPage(),
              ),
              GoRoute(
                name: RouteNames.notifications,
                path: '/${RouteNames.notifications}',
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        name: RouteNames.offers,
        path: '/',
        builder: (context, state) => const OffersPage(),
      ),

      GoRoute(
        name: RouteNames.serviceDetail,
        path: '/${RouteNames.services}/:serviceId',
        builder: (context, state) => ServiceDetailPage(
          serviceId: state.pathParameters['serviceId'] ?? '',
        ),
      ),

      GoRoute(
        name: RouteNames.packages,
        path: '/${RouteNames.packages}',
        builder: (context, state) => const PackagesPage(),
      ),

      GoRoute(
        name: RouteNames.gallery,
        path: '/${RouteNames.gallery}',
        builder: (context, state) => const GalleryPage(),
      ),

      GoRoute(
        name: RouteNames.petSelect,
        path: '/${RouteNames.petSelect}',
        builder: (context, state) => const PetSelectPage(),
      ),

      GoRoute(
        name: RouteNames.myPets,
        path: '/${RouteNames.myPets}',
        builder: (context, state) => const MyPetsPage(),
      ),

      GoRoute(
        name: RouteNames.createPet,
        path: '/${RouteNames.createPet}',
        builder: (context, state) => const CreatePetPage(),
      ),

      GoRoute(
        name: RouteNames.bookingService,
        path: '/${RouteNames.bookingService}',
        builder: (context, state) => const BookingServicePage(),
      ),

      GoRoute(
        name: RouteNames.bookingDateTime,
        path: '/${RouteNames.bookingDateTime}',
        builder: (context, state) => const BookingDateTimePage(),
      ),

      GoRoute(
        name: RouteNames.bookingReview,
        path: '/${RouteNames.bookingReview}',
        builder: (context, state) => const BookingReviewPage(),
      ),

      GoRoute(
        name: RouteNames.bookingConfirmed,
        path: '/${RouteNames.bookingConfirmed}',
        builder: (context, state) => const BookingConfirmedPage(),
      ),

      GoRoute(
        name: RouteNames.groomerLogin,
        path: '/${RouteNames.groomerLogin}',
        builder: (context, state) => const GroomerLoginPage(),
      ),

      GoRoute(
        name: RouteNames.groomerRegister,
        path: '/${RouteNames.groomerRegister}',
        builder: (context, state) {
          final extra = state.extra is Map ? state.extra as Map : null;
          return GroomerRegisterPage(
            tempLoginId: extra?['tempLoginId']?.toString(),
            tempPassword: extra?['tempPassword']?.toString(),
          );
        },
      ),

      GoRoute(
        name: RouteNames.groomerHome,
        path: '/${RouteNames.groomerHome}',
        builder: (context, state) => const GroomerHomePage(),
      ),
    ],
    errorBuilder: (context, state) {
      return FileNotFound(message: "${state.error?.message}");
    },
  );

  GoRouter get router => _router;
  static GoRouter get globalRouter => _router;

  static void redirectToLogin({bool isGroomer = false}) {
    try {
      final targetRoute = isGroomer ? '/${RouteNames.groomerLogin}' : '/${RouteNames.login}';
      String? currentRoute;
      try {
        currentRoute = _router.routerDelegate.currentConfiguration.uri.toString();
      } catch (_) {}

      if (currentRoute != null &&
          (currentRoute == targetRoute ||
              currentRoute == '/${RouteNames.welcome}' ||
              currentRoute == '/${RouteNames.firstScreen}')) {
        _staticLog.d('Routes::redirectToLogin::Already at or navigating to $currentRoute, skipping redirect');
        return;
      }

      _staticLog.i('Routes::redirectToLogin::Redirecting to $targetRoute from $currentRoute');
      _router.go(targetRoute);
    } catch (e) {
      _staticLog.e('Routes::redirectToLogin::Error: $e');
    }
  }
}

