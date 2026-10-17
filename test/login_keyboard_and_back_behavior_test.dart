import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/mobile/create_account_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/mobile/forgot_password_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/mobile/login_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/mobile/otp_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/repo/groomer_login_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/views/mobile/groomer_login_page_mobile.dart';

Widget _wrapWithResponsive(Widget child) {
  return ResponsiveBreakpoints.builder(
    child: child,
    breakpoints: const [
      Breakpoint(start: 0, end: 450, name: MOBILE),
      Breakpoint(start: 451, end: 800, name: TABLET),
      Breakpoint(start: 801, end: 1920, name: DESKTOP),
    ],
  );
}

class _MockApiRepository extends ApiRepository {
  @override
  Future<Map<String, dynamic>?> post(
    String path,
    dynamic data, {
    Map<String, dynamic>? query,
  }) async {
    return {'success': true, 'message': 'OK'};
  }

  @override
  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return {'success': true, 'data': {}};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiRepository mockApi;
  late SessionService sessionService;
  late DeviceIdService deviceIdService;
  late AuthRepository authRepository;
  late GroomerLoginRepository groomerLoginRepository;



  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    mockApi = _MockApiRepository();
    sessionService = SessionService();
    await sessionService.initialize();

    deviceIdService = DeviceIdService();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ApiRepository>(mockApi);
    GetIt.I.registerSingleton<SessionService>(sessionService);
    GetIt.I.registerSingleton<DeviceIdService>(deviceIdService);

    groomerLoginRepository = GroomerLoginRepository();
    await groomerLoginRepository.initialize();
    GetIt.I.registerSingleton<GroomerLoginRepository>(groomerLoginRepository);

    authRepository = AuthRepository();
    await authRepository.initialize();
    GetIt.I.registerSingleton<AuthRepository>(authRepository);
  });

  group('Login Screen Keyboard and Back Button Behavior Tests', () {
    testWidgets(
      '1. When keyboard is open and Back is pressed: closes keyboard only, no exit dialog, stays on Login',
      (WidgetTester tester) async {
        final authBloc = AuthBloc(repository: authRepository);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => _wrapWithResponsive(child!),
            home: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const LoginPageMobile(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Login Page is rendered
        expect(find.text('Login'), findsWidgets);

        // Tap the email field to focus
        final emailField = find.byType(TextField).first;
        await tester.tap(emailField);
        await tester.pump();

        // Simulate open software keyboard via viewInsets
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();

        // Press the device back button while keyboard is open
        await tester.binding.handlePopRoute();
        await tester.pump();

        // Exit dialog MUST NOT be shown
        expect(find.text('Exit App?'), findsNothing);
        expect(
          find.text('Are you sure you want to exit the application?'),
          findsNothing,
        );

        // User MUST remain on the login page
        expect(find.text('Login'), findsWidgets);

        // Reset viewInsets after test
        tester.view.resetViewInsets();
        await tester.pump();

        await authBloc.close();
      },
    );

    testWidgets(
      '2. When keyboard is closed and Back is pressed: displays Exit/Cancel confirmation dialog',
      (WidgetTester tester) async {
        final authBloc = AuthBloc(repository: authRepository);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => _wrapWithResponsive(child!),
            home: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const LoginPageMobile(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Ensure keyboard is closed
        tester.view.resetViewInsets();
        await tester.pump();

        // Press device Back button
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 100));

        // Exit Confirmation Dialog MUST appear
        expect(find.text('Exit App?'), findsOneWidget);
        expect(
          find.text('Are you sure you want to exit the application?'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Exit'), findsOneWidget);

        // Tap Cancel: dialog disappears, user stays on Login Page
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Exit App?'), findsNothing);
        expect(find.text('Login'), findsWidgets);

        await authBloc.close();
      },
    );

    testWidgets(
      '3. Keyboard open + Back pressed -> closes keyboard; next Back press -> opens Exit dialog',
      (WidgetTester tester) async {
        final authBloc = AuthBloc(repository: authRepository);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => _wrapWithResponsive(child!),
            home: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const LoginPageMobile(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Step 1: Open keyboard
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();

        // Step 2: Press Back once -> dismisses keyboard only
        await tester.binding.handlePopRoute();
        await tester.pump();

        expect(find.text('Exit App?'), findsNothing);
        expect(find.text('Login'), findsWidgets);

        // Simulate keyboard finish hiding
        tester.view.resetViewInsets();
        await tester.pump();

        // Step 3: Press Back a second time -> displays Exit confirmation dialog
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Exit App?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Exit'), findsOneWidget);

        // Cancel dialog
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Exit App?'), findsNothing);

        await authBloc.close();
      },
    );

    testWidgets(
      '4. Exit confirmed triggers SystemNavigator.pop',
      (WidgetTester tester) async {
        final authBloc = AuthBloc(repository: authRepository);

        // Track system calls
        final List<MethodCall> systemCalls = [];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            systemCalls.add(methodCall);
            return null;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => _wrapWithResponsive(child!),
            home: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const LoginPageMobile(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        tester.view.resetViewInsets();
        await tester.pump();

        // Press Back to open exit dialog
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Exit App?'), findsOneWidget);

        // Tap Exit
        await tester.tap(find.text('Exit'));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify SystemNavigator.pop was called
        expect(
          systemCalls.any((call) => call.method == 'SystemNavigator.pop'),
          isTrue,
        );

        await authBloc.close();
      },
    );
  });

  group('Other Auth Screens Keyboard Dismissal on Back Press Tests', () {
    testWidgets(
      '5. GroomerLoginPageMobile: keyboard open + Back dismisses keyboard without navigating away',
      (WidgetTester tester) async {
        String? navigatedRoute;
        final testRouter = GoRouter(
          initialLocation: '/${RouteNames.groomerLogin}',
          routes: [
            GoRoute(
              name: RouteNames.groomerLogin,
              path: '/${RouteNames.groomerLogin}',
              builder: (context, state) => const GroomerLoginPageMobile(),
            ),
            GoRoute(
              name: RouteNames.login,
              path: '/${RouteNames.login}',
              builder: (context, state) {
                navigatedRoute = RouteNames.login;
                return const SizedBox();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            builder: (context, child) => _wrapWithResponsive(child!),
            routerConfig: testRouter,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Open keyboard
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();

        // Press Back
        await tester.binding.handlePopRoute();
        await tester.pump();

        // Must NOT navigate to login
        expect(navigatedRoute, isNull);
        expect(find.byType(GroomerLoginPageMobile), findsOneWidget);

        // Now close keyboard
        tester.view.resetViewInsets();
        await tester.pump();

        // Press Back again -> navigates to login
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 100));
        expect(navigatedRoute, equals(RouteNames.login));
      },
    );

    testWidgets(
      '6. CreateAccountPageMobile: keyboard open + Back dismisses keyboard without navigating away',
      (WidgetTester tester) async {
        final authBloc = AuthBloc(repository: authRepository);
        String? navigatedRoute;

        final testRouter = GoRouter(
          initialLocation: '/${RouteNames.signup}',
          routes: [
            GoRoute(
              name: RouteNames.signup,
              path: '/${RouteNames.signup}',
              builder: (context, state) => BlocProvider<AuthBloc>.value(
                value: authBloc,
                child: const CreateAccountPageMobile(),
              ),
            ),
            GoRoute(
              name: RouteNames.login,
              path: '/${RouteNames.login}',
              builder: (context, state) {
                navigatedRoute = RouteNames.login;
                return const SizedBox();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            builder: (context, child) => _wrapWithResponsive(child!),
            routerConfig: testRouter,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Open keyboard
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();

        // Press Back
        await tester.binding.handlePopRoute();
        await tester.pump();

        // Must NOT navigate to login
        expect(navigatedRoute, isNull);
        expect(find.byType(CreateAccountPageMobile), findsOneWidget);

        // Close keyboard
        tester.view.resetViewInsets();
        await tester.pump();

        // Press Back again -> navigates to login
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 100));
        expect(navigatedRoute, equals(RouteNames.login));

        await authBloc.close();
      },
    );

    testWidgets(
      '7. ForgotPasswordPageMobile: keyboard open + Back dismisses keyboard without popping step',
      (WidgetTester tester) async {
        final authBloc = AuthBloc(repository: authRepository);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => _wrapWithResponsive(child!),
            home: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const ForgotPasswordPageMobile(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Forgot Password screen is mounted
        expect(find.byType(ForgotPasswordPageMobile), findsOneWidget);

        // Open keyboard
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();

        // Press Back
        await tester.binding.handlePopRoute();
        await tester.pump();

        // Still on Forgot Password screen
        expect(find.byType(ForgotPasswordPageMobile), findsOneWidget);

        tester.view.resetViewInsets();
        await tester.pump();

        await authBloc.close();
      },
    );

    testWidgets(
      '8. OtpPageMobile: keyboard open + Back dismisses keyboard without navigating away',
      (WidgetTester tester) async {
        final authBloc = AuthBloc(repository: authRepository);
        String? navigatedRoute;

        final testRouter = GoRouter(
          initialLocation: '/${RouteNames.otp}',
          routes: [
            GoRoute(
              name: RouteNames.otp,
              path: '/${RouteNames.otp}',
              builder: (context, state) => BlocProvider<AuthBloc>.value(
                value: authBloc,
                child: const OtpPageMobile(),
              ),
            ),
            GoRoute(
              name: RouteNames.signup,
              path: '/${RouteNames.signup}',
              builder: (context, state) {
                navigatedRoute = RouteNames.signup;
                return const SizedBox();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            builder: (context, child) => _wrapWithResponsive(child!),
            routerConfig: testRouter,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Open keyboard
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();

        // Press Back
        await tester.binding.handlePopRoute();
        await tester.pump();

        // Must NOT navigate to signup
        expect(navigatedRoute, isNull);
        expect(find.byType(OtpPageMobile), findsOneWidget);

        // Close keyboard
        tester.view.resetViewInsets();
        await tester.pump();

        // Press Back again -> navigates to signup
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 100));
        expect(navigatedRoute, equals(RouteNames.signup));

        await authBloc.close();
      },
    );
  });
}
