import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/login_page.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {}

void main() {
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

  testWidgets('login screen matches Figma geometry', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final authBloc = AuthBloc(repository: _FakeAuthRepository());

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const LoginPage(),
      ),
    ));
    await tester.pumpAndSettle();

    final logo = find.byType(SvgPicture).first;
    expect(logo, findsOneWidget);
    final logoRect = tester.getRect(logo);
    expect(logoRect.width, closeTo(146, 1.0));
    expect(logoRect.height, closeTo(82, 1.0));

    expect(find.text('Customer Login'), findsOneWidget);
    expect(find.text("Log in to book your pet's appointment"), findsOneWidget);
    expect(find.text('Enter Email ID'), findsOneWidget);
    expect(find.text('Enter Password'), findsOneWidget);

    final createAccount = find.textContaining("Create Account", findRichText: true);
    expect(createAccount, findsOneWidget);
  });

  testWidgets('login input labels use font medium and reduced gap (4.0)', (tester) async {
    final emailText = find.text('Enter Email ID');
    final passwordText = find.text('Enter Password');

    final authBloc = AuthBloc(repository: _FakeAuthRepository());

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const LoginPage(),
      ),
    ));
    await tester.pumpAndSettle();

    final Text emailLabelWidget = tester.widget(emailText);
    expect(emailLabelWidget.style?.fontWeight, equals(FontWeight.w500));

    final Text passwordLabelWidget = tester.widget(passwordText);
    expect(passwordLabelWidget.style?.fontWeight, equals(FontWeight.w500));

    // Verify reduced gap between label Row and input container (4.0)
    final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    final gapSizedBoxes = sizedBoxes.where((sb) => sb.height == 4.0).toList();
    expect(gapSizedBoxes.length, greaterThanOrEqualTo(2));
  });

  testWidgets('login password field has view password icon and toggles obscureText', (tester) async {
    final authBloc = AuthBloc(repository: _FakeAuthRepository());

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const LoginPage(),
      ),
    ));
    await tester.pumpAndSettle();

    // Initially password field is obscured and shows visibility_off_outlined icon
    final visibilityOffIcon = find.byIcon(Icons.visibility_off_outlined);
    expect(visibilityOffIcon, findsOneWidget);

    final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields.length, equals(2));
    final emailField = textFields[0];
    final passwordField = textFields[1];

    expect(emailField.obscureText, isFalse);
    expect(passwordField.obscureText, isTrue);

    // Tap the visibility icon to toggle
    await tester.tap(visibilityOffIcon);
    await tester.pumpAndSettle();

    // Now it shows visibility_outlined icon and obscureText is false
    final visibilityOnIcon = find.byIcon(Icons.visibility_outlined);
    expect(visibilityOnIcon, findsOneWidget);

    final updatedTextFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(updatedTextFields[1].obscureText, isFalse);

    // Tap again to obscure
    await tester.tap(visibilityOnIcon);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    final reObscuredTextFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(reObscuredTextFields[1].obscureText, isTrue);
  });
}
