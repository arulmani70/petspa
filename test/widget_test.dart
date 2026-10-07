import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/brand_logo.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/primary_button.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/step_indicator.dart';

void main() {
  testWidgets('PrimaryButton renders label and handles tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: false,
          splashFactory: NoSplash.splashFactory,
        ),
        home: Scaffold(
          body: PrimaryButton(
            label: "Continue",
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(tapped, isTrue);
  });

  testWidgets('StepIndicator shows expected number of steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StepIndicator(currentStep: 2, totalSteps: 4),
        ),
      ),
    );

    expect(find.byType(Container), findsNWidgets(4));
  });

  testWidgets('BrandLogo renders pet icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandLogo(dark: true),
        ),
      ),
    );

    expect(find.byIcon(Icons.pets), findsOneWidget);
  });
}
