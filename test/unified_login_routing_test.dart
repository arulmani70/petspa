import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/mobile/login_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

class _MockApiRepository extends ApiRepository {
  Map<String, dynamic>? mockResponse;
  String? lastPath;
  dynamic lastPayload;

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPath = path;
    lastPayload = data;
    return mockResponse;
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
  });

  test('AuthRepository.login handles customer response and saves customer tokens', () async {
    mockApi.mockResponse = {
      'success': true,
      'message': 'Login successful',
      'data': {
        'userType': 'customer',
        'accessToken': 'cust-access-token-123',
        'refreshToken': 'cust-refresh-token-123',
        'user': {
          'id': 2,
          'name': 'Arul',
          'email': 'arul77231@gmail.com',
          'mobile': '9876543210',
        },
        'deviceAccessToken': 'device-tok-123',
      },
    };

    final result = await authRepository.login(
      email: 'arul77231@gmail.com',
      password: 'Password@123',
    );

    expect(result['userType'], equals('customer'));
    expect(result['accessToken'], equals('cust-access-token-123'));
    expect(result['refreshToken'], equals('cust-refresh-token-123'));
    expect(result['user']['name'], equals('Arul'));

    final savedAccess = await sessionService.getAccessToken();
    expect(savedAccess, equals('cust-access-token-123'));
    expect(sessionService.isLoggedIn, isTrue);
    expect(sessionService.isGroomerLoggedIn, isFalse);
  });

  test('AuthRepository.login handles groomer response and saves groomer session', () async {
    mockApi.mockResponse = {
      'success': true,
      'message': 'Login successful',
      'data': {
        'userType': 'groomer',
        'accessToken': 'groomer-access-token-456',
        'refreshToken': 'groomer-refresh-token-456',
        'mustChangePassword': false,
        'groomer': {
          'id': 1,
          'groomerCode': 'G001',
          'firstName': 'Merisa',
          'lastName': 'Brown',
          'email': 'g001@shearheaven.com',
          'mobile': '9876543210',
          'role': 'Groomer',
          'multiBookingEnabled': false,
          'slotBookingLimit': 1,
        },
      },
    };

    final result = await authRepository.login(
      email: 'g001@shearheaven.com',
      password: 'Groomer@123',
    );

    expect(result['userType'], equals('groomer'));
    expect(result['mustChangePassword'], isFalse);
    expect(result['groomer']['groomerCode'], equals('G001'));

    final savedGroomerToken = await sessionService.getGroomerAccessToken();
    expect(savedGroomerToken, equals('groomer-access-token-456'));
    expect(sessionService.isGroomerLoggedIn, isTrue);
  });

  testWidgets('LoginPageMobile does not display separate Groomer Portal button', (tester) async {
    final authBloc = AuthBloc(repository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const LoginPageMobile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify separate groomer portal button is removed
    expect(find.byKey(const Key('temporary_groomer_login_btn')), findsNothing);
    expect(find.text('Staff / Groomer Portal Login'), findsNothing);

    // Verify main login elements remain
    expect(find.text('Customer Login'), findsOneWidget);
    expect(find.text('Enter Email ID'), findsOneWidget);
    expect(find.text('Enter Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('LoginPageMobile routes to home for customer login and groomerHome for groomer login', (tester) async {
    String navigatedRoute = '';

    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          name: RouteNames.login,
          builder: (context, state) => const LoginPageMobile(),
        ),
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (context, state) {
            navigatedRoute = RouteNames.home;
            return const Scaffold(body: Text('Customer Home Screen'));
          },
        ),
        GoRoute(
          path: '/groomer/home',
          name: RouteNames.groomerHome,
          builder: (context, state) {
            navigatedRoute = RouteNames.groomerHome;
            return const Scaffold(body: Text('Groomer Home Screen'));
          },
        ),
        GoRoute(
          path: '/groomer/register',
          name: RouteNames.groomerRegister,
          builder: (context, state) {
            navigatedRoute = RouteNames.groomerRegister;
            return const Scaffold(body: Text('Groomer Register Screen'));
          },
        ),
      ],
    );

    final authBloc = AuthBloc(repository: authRepository);

    // Test Customer Flow
    mockApi.mockResponse = {
      'success': true,
      'message': 'Login successful',
      'data': {
        'userType': 'customer',
        'accessToken': 'cust-token',
        'refreshToken': 'cust-refresh',
        'user': {'id': 2, 'name': 'Arul', 'email': 'arul@example.com'},
      },
    };

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emailField = find.widgetWithText(TextField, 'name@gmail.com');
    final passField = find.widgetWithText(TextField, 'Enter your password');

    await tester.enterText(emailField, 'arul@example.com');
    await tester.enterText(passField, 'Password@123');
    await tester.pump();

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(navigatedRoute, equals(RouteNames.home));

    // Test Groomer Flow
    mockApi.mockResponse = {
      'success': true,
      'message': 'Login successful',
      'data': {
        'userType': 'groomer',
        'accessToken': 'groomer-token',
        'refreshToken': 'groomer-refresh',
        'mustChangePassword': false,
        'groomer': {'id': 1, 'groomerCode': 'G001', 'firstName': 'Merisa', 'lastName': 'Brown'},
      },
    };

    router.goNamed(RouteNames.login);
    await tester.pumpAndSettle();

    await tester.enterText(emailField, 'g001@shearheaven.com');
    await tester.enterText(passField, 'Groomer@123');
    await tester.pump();

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(navigatedRoute, equals(RouteNames.groomerHome));
  });
}
