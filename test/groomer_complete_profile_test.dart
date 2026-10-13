import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/groomer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/repo/groomer_login_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/views/mobile/groomer_login_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/repo/groomer_register_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/views/mobile/groomer_register_page_mobile.dart';

class _MockApiRepo extends ApiRepository {
  final List<String> calledPaths = [];
  final Map<String, dynamic> lastPayloadByPath = {};
  Map<String, dynamic>? mockResponse;

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    calledPaths.add(path);
    if (data is Map<String, dynamic>) {
      lastPayloadByPath[path] = data;
    }
    return mockResponse;
  }

  @override
  Future<Map<String, dynamic>?> putData(String path, dynamic data) async {
    calledPaths.add(path);
    if (data is Map<String, dynamic>) {
      lastPayloadByPath[path] = data;
    }
    return mockResponse;
  }


  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    calledPaths.add(path);
    return mockResponse;
  }
}

class _MockGroomerSocketService extends GroomerSocketService {
  @override
  Future<void> connect({
    String? token,
    String? serverUrl,
    List<String>? customEvents,
  }) async {
    // In unit and widget tests, avoid opening real socket.io network connections or timers
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiRepo mockApi;
  late SessionService sessionService;
  late GroomerLoginRepository loginRepo;
  late GroomerRegisterRepository registerRepo;
  late GroomerHomeRepository homeRepo;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    mockApi = _MockApiRepo();
    sessionService = SessionService();
    await sessionService.initialize();

    loginRepo = GroomerLoginRepository();
    await loginRepo.initialize();

    registerRepo = GroomerRegisterRepository();
    await registerRepo.initialize();

    homeRepo = GroomerHomeRepository();
    await homeRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ApiRepository>(mockApi);
    GetIt.I.registerSingleton<SessionService>(sessionService);
    GetIt.I.registerSingleton<GroomerLoginRepository>(loginRepo);
    GetIt.I.registerSingleton<GroomerRegisterRepository>(registerRepo);
    GetIt.I.registerSingleton<GroomerHomeRepository>(homeRepo);
    GetIt.I.registerSingleton<GroomerSocketService>(_MockGroomerSocketService());
  });

  group('GroomerUser.isProfileCompleted Model Logic', () {
    test('returns false when mustChangePassword is true', () {
      const user = GroomerUser(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Ashna',
        lastName: 'Menon',
        email: 'ashna@shearheaven.com',
        mustChangePassword: true,
      );
      expect(user.isProfileCompleted, isFalse);
    });

    test('returns false when firstName is empty or whitespace', () {
      const user = GroomerUser(
        id: 1,
        groomerCode: 'G001',
        firstName: '   ',
        lastName: 'Menon',
        email: 'ashna@shearheaven.com',
        mustChangePassword: false,
      );
      expect(user.isProfileCompleted, isFalse);
    });

    test('returns false when lastName is empty or whitespace', () {
      const user = GroomerUser(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Ashna',
        lastName: '',
        email: 'ashna@shearheaven.com',
        mustChangePassword: false,
      );
      expect(user.isProfileCompleted, isFalse);
    });

    test('returns false when email is empty or whitespace', () {
      const user = GroomerUser(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Ashna',
        lastName: 'Menon',
        email: '  ',
        mustChangePassword: false,
      );
      expect(user.isProfileCompleted, isFalse);
    });

    test('returns true when mustChangePassword is false and names & email are non-empty', () {
      const user = GroomerUser(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Ashna',
        lastName: 'Menon',
        email: 'ashna@shearheaven.com',
        mustChangePassword: false,
      );
      expect(user.isProfileCompleted, isTrue);
    });
  });

  group('Navigation Guard and Profile Status Redirection', () {
    GoRouter createTestRouter() {
      return GoRouter(
        initialLocation: '/${RouteNames.groomerHome}',
        redirect: (context, state) {
          final loc = state.matchedLocation;
          final session = sessionService;
          final isGroomerLoggedIn = session.isGroomerLoggedIn;
          if (loc.startsWith('/${RouteNames.groomerHome}')) {
            if (!isGroomerLoggedIn) return '/${RouteNames.login}';
            final groomerMap = session.getGroomerUser();
            if (groomerMap != null) {
              final groomer = GroomerUser.fromJson(groomerMap);
              if (!groomer.isProfileCompleted) return '/${RouteNames.groomerRegister}';
            }
          }
          if (loc == '/${RouteNames.groomerRegister}') {
            if (isGroomerLoggedIn) {
              final groomerMap = session.getGroomerUser();
              if (groomerMap != null) {
                final groomer = GroomerUser.fromJson(groomerMap);
                if (groomer.isProfileCompleted) return '/${RouteNames.groomerHome}';
              }
            }
          }
          return null;
        },
        routes: [
          GoRoute(path: '/${RouteNames.login}', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/${RouteNames.groomerRegister}', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/${RouteNames.groomerHome}', builder: (_, __) => const SizedBox()),
        ],
      );
    }

    testWidgets('Protected Groomer Home redirects incomplete profile to groomerRegister', (tester) async {
      await sessionService.saveGroomerSession(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh',
        groomerData: {
          'id': 16,
          'groomerCode': 'TESTG97',
          'firstName': 'Test',
          'lastName': 'Groomer',
          'email': 'testg97@shearheaven.com',
          'mustChangePassword': true,
        },
      );

      final router = createTestRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final currentUri = router.routerDelegate.currentConfiguration.uri.toString();
      expect(currentUri, equals('/${RouteNames.groomerRegister}'));
    });

    testWidgets('Completed groomer profile attempting groomerRegister redirects to groomerHome', (tester) async {
      await sessionService.saveGroomerSession(
        accessToken: 'mock-token',
        refreshToken: 'mock-refresh',
        groomerData: {
          'id': 1,
          'groomerCode': 'G001',
          'firstName': 'Ashna',
          'lastName': 'Menon',
          'email': 'ashna@shearheaven.com',
          'mustChangePassword': false,
        },
      );

      final router = createTestRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/${RouteNames.groomerRegister}');
      await tester.pumpAndSettle();

      final currentUri = router.routerDelegate.currentConfiguration.uri.toString();
      expect(currentUri, equals('/${RouteNames.groomerHome}'));
    });
  });

  group('First-Time Login Navigation and tempLoginId mapping', () {
    testWidgets('Groomer login passes correct tempLoginId from backend to groomerRegister', (tester) async {
      mockApi.mockResponse = {
        'success': true,
        'message': 'Login successful',
        'data': {
          'mustChangePassword': true,
          'tempLoginId': 'testg981791882876498@temp.shearheaven.com',
          'tempPassword': 'Temp@Password123',
          'groomer': {
            'id': 16,
            'groomerCode': 'TESTG97',
            'firstName': 'Test',
            'lastName': 'Groomer',
            'email': 'testg97@shearheaven.com',
            'mustChangePassword': true,
          },
        },
      };

      String? navigatedRoute;
      Map<String, dynamic>? passedExtra;

      final testRouter = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const GroomerLoginPageMobile(),
          ),
          GoRoute(
            name: RouteNames.groomerRegister,
            path: '/groomer-register',
            builder: (context, state) {
              navigatedRoute = RouteNames.groomerRegister;
              passedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('Register View'));
            },
          ),
          GoRoute(
            name: RouteNames.groomerHome,
            path: '/groomer-home',
            builder: (context, state) => const Scaffold(body: Text('Home View')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'testg97@shearheaven.com');
      await tester.enterText(textFields.at(1), 'Temp@Password123');
      await tester.pump();

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, equals(RouteNames.groomerRegister));
      expect(passedExtra, isNotNull);
      // Verify that backend tempLoginId is passed, not the user-typed email
      expect(passedExtra!['tempLoginId'], equals('testg981791882876498@temp.shearheaven.com'));
      expect(passedExtra!['tempPassword'], equals('Temp@Password123'));
    });
  });

  group('Complete Your Profile Submission and Persistence', () {
    testWidgets('First-time groomer completes profile with valid details, executes setupAccount and updateProfile', (tester) async {
      await sessionService.saveTempGroomerCredentials(
        tempLoginId: 'testg981791882876498@temp.shearheaven.com',
        tempPassword: 'Temp@Password123',
      );

      mockApi.mockResponse = {
        'success': true,
        'message': 'Account setup successful',
        'data': {
          'accessToken': 'jwt-new-access-token',
          'refreshToken': 'jwt-new-refresh-token',
          'mustChangePassword': false,
          'groomer': {
            'id': 16,
            'groomerCode': 'TESTG97',
            'firstName': 'Ashna',
            'lastName': 'Menon',
            'email': 'ashna.menon@shearheaven.com',
            'mobile': '5551234567',
            'role': 'Groomer',
          },
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const GroomerRegisterPageMobile(
            tempLoginId: 'testg981791882876498@temp.shearheaven.com',
            tempPassword: 'Temp@Password123',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Shear Heaven Pet Spa | Staff Login'), findsOneWidget);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(5));

      // Enter permanent email, password, confirm password, full name, phone
      await tester.enterText(textFields.at(0), 'ashna.menon@shearheaven.com');
      await tester.enterText(textFields.at(1), 'Permanent@123');
      await tester.enterText(textFields.at(2), 'Permanent@123');
      await tester.enterText(textFields.at(3), 'Ashna Menon');
      await tester.enterText(textFields.at(4), '5551234567');
      await tester.pump();

      await tester.ensureVisible(find.text('Complete Profile'));
      await tester.pump();
      await tester.tap(find.text('Complete Profile'));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify POST /api/groomer-auth/setup-account was called
      expect(mockApi.calledPaths, contains('/api/groomer-auth/setup-account'));
      final setupPayload = mockApi.lastPayloadByPath['/api/groomer-auth/setup-account'] as Map<String, dynamic>;
      expect(setupPayload['tempLoginId'], equals('testg981791882876498@temp.shearheaven.com'));
      expect(setupPayload['tempPassword'], equals('Temp@Password123'));
      expect(setupPayload['email'], equals('ashna.menon@shearheaven.com'));
      expect(setupPayload['password'], equals('Permanent@123'));
      expect(setupPayload['confirmPassword'], equals('Permanent@123'));

      // 2. Verify PUT /api/groomer-auth/profile was called with correct first/last names
      expect(mockApi.calledPaths, contains('/api/groomer-auth/profile'));
      final profilePayload = mockApi.lastPayloadByPath['/api/groomer-auth/profile'] as Map<String, dynamic>;
      expect(profilePayload['firstName'], equals('Ashna'));
      expect(profilePayload['lastName'], equals('Menon'));
      expect(profilePayload['mobile'], equals('5551234567'));

      // 3. Verify session was saved with active tokens and profile
      expect(sessionService.isGroomerLoggedIn, isTrue);
      final savedGroomer = sessionService.getGroomerUser();
      expect(savedGroomer, isNotNull);
      expect(savedGroomer!['firstName'], equals('Ashna'));
      expect(savedGroomer['lastName'], equals('Menon'));
    });

    test('Single-word full name correctly falls back to provide non-empty lastName without throwing error', () async {
      mockApi.mockResponse = {
        'success': true,
        'message': 'Profile updated',
        'data': {
          'id': 16,
          'firstName': 'Ashna',
          'lastName': 'Ashna',
          'email': 'ashna@shearheaven.com',
          'mobile': '5551234567',
          'role': 'Groomer',
        },
      };

      // updateProfile with single-word name should not throw 'Last name is required.'
      final updated = await homeRepo.updateProfile(
        firstName: 'Ashna',
        lastName: '',
      );

      expect(updated, isNotNull);
      expect(mockApi.calledPaths, contains('/api/groomer-auth/profile'));
      final profilePayload = mockApi.lastPayloadByPath['/api/groomer-auth/profile'] as Map<String, dynamic>;
      expect(profilePayload['firstName'], equals('Ashna'));
      expect(profilePayload['lastName'], equals('Ashna'));
    });
  });
}
