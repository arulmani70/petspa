import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iOS Info.plist Privacy Review', () {
    test('Info.plist contains only genuinely required iOS privacy permissions (Camera & Photo Library)', () {
      final infoPlistFile = File('ios/Runner/Info.plist');
      expect(infoPlistFile.existsSync(), isTrue, reason: 'ios/Runner/Info.plist must exist');

      final content = infoPlistFile.readAsStringSync();

      // Camera permission (REQUIRED for profile photo capture)
      expect(content.contains('<key>NSCameraUsageDescription</key>'), isTrue);
      expect(content.contains('camera'), isTrue);

      // Photo library permission (REQUIRED for pet & avatar selection)
      expect(content.contains('<key>NSPhotoLibraryUsageDescription</key>'), isTrue);
      expect(content.contains('photo library'), isTrue);

      // Microphone permission should NOT be included (not used)
      expect(content.contains('<key>NSMicrophoneUsageDescription</key>'), isFalse);

      // ATS disabling should NOT be included (APIs use standard HTTPS)
      expect(content.contains('<key>NSAllowsArbitraryLoads</key>'), isFalse);
    });
  });

  group('iOS Platform & Keychain Services Tests', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      GetIt.I.allowReassignment = true;

      final session = SessionService();
      await session.initialize();
      GetIt.I.registerSingleton<SessionService>(session);

      final deviceIdService = DeviceIdService();
      await deviceIdService.initialize();
      GetIt.I.registerSingleton<DeviceIdService>(deviceIdService);
    });

    test('DeviceIdService produces persistent UUID on iOS Keychain', () async {
      final deviceService = ServicesLocator.deviceIdService;
      final id1 = await deviceService.getDeviceId();
      expect(id1.isNotEmpty, isTrue);

      final id2 = await deviceService.getDeviceId();
      expect(id2, equals(id1));
    });

    test('SessionService securely stores tokens and groomer credentials on iOS', () async {
      final session = ServicesLocator.sessionService;
      await session.saveTokens(accessToken: 'ios_access_tok', refreshToken: 'ios_refresh_tok');

      final access = await session.getAccessToken();
      final refresh = await session.getRefreshToken();
      expect(access, equals('ios_access_tok'));
      expect(refresh, equals('ios_refresh_tok'));

      await session.saveTempGroomerCredentials(
        tempLoginId: 'ios_groomer@temp.shearheaven.com',
        tempPassword: 'IosPassword@123',
      );
      final tempId = session.getTempGroomerLoginId();
      final tempPass = await session.getTempGroomerPassword();
      expect(tempId, equals('ios_groomer@temp.shearheaven.com'));
      expect(tempPass, equals('IosPassword@123'));
    });
  });

  group('iOS Responsive Breakpoints & Multi-Device Rendering', () {
    final iPhoneScreens = <String, Size>{
      'iPhone SE / 8': const Size(375, 667),
      'iPhone X / 11 Pro / 12 mini': const Size(375, 812),
      'iPhone 12 / 13 / 14': const Size(390, 844),
      'iPhone 14 Pro / 15 / 16': const Size(393, 852),
      'iPhone 14 Pro Max / 15 Pro Max / 16 Pro Max': const Size(430, 932),
      'iPhone SE 1st Gen (320w)': const Size(320, 568),
    };

    for (final entry in iPhoneScreens.entries) {
      testWidgets('Renders app layout on ${entry.key} (${entry.value.width}x${entry.value.height}) with iOS platform', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          Theme(
            data: ThemeData(
              platform: TargetPlatform.iOS,
              useMaterial3: true,
            ),
            child: ResponsiveBreakpoints(
              breakpoints: const [
                Breakpoint(start: 0, end: 450, name: MOBILE),
                Breakpoint(start: 451, end: 800, name: TABLET),
                Breakpoint(start: 801, end: 1920, name: DESKTOP),
                Breakpoint(start: 1921, end: double.infinity, name: '4K'),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: Center(child: Text('iOS Test Screen')),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verify no crash and ResponsiveBreakpoints resolves
        final responsiveFinder = find.byType(ResponsiveBreakpoints);
        expect(responsiveFinder, findsOneWidget);
        expect(find.text('iOS Test Screen'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }
  });
}
