import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/create_account_page.dart';
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
  });

  testWidgets('create account screen matches Figma geometry', (tester) async {
    tester.view.physicalSize = const Size(390, 1123);
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
        child: const CreateAccountPage(),
      ),
    ));
    await tester.pumpAndSettle();

    final logo = find.byType(SvgPicture).first;
    expect(logo, findsOneWidget);
    final logoRect = tester.getRect(logo);
    expect(logoRect.width, closeTo(146, 1.0));
    expect(logoRect.height, closeTo(82, 1.0));

    expect(find.text('Create an Account'), findsOneWidget);
    expect(find.text('Sign up to create and account for booking'), findsOneWidget);
    expect(find.text('Enter Full Name'), findsOneWidget);
    expect(find.text('Enter Email ID'), findsOneWidget);

    final termsText = find.textContaining('binding arbitration', findRichText: true);
    expect(termsText, findsOneWidget);

    final loginLink = find.textContaining("Already have an account?", findRichText: true);
    expect(loginLink, findsOneWidget);
  });
}
