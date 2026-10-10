import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/account/bloc/profile_bloc.dart';
import 'package:shear_heaven_pet_spa/src/account/views/mobile/profile_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/mobile/login_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/exit_confirmation_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/home/views/mobile/home_page_mobile.dart';

class _MockApiRepository extends ApiRepository {
  Map<String, dynamic>? mockResponse;
  String? lastPath;
  dynamic lastPayload;

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPath = path;
    lastPayload = data;
    return mockResponse ?? {'success': true, 'message': 'OK'};
  }

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    lastPath = path;
    return mockResponse ?? {'success': true, 'data': {}};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiRepository mockApi;
  late SessionService sessionService;
  late DeviceIdService deviceIdService;
  late AuthRepository authRepository;

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

    authRepository = AuthRepository();
    await authRepository.initialize();
    GetIt.I.registerSingleton<AuthRepository>(authRepository);
  });

  tearDown(() {
    GetIt.I.reset();
  });

  group('Logout & Prevent Back Navigation Tests', () {
    test('1. LogoutSubmitted clears session, tokens, and redirects to login', () async {
      // Simulate active logged-in customer session
      await sessionService.saveSession({
        'id': 10,
        'name': 'Test Customer',
        'email': 'customer@test.com',
      });
      await sessionService.saveTokens(
        accessToken: 'access-token-123',
        refreshToken: 'refresh-token-123',
      );

      expect(sessionService.isLoggedIn, isTrue);

      final authBloc = AuthBloc(repository: authRepository);

      authBloc.add(const LogoutSubmitted());
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sessionService.isLoggedIn, isFalse);
      final accessToken = await sessionService.getAccessToken();
      expect(accessToken, isNull);
      final refreshToken = await sessionService.getRefreshToken();
      expect(refreshToken, isNull);
      expect(authBloc.state.status, equals(AuthStatus.unauthenticated));

      await authBloc.close();
    });

    test('2. Routes.redirectToLogin clears navigator stack and navigates to login route', () async {
      Routes.redirectToLogin(isGroomer: false);

      final currentUri = Routes.globalRouter.routerDelegate.currentConfiguration.uri.toString();
      expect(currentUri, equals('/${RouteNames.login}'));
      expect(Routes.navigatorKey.currentState?.canPop() ?? false, isFalse);
    });

    test('3. Routes.redirectToLogin for groomer redirects to groomerLogin route', () async {
      Routes.redirectToLogin(isGroomer: true);

      final currentUri = Routes.globalRouter.routerDelegate.currentConfiguration.uri.toString();
      expect(currentUri, equals('/${RouteNames.groomerLogin}'));
      expect(Routes.navigatorKey.currentState?.canPop() ?? false, isFalse);
    });

    test('4. Protected route guard redirects unauthenticated user from /profile to /login', () async {
      expect(sessionService.isLoggedIn, isFalse);

      // Attempt to navigate to protected profile route while logged out
      Routes.globalRouter.go('/${RouteNames.profile}');

      final currentUri = Routes.globalRouter.routerDelegate.currentConfiguration.uri.toString();
      expect(currentUri, equals('/${RouteNames.login}'),
          reason: 'Unauthenticated user accessing /profile must be redirected to /login');
    });

    test('5. Protected route guard redirects unauthenticated user from /groomer-home to /groomer-login', () async {
      expect(sessionService.isGroomerLoggedIn, isFalse);

      // Attempt to navigate to protected groomer-home route while logged out
      Routes.globalRouter.go('/${RouteNames.groomerHome}');

      final currentUri = Routes.globalRouter.routerDelegate.currentConfiguration.uri.toString();
      expect(currentUri, equals('/${RouteNames.groomerLogin}'),
          reason: 'Unauthenticated user accessing /groomer-home must be redirected to /groomer-login');
    });

    testWidgets('6. LoginPageMobile PopScope has canPop: false and does NOT navigate to home on Back', (WidgetTester tester) async {
      final authBloc = AuthBloc(repository: authRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const LoginPageMobile(),
          ),
        ),
      );
      await tester.pump();

      final popScopeFinder = find.byType(PopScope);
      expect(popScopeFinder, findsOneWidget);

      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse,
          reason: 'LoginPageMobile must have canPop: false to prevent popping to previous authenticated screens');

      await authBloc.close();
    });

    testWidgets('7. LoginPageMobile top-left back button navigates to Welcome instead of Home when stack cannot pop', (WidgetTester tester) async {
      final authBloc = AuthBloc(repository: authRepository);
      String? navigatedRoute;

      final testRouter = GoRouter(
        initialLocation: '/${RouteNames.login}',
        routes: [
          GoRoute(
            name: RouteNames.welcome,
            path: '/${RouteNames.welcome}',
            builder: (context, state) {
              navigatedRoute = RouteNames.welcome;
              return const Scaffold(body: Text('Welcome Screen'));
            },
          ),
          GoRoute(
            name: RouteNames.home,
            path: '/${RouteNames.home}',
            builder: (context, state) {
              navigatedRoute = RouteNames.home;
              return const Scaffold(body: Text('Home Screen'));
            },
          ),
          GoRoute(
            name: RouteNames.login,
            path: '/${RouteNames.login}',
            builder: (context, state) => BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const LoginPageMobile(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Find back arrow button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Ensure it navigated to Welcome, and NEVER to Home
      expect(navigatedRoute, equals(RouteNames.welcome));
      expect(navigatedRoute, isNot(equals(RouteNames.home)));

      await authBloc.close();
    });

    testWidgets('8. Profile page does not leak profile data when unauthenticated (shows guest state)', (WidgetTester tester) async {
      expect(sessionService.isLoggedIn, isFalse);
      final authBloc = AuthBloc(repository: authRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const ProfilePageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When unauthenticated, guest sign-in banner is rendered instead of private user profile details
      expect(find.text('Sign In to Your Account'), findsOneWidget);
      expect(find.text('Sign In / Register'), findsOneWidget);

      await authBloc.close();
    });

    testWidgets('9. ExitConfirmationDialog displays Title, Message, Cancel keeps open, Exit confirms', (WidgetTester tester) async {
      bool? userChoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    userChoice = await ExitConfirmationDialog.show(context);
                  },
                  child: const Text('Trigger Exit Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // 1. Open dialog
      await tester.tap(find.text('Trigger Exit Dialog'));
      await tester.pumpAndSettle();

      // 2. Check title and message
      expect(find.text('Exit App?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit the application?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // 3. Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(userChoice, isFalse);
      expect(find.text('Exit App?'), findsNothing);

      // 4. Open dialog again and tap Exit
      await tester.tap(find.text('Trigger Exit Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(userChoice, isTrue);
    });
  });
}
