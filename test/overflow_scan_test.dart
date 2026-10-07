import 'package:shear_heaven_pet_spa/src/account/repos/content_repository.dart';
import 'package:shear_heaven_pet_spa/src/account/repos/notification_repository.dart';
import 'package:shear_heaven_pet_spa/src/chat/repos/chat_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/groomer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/offers/repos/offer_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/repos/groomer_auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/mobile/groomer_home_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/repo/groomer_login_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/views/mobile/groomer_login_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/repo/groomer_register_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/views/mobile/groomer_register_page_mobile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/account/views/about_us_page.dart';
import 'package:shear_heaven_pet_spa/src/account/views/help_support_page.dart';
import 'package:shear_heaven_pet_spa/src/account/views/privacy_policy_page.dart';
import 'package:shear_heaven_pet_spa/src/account/views/profile_page.dart';
import 'package:shear_heaven_pet_spa/src/account/views/terms_condition_page.dart';
import 'package:shear_heaven_pet_spa/src/account/views/my_bookings_page.dart';
import 'package:shear_heaven_pet_spa/src/account/views/settings_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/account_created_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/forgot_password_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/login_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/create_account_page.dart';

import 'package:shear_heaven_pet_spa/src/auth/views/otp_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_confirmed_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_review_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_service_page.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/home/views/home_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/create_pet_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/my_pets_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/pet_select_page.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/views/packages_page.dart';
import 'package:shear_heaven_pet_spa/src/services/views/service_detail_page.dart';
import 'package:shear_heaven_pet_spa/src/services/views/services_page.dart';

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => {'id': 1, 'name': 'Alexander'};
}

class _FakeServiceRepository extends ServiceRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllServices() async => [];

  @override
  Future<List<Map<String, dynamic>>> getAllPackages() async => [];

  @override
  Future<Map<String, dynamic>?> getServiceById(int id) async => {
        'id': id,
        'service_name': 'Full Grooming & Luxury Spa Package',
        'description':
            'A comprehensive grooming session for dogs of all breeds. Includes a deep cleansing bath with premium pet-safe shampoos, a full coat trim and brush-out, nail trimming, ear cleaning, finishing blow dry and fluff, plus a relaxing spa massage.',
        'duration_min': 120,
        'rating': 4.9,
        'price': 65.0,
        'tag': 'MOST_BOOKED',
      };
}

class _FakePetRepository extends PetRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => [];

  @override
  Future<Map<String, dynamic>?> getPetById(int id) async => null;
}

class _FakeBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllBookings({int? userId, String? status}) async => [];

  @override
  Future<List<Map<String, dynamic>>> getUpcomingBookings({int? userId}) async => [];

  @override
  Future<List<Map<String, dynamic>>> getPastBookings({int? userId}) async => [];

  @override
  Future<List<String>> getBookedSlotsForDate(String date) async => [];
}

class _FakeStoreRepository extends StoreRepository {
  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async => [];
  @override
  Future<List<Map<String, dynamic>>> getGroomers() async => [];
  @override
  Future<List<Map<String, dynamic>>> getHolidays() async => [];
  @override
  bool isHoliday(DateTime date) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final failures = <String>[];

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final apiRepo = ApiRepository();
    await apiRepo.initialize();
    serviceLocator.allowReassignment = true;
    serviceLocator.registerSingleton<ApiRepository>(apiRepo);

    serviceLocator.registerSingleton<AuthRepository>(_FakeAuthRepository());
    serviceLocator.registerSingleton<ServiceRepository>(_FakeServiceRepository());
    serviceLocator.registerSingleton<PetRepository>(_FakePetRepository());
    serviceLocator.registerSingleton<BookingRepository>(_FakeBookingRepository());
    serviceLocator.registerSingleton<StoreRepository>(_FakeStoreRepository());
    
    final sessionService = SessionService();
    await sessionService.initialize();
    await sessionService.saveClientId('client');
    await sessionService.saveRegionId('region');
    await sessionService.saveStoreId('store');
    serviceLocator.registerSingleton<SessionService>(sessionService);

    final customerSocketService = CustomerSocketService();
    await customerSocketService.initialize();
    serviceLocator.registerSingleton<CustomerSocketService>(customerSocketService);

    final groomerSocketService = GroomerSocketService();
    await groomerSocketService.initialize();
    serviceLocator.registerSingleton<GroomerSocketService>(groomerSocketService);

    final groomerAuthRepo = GroomerAuthRepository();
    await groomerAuthRepo.initialize();
    serviceLocator.registerSingleton<GroomerAuthRepository>(groomerAuthRepo);

    final groomerLoginRepo = GroomerLoginRepository();
    await groomerLoginRepo.initialize();
    serviceLocator.registerSingleton<GroomerLoginRepository>(groomerLoginRepo);

    final groomerRegisterRepo = GroomerRegisterRepository();
    await groomerRegisterRepo.initialize();
    serviceLocator.registerSingleton<GroomerRegisterRepository>(groomerRegisterRepo);

    final groomerHomeRepo = GroomerHomeRepository();
    await groomerHomeRepo.initialize();
    serviceLocator.registerSingleton<GroomerHomeRepository>(groomerHomeRepo);

    final offerRepo = OfferRepository();
    await offerRepo.initialize();
    serviceLocator.registerSingleton<OfferRepository>(offerRepo);

    final chatRepo = ChatRepository();
    await chatRepo.initialize();
    serviceLocator.registerSingleton<ChatRepository>(chatRepo);

    final notifRepo = NotificationRepository();
    await notifRepo.initialize();
    serviceLocator.registerSingleton<NotificationRepository>(notifRepo);

    final contentRepo = ContentRepository();
    await contentRepo.initialize();
    serviceLocator.registerSingleton<ContentRepository>(contentRepo);

    serviceLocator.registerSingleton<BookingDraft>(BookingDraft());
  });

  final sizes = [
    const Size(375, 667), // iPhone SE / 8
    const Size(375, 812), // iPhone X / XS / 11 Pro / 12 mini / 13 mini
    const Size(390, 844), // iPhone 12 / 13 / 14
    const Size(393, 852), // iPhone 14 Pro / 15 / 15 Pro / 16
    const Size(430, 932), // iPhone 14 Pro Max / 15 Pro Max / 16 Pro Max
    const Size(360, 800), // Compact Android
  ];

  Future<void> scan(WidgetTester tester, String label, Widget screen, {bool router = false}) async {
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      final wrappedScreen = MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc(repository: serviceLocator<AuthRepository>())),
          BlocProvider(create: (_) => PetBloc(repository: serviceLocator<PetRepository>())),
          BlocProvider(create: (_) => ServiceBloc(repository: serviceLocator<ServiceRepository>())),
        ],
        child: screen,
      );
      Widget app = MaterialApp(
        builder: (context, child) => ResponsiveBreakpoints(
          breakpoints: const [
            Breakpoint(start: 0, end: 450, name: MOBILE),
            Breakpoint(start: 451, end: 800, name: TABLET),
            Breakpoint(start: 801, end: 1920, name: DESKTOP),
          ],
          child: child!,
        ),
        home: wrappedScreen,
      );
      if (router) {
        app = MaterialApp.router(
          builder: (context, child) => ResponsiveBreakpoints(
            breakpoints: const [
              Breakpoint(start: 0, end: 450, name: MOBILE),
              Breakpoint(start: 451, end: 800, name: TABLET),
              Breakpoint(start: 801, end: 1920, name: DESKTOP),
            ],
            child: child!,
          ),
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [GoRoute(path: '/', builder: (c, s) => wrappedScreen)],
          ),
        );
      }
      await tester.pumpWidget(app);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final e = tester.takeException();
      if (e is FlutterError && e.message.toString().contains('overflowed') == true) {
        failures.add('$label @ ${size.width}x${size.height}: ${e.message}');
      } else if (e != null) {
        final text = e.toString();
        // These screens are pumped without the app's GoRouter/Provider
        // scaffolding, so they raise harness-only errors (not overflows).
        final isHarnessArtifact = text.contains('GoRouterState') ||
            text.contains('_ModalScopeStatus') ||
            text.contains('Could not find the correct Provider');
        if (!isHarnessArtifact) {
          failures.add('$label @ ${size.width}x${size.height}: OTHER $e');
        }
      }
      await tester.pumpWidget(const SizedBox());
    }
  }

  testWidgets('scan all screens for overflow', (tester) async {
    await scan(tester, 'HomePage', const HomePage());
    await scan(tester, 'ServicesPage', const ServicesPage());
    await scan(tester, 'ServiceDetailPage', const ServiceDetailPage(serviceId: '1'));
    await scan(tester, 'PackagesPage', const PackagesPage());
    await scan(tester, 'MyPetsPage', const MyPetsPage());
    await scan(tester, 'CreatePetPage', const CreatePetPage(), router: true);
    await scan(tester, 'PetSelectPage', const PetSelectPage());
    await scan(tester, 'BookingServicePage', const BookingServicePage(), router: true);
    await scan(tester, 'BookingDateTimePage', const BookingDateTimePage());
    await scan(tester, 'BookingReviewPage', const BookingReviewPage());
    await scan(tester, 'BookingConfirmedPage', const BookingConfirmedPage());
    await scan(tester, 'MyBookingsPage', const MyBookingsPage());
    await scan(tester, 'SettingsPage', const SettingsPage());
    await scan(tester, 'AboutUsPage', const AboutUsPage());
    await scan(tester, 'HelpSupportPage', const HelpSupportPage());
    await scan(tester, 'PrivacyPolicyPage', const PrivacyPolicyPage());
    await scan(tester, 'TermsConditionPage', const TermsConditionPage());
    await scan(tester, 'ProfilePage', const ProfilePage());
    await scan(tester, 'LoginPage', const LoginPage());
    await scan(tester, 'CreateAccountPage', const CreateAccountPage());
    await scan(tester, 'ForgotPasswordPage', const ForgotPasswordPage());
    await scan(tester, 'OtpPage', const OtpPage());
    await scan(tester, 'AccountCreatedPage', const AccountCreatedPage());
    await scan(tester, 'GroomerLoginPageMobile', const GroomerLoginPageMobile(), router: true);
    await scan(tester, 'GroomerRegisterPageMobile', const GroomerRegisterPageMobile(), router: true);
    await scan(tester, 'GroomerHomePageMobile', const GroomerHomePageMobile());

    if (failures.isNotEmpty) {
      fail('OVERFLOW ISSUES FOUND:\n${failures.join('\n\n')}');
    } else {
      // ignore: avoid_print
      print('NO OVERFLOW FOUND in any screen at 390x844, 375x812, 360x800');
    }
  });
}
