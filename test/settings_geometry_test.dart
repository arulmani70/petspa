import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shear_heaven_pet_spa/src/account/views/settings_page.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => {'id': 1, 'name': 'Alexander'};
}

void main() {
  setUpAll(() {
    serviceLocator.registerSingleton<AuthRepository>(_FakeAuthRepository());
    serviceLocator.registerSingleton<SessionService>(SessionService());
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: SettingsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('settings matches design: appbar, profile card, account items, support items', (tester) async {
    await pump(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('My Pets'), findsOneWidget);
    expect(find.text('My Bookings'), findsOneWidget);
    expect(find.text('My Notification'), findsOneWidget);
    expect(find.text('About & Support'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Privacy & Policy'), findsOneWidget);
    expect(find.text('Terms & Condition'), findsOneWidget);

    // Social media removed per user request
    expect(find.text('Follow Us On Social Media'), findsNothing);

    // Profile card exists
    final profileCard = find.byKey(const Key('settings_profile_card'));
    expect(profileCard, findsOneWidget);

    // Account card exists
    final accountCard = find.byKey(const Key('settings_account_card'));
    expect(accountCard, findsOneWidget);

    // SVGs rendered for each menu item
    expect(find.byType(SvgPicture), findsWidgets);
  });
}
