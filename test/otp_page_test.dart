import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/mobile/otp_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:toastification/toastification.dart';

class _MockAuthRepository extends AuthRepository {
  String? lastVerifiedCode;
  String? lastSentOtpEmail;

  @override
  Future<bool> verifyOtp(String code) async {
    lastVerifiedCode = code;
    return code == '123456';
  }

  @override
  Future<String> sendOtp(String email) async {
    lastSentOtpEmail = email;
    return '123456';
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

  testWidgets('OtpPageMobile renders bubbles, verify button, and NO in-app black keypad', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const OtpPageMobile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header elements
    expect(find.text('Enter OTP'), findsNWidgets(2)); // Title + Lock label
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Resend OTP'), findsOneWidget);

    // Verify custom in-app black keypad is NOT present
    expect(find.byIcon(Icons.backspace_outlined), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);

    // Verify native TextField is present for device keyboard
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Typing OTP in native TextField populates bubbles and triggers verification on 6 digits', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const OtpPageMobile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter 6 digits via native text field
    final textField = find.byType(TextField);
    await tester.enterText(textField, '123456');
    await tester.pump();

    // Verify each digit is displayed in the UI bubbles
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    // Wait for async verification
    await tester.pumpAndSettle();

    // Verify repository received the code
    expect(mockAuthRepo.lastVerifiedCode, equals('123456'));
  });

  testWidgets('Tapping Resend OTP triggers SendOtpSubmitted', (tester) async {
    authBloc.emit(authBloc.state.copyWith(
      otpSentTo: () => 'test@example.com',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: ToastificationWrapper(
          child: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const OtpPageMobile(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resend OTP'));
    await tester.runAsync(() async => await Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(mockAuthRepo.lastSentOtpEmail, equals('test@example.com'));
    expect(
      find.text('OTP sent to your email', skipOffstage: false),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 6));
  });
}
