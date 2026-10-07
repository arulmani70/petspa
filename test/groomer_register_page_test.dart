import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_formatters.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/repo/groomer_register_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/views/mobile/groomer_register_page_mobile.dart';

class _MockApiRepository extends ApiRepository {
  String? lastPostPath;
  dynamic lastPostData;
  Map<String, dynamic>? mockPostResponse;

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPostPath = path;
    lastPostData = data;
    return mockPostResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiRepository mockApi;
  late SessionService sessionService;
  late GroomerRegisterRepository repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    mockApi = _MockApiRepository();
    sessionService = SessionService();
    await sessionService.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ApiRepository>(mockApi);
    GetIt.I.registerSingleton<SessionService>(sessionService);

    repository = GroomerRegisterRepository();
    await repository.initialize();
    GetIt.I.registerSingleton<GroomerRegisterRepository>(repository);
  });

  testWidgets('GroomerRegisterPageMobile renders only API-required fields, no back button, and no avatar field', (tester) async {
    // Save temporary credentials as from login
    await sessionService.saveTempGroomerCredentials(
      tempLoginId: 'b00161787832259039@temp.shearheaven.com',
      tempPassword: 'Tmp@4e5upw9',
    );

    mockApi.mockPostResponse = {
      'success': true,
      'message': 'Account setup successful',
      'data': {
        'accessToken': 'setup-acc-tok',
        'refreshToken': 'setup-ref-tok',
        'mustChangePassword': false,
        'groomer': {
          'id': 5,
          'groomerCode': 'G005',
          'firstName': 'Ashna',
          'lastName': 'Menon',
          'email': 'b00161787832259039@temp.shearheaven.com',
          'role': 'Groomer',
        },
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: NoSplash.splashFactory,
        ),
        home: const GroomerRegisterPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify required UI elements are rendered
    expect(find.text('Complete Your Setup'), findsOneWidget);
    expect(find.text('Shear Heaven Pet Spa | Staff Login'), findsOneWidget);
    expect(find.text('ACCOUNT CREDENTIALS'), findsOneWidget);
    expect(find.text('Email / Login ID'), findsOneWidget);
    expect(find.text('Enter Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('PROFILE DETAILS'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Complete Setup'), findsOneWidget);

    // Verify Back button and Image Upload field are removed
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
    expect(find.text('New User ID'), findsNothing);
    expect(find.text('New Login ID'), findsNothing);
    expect(find.text('Experience'), findsNothing);
    expect(find.text('Email ID (Optional)'), findsNothing);
    expect(find.text('Specilization'), findsNothing);
    expect(find.text('Availability'), findsNothing);

    // Enter new password & confirm password
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(1), 'Groomer@123');
    await tester.enterText(textFields.at(2), 'Groomer@123');
    await tester.pump();

    // Scroll to and tap Complete Setup
    await tester.ensureVisible(find.text('Complete Setup'));
    await tester.pump();
    await tester.tap(find.text('Complete Setup'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify exact endpoint was called
    expect(mockApi.lastPostPath, equals('/api/groomer-auth/setup-account'));

    // Verify exact 5 fields in payload
    final payload = mockApi.lastPostData as Map<String, dynamic>;
    expect(payload.length, equals(5));
    expect(payload['tempLoginId'], equals('b00161787832259039@temp.shearheaven.com'));
    expect(payload['tempPassword'], equals('Tmp@4e5upw9'));
    expect(payload['email'], equals('b00161787832259039@temp.shearheaven.com'));
    expect(payload['password'], equals('Groomer@123'));
    expect(payload['confirmPassword'], equals('Groomer@123'));
  });

  testWidgets('GroomerRegisterPageMobile fails defensively when tempPassword is missing', (tester) async {
    // Clear session temp credentials
    await sessionService.clearTempGroomerCredentials();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: NoSplash.splashFactory,
        ),
        home: const GroomerRegisterPageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'b00161787832259039@temp.shearheaven.com');
    await tester.enterText(textFields.at(1), 'Groomer@123');
    await tester.enterText(textFields.at(2), 'Groomer@123');
    await tester.pump();

    await tester.ensureVisible(find.text('Complete Setup'));
    await tester.pump();
    await tester.tap(find.text('Complete Setup'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify error message is shown and no network request was sent
    expect(find.text('Temporary password is missing. Please log in again to continue setup.'), findsOneWidget);
    expect(mockApi.lastPostPath, isNull);
  });

  testWidgets('GroomerRegisterPageMobile uses temp credentials passed via constructor', (tester) async {
    mockApi.mockPostResponse = {
      'success': true,
      'message': 'Account setup successful',
      'data': {
        'accessToken': 'tok-direct',
        'refreshToken': 'ref-direct',
        'mustChangePassword': false,
        'groomer': {
          'id': 7,
          'groomerCode': 'G007',
          'firstName': 'Ashna',
          'lastName': 'Menon',
          'email': 'direct@temp.shearheaven.com',
          'role': 'Groomer',
        },
      },
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: NoSplash.splashFactory,
        ),
        home: const GroomerRegisterPageMobile(
          tempLoginId: 'direct@temp.shearheaven.com',
          tempPassword: 'DirectTempPassword@99',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(1), 'NewPass@123');
    await tester.enterText(textFields.at(2), 'NewPass@123');
    await tester.pump();

    await tester.ensureVisible(find.text('Complete Setup'));
    await tester.pump();
    await tester.tap(find.text('Complete Setup'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(mockApi.lastPostPath, equals('/api/groomer-auth/setup-account'));
    final payload = mockApi.lastPostData as Map<String, dynamic>;
    expect(payload['tempLoginId'], equals('direct@temp.shearheaven.com'));
    expect(payload['tempPassword'], equals('DirectTempPassword@99'));
    expect(payload['email'], equals('direct@temp.shearheaven.com'));
    expect(payload['password'], equals('NewPass@123'));
    expect(payload['confirmPassword'], equals('NewPass@123'));
  });

  group('US Phone Number formatting and validation', () {
    test('UsPhoneInputFormatter formats and strictly limits digits to 10 max', () {
      // 10 digits formatted
      expect(UsPhoneInputFormatter.formatDigits('5551234567'), equals('(555) 123-4567'));
      // Extra numbers beyond 10 are strictly discarded
      expect(UsPhoneInputFormatter.formatDigits('55512345678999'), equals('(555) 123-4567'));
      // 11 digits starting with +1 country code has leading 1 stripped and 10 digits formatted
      expect(UsPhoneInputFormatter.formatDigits('+1 (555) 123-4567'), equals('(555) 123-4567'));
      expect(UsPhoneInputFormatter.formatDigits('15551234567'), equals('(555) 123-4567'));
      // Partial numbers formatted progressively
      expect(UsPhoneInputFormatter.formatDigits('5'), equals('(5'));
      expect(UsPhoneInputFormatter.formatDigits('555'), equals('(555'));
      expect(UsPhoneInputFormatter.formatDigits('555123'), equals('(555) 123'));
      expect(UsPhoneInputFormatter.formatDigits(''), equals(''));
    });

    testWidgets('Phone input does not allow typing extra numbers and formats as US number', (tester) async {
      await sessionService.saveTempGroomerCredentials(
        tempLoginId: 'phone@test.com',
        tempPassword: 'Password@123',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: false,
            splashFactory: NoSplash.splashFactory,
          ),
          home: const GroomerRegisterPageMobile(),
        ),
      );
      await tester.pumpAndSettle();

      // Find phone text field (index 4 in the form: email, pass, confirm, name, phone)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(5));

      // Enter 15 digits
      await tester.enterText(textFields.at(4), '555123456799999');
      await tester.pump();

      final phoneField = tester.widget<TextField>(textFields.at(4));
      // Should be strictly clamped to 10 digits formatted (no extra numbers allowed)
      expect(phoneField.controller?.text, equals('(555) 123-4567'));
    });

    testWidgets('GroomerRegisterPageMobile shows error when phone number has fewer than 10 digits', (tester) async {
      await sessionService.saveTempGroomerCredentials(
        tempLoginId: 'phone@test.com',
        tempPassword: 'Password@123',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: false,
            splashFactory: NoSplash.splashFactory,
          ),
          home: const GroomerRegisterPageMobile(),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'Groomer@123');
      await tester.enterText(textFields.at(2), 'Groomer@123');
      // Incomplete phone number (only 6 digits)
      await tester.enterText(textFields.at(4), '555123');
      await tester.pump();

      await tester.ensureVisible(find.text('Complete Setup'));
      await tester.pump();
      await tester.tap(find.text('Complete Setup'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verification error
      expect(find.text('Please enter a valid 10-digit US phone number.'), findsOneWidget);
      expect(mockApi.lastPostPath, isNull);
    });
  });
}
