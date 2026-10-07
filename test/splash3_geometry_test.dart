import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/auth/views/splash_screens.dart';

void main() {
  testWidgets('splash screen 3 matches Figma geometry', (tester) async {
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
      home: const SplashScreens(),
    ));
    await tester.pumpAndSettle();

    // Tap Next to advance to Splash Screen 2
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Tap Next to advance to Splash Screen 3
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final titleText = "Track your pet's\ngrooming history";
    expect(find.text(titleText), findsOneWidget);

    final logo = find.byType(SvgPicture).first;
    final logoRect = tester.getRect(logo);
    expect(logoRect.width, closeTo(151.5, 1.0));
    expect(logoRect.height, closeTo(85, 1.0));

    expect(find.text('Get Started'), findsOneWidget);
  });
}
