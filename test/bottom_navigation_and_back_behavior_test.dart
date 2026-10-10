import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/exit_confirmation_dialog.dart';
import 'package:shear_heaven_pet_spa/src/shell/main_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    GetIt.I.allowReassignment = true;
    await ServicesLocator.initialize();
  });

  group('Bottom Navigation and Back Button Behavior Tests', () {
    testWidgets('ExitConfirmationDialog renders correctly and handles Cancel and Exit buttons', (tester) async {
      bool? userChoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    userChoice = await ExitConfirmationDialog.show(context);
                  },
                  child: const Text('Show Exit Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open Exit dialog
      await tester.tap(find.text('Show Exit Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog elements
      expect(find.text('Exit App?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit the application?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(userChoice, isFalse);
      expect(find.text('Exit App?'), findsNothing);

      // Open dialog again and tap Exit button
      await tester.tap(find.text('Show Exit Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Exit App?'), findsOneWidget);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(userChoice, isTrue);
      expect(find.text('Exit App?'), findsNothing);
    });

    testWidgets('MainShell navigation and back navigation back to Home tab', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return MainShell(navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (context, state) => const Scaffold(
                      body: Center(child: Text('Home Screen Content')),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/services',
                    builder: (context, state) => const Scaffold(
                      body: Center(child: Text('Services Screen Content')),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/chat',
                    builder: (context, state) => const Scaffold(
                      body: Center(child: Text('Chat Screen Content')),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/bookings',
                    builder: (context, state) => const Scaffold(
                      body: Center(child: Text('Bookings Screen Content')),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/settings',
                    builder: (context, state) => const Scaffold(
                      body: Center(child: Text('Settings Screen Content')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Home Screen Content'), findsOneWidget);

      // Tap Services tab (index 1 - pets icon)
      await tester.tap(find.byIcon(Icons.pets_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Services Screen Content'), findsOneWidget);

      // Simulate Android hardware back button
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Should return to Home screen
      expect(find.text('Home Screen Content'), findsOneWidget);

      // Tap Chat tab (index 2)
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();
      expect(find.text('Chat Screen Content'), findsOneWidget);

      // Simulate Android Back button
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home Screen Content'), findsOneWidget);

      // Tap Bookings tab (index 3)
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Bookings Screen Content'), findsOneWidget);

      // Simulate Android Back button
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home Screen Content'), findsOneWidget);

      // On Home screen (index 0), pressing back invokes ExitConfirmationDialog
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Exit App?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit the application?'), findsOneWidget);

      // Cancel exit dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Exit App?'), findsNothing);
      expect(find.text('Home Screen Content'), findsOneWidget);
    });
  });
}
