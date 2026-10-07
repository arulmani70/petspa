import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/mobile/create_account_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_formatters.dart';

import 'package:toastification/toastification.dart';

class _MockAuthRepository extends AuthRepository {
  String? lastRegisteredPhone;
  String? lastRegisteredEmail;

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    lastRegisteredPhone = phone;
    lastRegisteredEmail = email;
    return {
      'id': 10,
      'name': name,
      'email': email,
      'phone': phone,
    };
  }
}

void main() {
  late _MockAuthRepository mockAuthRepo;
  late AuthBloc authBloc;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    if (!serviceLocator.isRegistered<SessionService>()) {
      serviceLocator.registerSingleton<SessionService>(SessionService());
    }
    if (!serviceLocator.isRegistered<DeviceIdService>()) {
      serviceLocator.registerSingleton<DeviceIdService>(DeviceIdService());
    }
    if (!serviceLocator.isRegistered<CustomerSocketService>()) {
      serviceLocator.registerSingleton<CustomerSocketService>(CustomerSocketService());
    }
  });

  setUp(() {
    mockAuthRepo = _MockAuthRepository();
    authBloc = AuthBloc(repository: mockAuthRepo);
  });

  tearDown(() {
    authBloc.close();
  });

  group('CreateAccountPageMobile Phone Number Formatting & Validation', () {
    test('UsPhoneInputFormatter helper methods work correctly', () {
      expect(UsPhoneInputFormatter.formatDigits('8171234567'), equals('(817) 123-4567'));
      expect(UsPhoneInputFormatter.formatDigits('817123456799999'), equals('(817) 123-4567'));
      expect(UsPhoneInputFormatter.cleanDigits('(817) 123-4567'), equals('8171234567'));
      expect(UsPhoneInputFormatter.isValid('(817) 123-4567'), isTrue);
      expect(UsPhoneInputFormatter.isValid('8171234567'), isTrue);
      expect(UsPhoneInputFormatter.isValid('(817) 123'), isFalse);
    });

    testWidgets('Phone input does not allow typing extra digits beyond 10 digits', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToastificationWrapper(
            child: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const CreateAccountPageMobile(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find all TextFields: 0: Name, 1: Email, 2: Phone, 3: Password, 4: ConfirmPassword
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(5));

      // Enter 15 digits into phone field (index 2)
      await tester.enterText(textFields.at(2), '817123456799999');
      await tester.pump();

      final phoneWidget = tester.widget<TextField>(textFields.at(2));
      expect(phoneWidget.controller?.text, equals('(817) 123-4567'));
    });

    testWidgets('Shows error when phone number has fewer than 10 digits', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToastificationWrapper(
            child: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const CreateAccountPageMobile(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Robert Martin');
      await tester.enterText(textFields.at(1), 'robert@test.com');
      await tester.enterText(textFields.at(2), '817123'); // Incomplete
      await tester.enterText(textFields.at(3), 'Password@123');
      await tester.enterText(textFields.at(4), 'Password@123');
      await tester.pump();

      await tester.ensureVisible(find.text('Sign Up'));
      await tester.pump();
      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Please enter a valid 10-digit US phone number.', skipOffstage: false),
        findsOneWidget,
      );
      expect(mockAuthRepo.lastRegisteredPhone, isNull);

      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Allows valid 10-digit US phone number to submit registration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ToastificationWrapper(
            child: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const CreateAccountPageMobile(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Robert Martin');
      await tester.enterText(textFields.at(1), 'robert@test.com');
      await tester.enterText(textFields.at(2), '8171234567'); // Valid 10 digits
      await tester.enterText(textFields.at(3), 'Password@123');
      await tester.enterText(textFields.at(4), 'Password@123');
      await tester.pump();

      await tester.ensureVisible(find.text('Sign Up'));
      await tester.pump();
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(mockAuthRepo.lastRegisteredPhone, equals('(817) 123-4567'));
      expect(mockAuthRepo.lastRegisteredEmail, equals('robert@test.com'));
    });
  });
}
