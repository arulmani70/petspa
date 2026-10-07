import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/otp_page.dart';
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

  testWidgets('otp screen matches Figma geometry debug', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47);
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
        child: const OtpPage(),
      ),
    ));
    await tester.pumpAndSettle();
  });
}
