import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/account/views/my_bookings_page.dart';
import 'package:shear_heaven_pet_spa/src/account/views/settings_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/account_created_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/create_account_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/forgot_password_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/login_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/otp_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/splash_screens.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/welcome_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_confirmed_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_review_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_service_page.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
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
  Future<BookingServicesResult> getBookingServices() async => BookingServicesResult(
    breeds: [],
    packages: [],
    addOns: [],
    walkIn: [],
  );

  @override
  Future<Map<String, dynamic>?> getServiceById(int id) async => {
        'id': id,
        'service_name': 'Full Grooming',
        'description':
            'Our Full Service Pet Grooming includes a refreshing bath, blow drying, brushing, haircut, styling, Nail Clipping, ear cleaning, and finishing touches. Every grooming session is tailored to your dog\'s breed coat condition, and individual needs.',
        'duration_min': 0,
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
  Future<List<Map<String, dynamic>>> getUpcomingBookingsApi({bool forceRefresh = false}) async => [];

  @override
  Future<List<Map<String, dynamic>>> getPastBookingsApi() async => [];

  @override
  Future<List<Map<String, dynamic>>> getCancelledBookingsApi() async => [];

  @override
  Future<List<Map<String, dynamic>>> getPastBookings({int? userId}) async => [];

  @override
  Future<List<String>> getBookedSlotsForDate(String date) async => [];
}

const _out = r'C:\Users\arulm\AppData\Local\Temp\opencode\app_texts.txt';

String _esc(String s) => s.replaceAll(r'\', r'\\').replaceAll('\n', r'\n').replaceAll('"', r'"');

Future<void> _pump(WidgetTester tester, Widget page, {bool router = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  final wrapped = MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>(create: (c) => AuthBloc(repository: ServicesLocator.authRepository)),
      BlocProvider<PetBloc>(create: (c) => PetBloc(repository: ServicesLocator.petRepository)),
      BlocProvider<ServiceBloc>(create: (c) => ServiceBloc(repository: ServicesLocator.serviceRepository)),
    ],
    child: page,
  );
  final widget = MaterialApp.router(
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
      routes: [GoRoute(path: '/', builder: (c, s) => wrapped)],
    ),
  );
  await tester.pumpWidget(widget);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  tester.takeException();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
    serviceLocator.allowReassignment = true;
    serviceLocator.registerSingleton<AuthRepository>(_FakeAuthRepository());
    serviceLocator.registerSingleton<ServiceRepository>(_FakeServiceRepository());
    serviceLocator.registerSingleton<PetRepository>(_FakePetRepository());
    serviceLocator.registerSingleton<BookingRepository>(_FakeBookingRepository());
  });

  tearDownAll(() async {
    await ServicesLocator.initialize();
  });

  // (key, widget, needs GoRouter harness)
  final pages = <List<Object>>[
    ['welcome', const WelcomePage(), false, false],
    ['login', const LoginPage(), false, false],
    ['signup', const CreateAccountPage(), false, false],
    ['forgot', const ForgotPasswordPage(), false, false],
    ['otp', const OtpPage(), false, false],
    ['account_created', const AccountCreatedPage(), false, false],
    ['home', const HomePage(), false, true],
    ['pet_select', const PetSelectPage(), false, false],
    ['my_pets', const MyPetsPage(), false, false],
    ['service_select', const BookingServicePage(), true, true],
    ['date_time', const BookingDateTimePage(), false, false],
    ['review_confirm', const BookingReviewPage(), false, false],
    ['booking_confirmed', const BookingConfirmedPage(), false, false],
    ['create_pet', const CreatePetPage(), true, true],
    ['services_list', const ServicesPage(), false, true],
    ['package_list', const PackagesPage(), false, true],
    ['my_bookings', const MyBookingsPage(), false, false],
    ['settings', const SettingsPage(), false, false],
    ['service_inner', const ServiceDetailPage(serviceId: '1'), false, true],
  ];

  Future<void> collect(WidgetTester tester, Map<String, String> out) async {
    for (final e in tester.widgetList<Text>(find.byType(Text))) {
      final st = e.style;
      final s = st == null ? '-' : '${st.fontSize}';
      final w = st?.fontWeight?.toString().replaceAll('FontWeight.', 'w');
      final fam = st?.fontFamily ?? 'default';
      final h = st?.height;
      final ls = st?.letterSpacing;
      final key = e.data ?? '';
      Rect? rect;
      final f = find.text(key);
      if (f.evaluate().isNotEmpty) {
        try {
          rect = tester.getRect(f);
        } catch (_) {}
      }
      final pos = rect == null ? '?,?' : '${rect.left.round()},${rect.top.round()}';
      out.putIfAbsent(_esc(key), () => '$s\t$w\t$fam\t$pos\t$h\t$ls');
    }
  }

  Future<void> dumpCurrent(WidgetTester tester, StringBuffer buf, String label,
      {bool scroll = false}) async {
    buf.write('===== $label =====\n');
    final out = <String, String>{};
    await collect(tester, out);
    if (scroll) {
      for (var i = 0; i < 15; i++) {
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isEmpty) break;
        final state = tester.state<ScrollableState>(scrollable.first);
        final before = state.position.pixels;
        await tester.drag(scrollable.first, const Offset(0, -700), warnIfMissed: false);
        await tester.pump();
        final after = tester.state<ScrollableState>(scrollable.first).position.pixels;
        await collect(tester, out);
        if ((after - before).abs() < 1) break;
      }
    }
    for (final key in out.keys) {
      final v = out[key]!.split('\t');
      buf.write('  "$key" fs=${v[0]} fw=${v[1]} fam=${v[2]} pos=(${v[3]}) lh=${v[4]} ls=${v[5]}\n');
    }
    final ex = tester.takeException();
    if (ex != null) {
      buf.write('  [EXCEPTION: ${ex.toString().split('\n').first}]\n');
    }
    buf.write('\n');
  }

  testWidgets('dump all app page texts', (tester) async {
    final buf = StringBuffer();

    for (final entry in pages) {
      final key = entry[0] as String;
      final page = entry[1] as Widget;
      final router = entry[2] as bool;
      final scroll = entry[3] as bool;
      await _pump(tester, page, router: router);
      await dumpCurrent(tester, buf, key, scroll: scroll);
      await tester.pumpWidget(const SizedBox());
    }

    // Splash screens 1-3 via PageView swipes.
    await _pump(tester, const SplashScreens());
    await dumpCurrent(tester, buf, 'splash1');
    await tester.drag(find.byType(PageView), const Offset(-390, 0), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await dumpCurrent(tester, buf, 'splash2');
    await tester.drag(find.byType(PageView), const Offset(-390, 0), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await dumpCurrent(tester, buf, 'splash3');
    await tester.pumpWidget(const SizedBox());
    tester.takeException();

    final outFile = File(_out);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(buf.toString());
    // ignore: avoid_print
    print('WROTE $_out');
  });
}
