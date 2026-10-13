import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/bloc/groomer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/mobile/groomer_home_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/groomer/repo/groomer_repository.dart';

class _MockApiRepository extends ApiRepository {
  String? lastDeletePath;
  dynamic lastDeletePayload;
  Map<String, dynamic>? mockDeleteResponse;
  bool shouldThrowDeleteError = false;

  String? lastGetPath;
  Map<String, dynamic>? mockGetResponse;

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    lastGetPath = path;
    return mockGetResponse ?? {'success': true, 'data': []};
  }

  @override
  Future<Map<String, dynamic>?> deleteData(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastDeletePath = path;
    lastDeletePayload = data;
    if (shouldThrowDeleteError) {
      throw Exception('Network connection refused');
    }
    return mockDeleteResponse;
  }
}

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

Future<void> _mockGroomerLogin(SessionService sessionService) async {
  await sessionService.saveGroomerSession(
    accessToken: 'groomer-acc-token-123',
    refreshToken: 'groomer-ref-token-123',
    groomerData: {
      'id': 11,
      'groomerCode': 'G001',
      'firstName': 'Merisa',
      'lastName': 'Brown',
      'email': 'g001@shearheaven.com',
      'role': 'Groomer',
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiRepository mockApi;
  late SessionService sessionService;
  late GroomerRepository groomerRepository;
  late GroomerHomeRepository groomerHomeRepository;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    mockApi = _MockApiRepository();
    sessionService = SessionService();
    await sessionService.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ApiRepository>(mockApi);
    GetIt.I.registerSingleton<SessionService>(sessionService);

    groomerRepository = GroomerRepository();
    await groomerRepository.initialize();
    GetIt.I.registerSingleton<GroomerRepository>(groomerRepository);

    groomerHomeRepository = GroomerHomeRepository();
    await groomerHomeRepository.initialize();
    GetIt.I.registerSingleton<GroomerHomeRepository>(groomerHomeRepository);
  });

  group('Groomer Account Deletion - Repository Business Rules & API Integration', () {
    test('1. Blocks account deletion if active/upcoming appointments exist', () async {
      await _mockGroomerLogin(sessionService);

      // Mock upcoming bookings with an active appointment
      mockApi.mockGetResponse = {
        'success': true,
        'data': [
          {
            'bookingId': 101,
            'status': 'confirmed',
            'bookingDate': '2026-10-15',
            'startTime': '10:00 AM',
            'endTime': '11:00 AM',
          }
        ],
      };

      expect(
        () => groomerRepository.deleteAccount(),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Cannot delete account while you have') &&
              e.toString().contains('active or upcoming appointment')),
        ),
      );

      // Session must NOT be cleared when business rule blocks deletion
      expect(sessionService.isGroomerLoggedIn, isTrue);
    });

    test('2. Allows deletion when appointments are all completed or cancelled', () async {
      await _mockGroomerLogin(sessionService);

      mockApi.mockGetResponse = {
        'success': true,
        'data': [
          {
            'bookingId': 101,
            'status': 'completed',
            'bookingDate': '2026-10-10',
            'startTime': '10:00 AM',
            'endTime': '11:00 AM',
          },
          {
            'bookingId': 102,
            'status': 'cancelled',
            'bookingDate': '2026-10-11',
            'startTime': '11:00 AM',
            'endTime': '12:00 PM',
          }
        ],
      };

      // Mock backend deletion success
      mockApi.mockDeleteResponse = {
        'success': true,
        'message': 'Groomer deleted successfully',
      };

      final success = await groomerRepository.deleteAccount();
      expect(success, isTrue);

      // Tokens and session data must be wiped
      expect(sessionService.isGroomerLoggedIn, isFalse);
      expect(await sessionService.getGroomerAccessToken(), isNull);
      expect(await sessionService.getGroomerRefreshToken(), isNull);
    });

    test('3. Fallback to /api/admin/groomers/{id} when dedicated endpoint returns 404', () async {
      await _mockGroomerLogin(sessionService);

      mockApi.mockGetResponse = {'success': true, 'data': []};

      // Primary returns route not found
      mockApi.mockDeleteResponse = {
        'success': false,
        'message': 'Route not found: DELETE /api/groomer-auth/account',
      };

      // When called, the repo tries primary, secondary, then fallback to /api/admin/groomers/11
      final success = await groomerRepository.deleteAccount();
      expect(mockApi.lastDeletePath, equals('/api/admin/groomers/11'));
      expect(success, isTrue);
    });

    test('4. Fails loudly with error message without clearing session when backend fails', () async {
      await _mockGroomerLogin(sessionService);

      mockApi.mockGetResponse = {'success': true, 'data': []};
      mockApi.mockDeleteResponse = {
        'success': false,
        'message': 'Database constraint failure: Cannot delete groomer',
      };

      expect(
        () => groomerRepository.deleteAccount(),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Database constraint failure')),
        ),
      );

      // Crucial: Must NEVER simulate successful deletion if backend request fails
      expect(sessionService.isGroomerLoggedIn, isTrue);
      expect(await sessionService.getGroomerAccessToken(), isNotNull);
    });
  });

  group('Groomer Account Deletion - BLoC State Management', () {
    test('5. GroomerHomeBloc processes GroomerHomeDeleteAccountEvent successfully', () async {
      mockApi.mockGetResponse = {'success': true, 'data': []};
      mockApi.mockDeleteResponse = {'success': true, 'message': 'Groomer deleted successfully'};

      await _mockGroomerLogin(sessionService);

      final bloc = GroomerHomeBloc(repository: groomerHomeRepository);

      bloc.add(const GroomerHomeDeleteAccountEvent());
      await Future.delayed(const Duration(milliseconds: 150));

      expect(bloc.state.deleteAccountSuccess, isTrue);
      expect(bloc.state.isDeletingAccount, isFalse);
      expect(sessionService.isGroomerLoggedIn, isFalse);

      await bloc.close();
    });

    test('6. GroomerBloc processes GroomerDeleteAccountEvent successfully', () async {
      mockApi.mockGetResponse = {'success': true, 'data': []};
      mockApi.mockDeleteResponse = {'success': true, 'message': 'Groomer deleted successfully'};

      await _mockGroomerLogin(sessionService);

      final bloc = GroomerBloc(repository: groomerRepository);

      bloc.add(const GroomerDeleteAccountEvent());
      await Future.delayed(const Duration(milliseconds: 150));

      expect(bloc.state.status, equals(GroomerStatus.success));
      expect(bloc.state.message, contains('Account successfully deleted'));

      await bloc.close();
    });
  });

  group('Groomer Account Deletion - UI & Confirmation Dialog Flow', () {
    testWidgets('7. Delete Account button renders in Groomer Profile tab', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final homeBloc = GroomerHomeBloc(repository: groomerHomeRepository);

      await _mockGroomerLogin(sessionService);

      mockApi.mockGetResponse = {'success': true, 'data': []};

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => _wrapWithResponsive(child!),
          home: BlocProvider<GroomerHomeBloc>.value(
            value: homeBloc,
            child: const GroomerHomePageMobile(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Profile Tab by tapping the groomer avatar in the header
      final avatarFinder = find.byType(ClipOval);
      expect(avatarFinder, findsWidgets);
      await tester.tap(avatarFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify "Delete Account" button is present on the profile screen
      final deleteAccountButton = find.widgetWithText(OutlinedButton, 'Delete Account');
      expect(deleteAccountButton, findsOneWidget);

      await homeBloc.close();
    });

    testWidgets('8. Confirmation dialog shows warning, Cancel closes dialog without deleting', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final homeBloc = GroomerHomeBloc(repository: groomerHomeRepository);

      await _mockGroomerLogin(sessionService);

      mockApi.mockGetResponse = {'success': true, 'data': []};

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => _wrapWithResponsive(child!),
          home: BlocProvider<GroomerHomeBloc>.value(
            value: homeBloc,
            child: const GroomerHomePageMobile(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Profile Tab by tapping the groomer avatar
      final avatarFinder = find.byType(ClipOval);
      expect(avatarFinder, findsWidgets);
      await tester.tap(avatarFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final deleteAccountButton = find.widgetWithText(OutlinedButton, 'Delete Account');
      expect(deleteAccountButton, findsOneWidget);

      // Tap Delete Account to open confirmation dialog
      await tester.tap(deleteAccountButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify permanent deletion warning title and message
      expect(find.text('Delete Groomer Account'), findsOneWidget);
      expect(find.textContaining('This action is permanent and cannot be undone'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Dialog is dismissed and session remains untouched
      expect(find.text('Delete Groomer Account'), findsNothing);
      expect(sessionService.isGroomerLoggedIn, isTrue);

      await homeBloc.close();
    });
  });
}
