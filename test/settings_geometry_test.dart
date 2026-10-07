import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('settings matches Figma 1:2292: appbar, profile card, 3 account items', (tester) async {
    await pump(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('My Pets'), findsOneWidget);
    expect(find.text('My Bookings'), findsOneWidget);

    // Figma has no edit button, no footer.
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    // ACCOUNT label is black per Figma (not grey).
    final accountLabel = tester.widget<Text>(find.text('ACCOUNT'));
    expect(accountLabel.style?.color, Colors.black);

    // AppBar: 67 tall (Rectangle 153) with drop shadow blur 20 @ 10%.
    final appBar = tester.widget<PreferredSize>(find.byType(PreferredSize).first);
    expect(appBar.preferredSize, const Size.fromHeight(67));
    final appBarDeco = tester.widget<Container>(
      find.ancestor(of: find.byType(AppBar), matching: find.byType(Container)).first,
    );
    final deco = appBarDeco.decoration as BoxDecoration;
    expect((deco.boxShadow?.first.blurRadius ?? 0), 20);
    expect(deco.boxShadow?.first.color.a, closeTo(0.10, 0.001));

    // Profile card: 80 tall, r12, #FAFAFA, shadow blur 20 @ 10%, no image fill.
    final profileCard = find.byKey(const Key('settings_profile_card'));
    expect(profileCard, findsOneWidget);
    final profileContainer = tester.widget<Container>(profileCard);
    final profileDeco = profileContainer.decoration as BoxDecoration;
    expect(profileDeco.color, const Color(0xFFFAFAFA));
    expect(profileDeco.borderRadius, BorderRadius.circular(12));
    expect(profileDeco.image, isNull);
    expect(profileDeco.boxShadow?.first.blurRadius, 20);

    // Account card: 4 rows of 32 + 3 gaps of 19 + padding 20/20 = 225 tall, #FAFAFA.
    final accountCard = find.byKey(const Key('settings_account_card'));
    expect(accountCard, findsOneWidget);
    final accountContainer = tester.widget<Container>(accountCard);
    final accountDeco = accountContainer.decoration as BoxDecoration;
    expect(accountDeco.color, const Color(0xFFFAFAFA));
    expect(accountDeco.boxShadow?.first.blurRadius, 20);
    expect(tester.getSize(accountCard).height, 225);
    expect(tester.getSize(accountCard).width, 356);

    // My Bookings uses the filled calendar icon (Figma Group 76119).
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.byIcon(Icons.pets), findsOneWidget);
  });
}
