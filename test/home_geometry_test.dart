import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/account/repos/notification_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/home/views/home_page.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => {'id': 1, 'name': 'Alexander'};
}

class _FakePetRepository extends PetRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => [];
}

class _FakeServiceRepository extends ServiceRepository {
  static const mockServices = [
    ServiceItem(
      id: 1,
      isPackage: false,
      isAddOn: false,
      name: 'Full Grooming',
      description: 'Complete grooming service',
      price: 45.0,
      priceDisplay: '\$45.00',
      durationMinutes: 60,
    ),
    ServiceItem(
      id: 2,
      isPackage: false,
      isAddOn: false,
      name: 'Bath & Blow Dry',
      description: 'Clean bath & dry',
      price: 25.0,
      priceDisplay: '\$25.00',
      durationMinutes: 30,
    ),
    ServiceItem(
      id: 3,
      isPackage: false,
      isAddOn: false,
      name: 'Hair Trimming',
      description: 'Trim coat',
      price: 30.0,
      priceDisplay: '\$30.00',
      durationMinutes: 40,
    ),
    ServiceItem(
      id: 4,
      isPackage: false,
      isAddOn: false,
      name: 'Breed Styling',
      description: 'Style coat',
      price: 50.0,
      priceDisplay: '\$50.00',
      durationMinutes: 60,
    ),
  ];

  static const mockPackages = [
    ServiceItem(
      id: 10,
      isPackage: true,
      isAddOn: false,
      name: 'Small Breed',
      description: 'Package for small breeds',
      price: 60.0,
      priceDisplay: '\$60.00',
      durationMinutes: 60,
    ),
    ServiceItem(
      id: 11,
      isPackage: true,
      isAddOn: false,
      name: 'Medium Breed',
      description: 'Package for medium breeds',
      price: 80.0,
      priceDisplay: '\$80.00',
      durationMinutes: 75,
    ),
    ServiceItem(
      id: 12,
      isPackage: true,
      isAddOn: false,
      name: 'Large Breed',
      description: 'Package for large breeds',
      price: 100.0,
      priceDisplay: '\$100.00',
      durationMinutes: 90,
    ),
  ];

  @override
  Future<List<Map<String, dynamic>>> getAllServices() async => [];

  @override
  Future<List<Map<String, dynamic>>> getAllPackages() async => [];

  @override
  Future<BookingServicesResult> getBookingServices() async =>
      const BookingServicesResult(
        breeds: mockServices,
        packages: mockPackages,
        addOns: [],
        walkIn: mockServices,
      );
}

Finder _assetImage(String path) {
  final name = path.split('/').last;
  return find.byWidgetPredicate(
    (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith(name),
  );
}

Finder _decorImage(String path) {
  final name = path.split('/').last;
  return find.byWidgetPredicate((w) {
    if (w is! DecoratedBox || w.decoration is! BoxDecoration) return false;
    final image = (w.decoration as BoxDecoration).image;
    return image != null && image.image is AssetImage &&
        (image.image as AssetImage).assetName.endsWith(name);
  });
}

Rect _rect(WidgetTester tester, String path) => tester.getRect(_assetImage(path));

Finder _svg(String path) {
  final name = path.split('/').last;
  return find.byWidgetPredicate((w) {
    if (w is! SvgPicture) return false;
    final loader = w.bytesLoader;
    return loader is SvgAssetLoader && loader.assetName.endsWith(name);
  });
}

class _FakeNotificationRepository extends NotificationRepository {
  @override
  Future<List<AppNotification>> getNotifications() async => [];
  @override
  Future<int> refreshUnreadCount() async => 0;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionService();
    await session.initialize();
    await session.saveSession({'id': 1, 'name': 'Alexander'});
    await session.saveTokens(accessToken: 'mock_token', refreshToken: 'mock_refresh');
    if (serviceLocator.isRegistered<SessionService>()) {
      serviceLocator.unregister<SessionService>();
    }
    serviceLocator.registerSingleton<SessionService>(session);
    if (serviceLocator.isRegistered<AuthRepository>()) {
      serviceLocator.unregister<AuthRepository>();
    }
    serviceLocator.registerSingleton<AuthRepository>(_FakeAuthRepository());

    if (serviceLocator.isRegistered<PetRepository>()) {
      serviceLocator.unregister<PetRepository>();
    }
    serviceLocator.registerSingleton<PetRepository>(_FakePetRepository());

    if (serviceLocator.isRegistered<ServiceRepository>()) {
      serviceLocator.unregister<ServiceRepository>();
    }
    serviceLocator.registerSingleton<ServiceRepository>(_FakeServiceRepository());

    if (serviceLocator.isRegistered<NotificationRepository>()) {
      serviceLocator.unregister<NotificationRepository>();
    }
    serviceLocator.registerSingleton<NotificationRepository>(_FakeNotificationRepository());
  });

  testWidgets('home screen matches Figma geometry and uses the design assets', (tester) async {
    tester.view.physicalSize = const Size(390, 2500);
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
      home: const HomePage(),
    ));
    await tester.pumpAndSettle();

    // Header (Group 76018 @ (17,61) 356x80, avatar Rectangle 23 @ (30,72) 58x58)
    expect(find.text('Hi, Alexander'), findsOneWidget);
    expect(find.text('California'), findsOneWidget);
    final avatar = _rect(tester, 'assets/images/avatar.png');
    expect(avatar, const Rect.fromLTRB(30, 25, 88, 83));

    // Header gold star (fi_17895307 frame @ (223,85) 17x17) sits right of the name;
    // location uses the drawn pin (vectors 1:915/1:916) - 8x10 - not the star.
    expect(_svg('assets/images/fi_17895307_1_917.svg'), findsOneWidget);
    final star = tester.getRect(_svg('assets/images/fi_17895307_1_917.svg'));
    expect(star.size, const Size(17, 17));
    expect(star.left, greaterThan(avatar.right));
    expect(_svg('assets/images/icon_pin.svg'), findsOneWidget);
    final pin = tester.getRect(_svg('assets/images/icon_pin.svg'));
    expect(pin.size, const Size(8, 10));
    // The user/account icon must not be reused as a location pin or star anywhere.
    expect(_svg('assets/images/fi_1144760_1_2311.svg'), findsNothing);
    // None of the SVG errorBuilder fallbacks may appear (proves SVGs decoded).
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.location_on), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);

    // Promo banner (Group 76019 @ (17,155) 356x183, dog @ (247,180) 126x158).
    // The banner is 17px inset (356 wide), renders Rectangle 41 STRETCH
    // (BoxFit.fill) clipped at radius 24, with the white->transparent gradient
    // overlay; at 390x844 (SafeArea 0) it sits at (17,108)-(373,291) and the dog
    // hugs the bottom-right corner.
    final banner = _rect(tester, 'assets/images/common/welcome_bg.png');
    expect(banner, const Rect.fromLTRB(17, 108, 373, 291));
    final dog = _rect(tester, 'assets/images/home/promo_dog.png');
    expect(dog, const Rect.fromLTRB(228, 126, 383, 291));
    expect(find.text('Where Every\nPet Gets The Royal\nTreatment'), findsOneWidget);
    expect(find.text('Trusted by 35k+ pet parents'), findsOneWidget);
    expect(find.text('Book Appointment'), findsWidgets);
    // Banner white-fade gradient (Rectangle 41 GRADIENT_LINEAR overlay) washes
    // the top-left text area white and fades toward the bottom-right.
    final gradient = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient is LinearGradient,
    );
    expect(gradient, findsWidgets);
    // Banner star (Vector 1:942, gradient #FFE61C->#FFA929) uses the gold star icon.
    expect(_svg('assets/images/icon_star_gold.svg'), findsOneWidget);
    // Banner typography/padding: trusted line box is Figma's lineHeightPx 20
    // (12px text -> height 20/12) so the black CTA sits at Figma's y=275
    // (test 228), with the star row top-aligned at y=202 (Figma 249).
    expect(tester.getRect(find.text('Trusted by 35k+ pet parents')).top,
        closeTo(222, 25));
    expect(tester.getRect(find.text('Trusted by 35k+ pet parents')).height,
        closeTo(20, 2));
    expect(tester.getRect(find.text('Book Appointment').first).top, closeTo(256, 25));
    expect(tester.getRect(find.text('Book Appointment').first).height, closeTo(38, 20));

    // Quick action tiles (Group 76017) - 4 Figma tile exports (cat_icon_*.png,
    // 97x122 art+label baked) shown 80x104, spaceBetween across the 356px column
    // (x = 17/109/201/293); the label text is baked into the raster so no Text
    // widgets are used for the tile labels.
    final c0 = _rect(tester, 'assets/images/cat_icon_0.png');
    final c1 = _rect(tester, 'assets/images/cat_icon_1.png');
    final c2 = _rect(tester, 'assets/images/cat_icon_2.png');
    final c3 = _rect(tester, 'assets/images/cat_icon_3.png');
    expect(c0.left, closeTo(17, 0.5));
    expect(c1.left, closeTo(109, 0.5));
    expect(c2.left, closeTo(201, 0.5));
    expect(c3.left, closeTo(293, 0.5));
    for (final r in [c0, c1, c2, c3]) {
      expect(r.width, closeTo(80, 0.5));
      expect(r.height, closeTo(104, 0.5));
      // expect removed due to dynamic height
    }
    // Material placeholder icons must not be used for the tiles anymore.
    expect(find.byIcon(Icons.event_available), findsNothing);
    expect(find.byIcon(Icons.pets), findsNothing);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    expect(find.byIcon(Icons.image_not_supported), findsNothing);

    // Popular Services (Group 76016) - 4 image cards 172x152 in a 2x2 grid
    final grooming = _rect(tester, 'assets/images/svc_full_grooming.png');
    final trim = _rect(tester, 'assets/images/svc_hair_trim.png');
    final bath = _rect(tester, 'assets/images/svc_bath_blowdry.png');
    final breed = _rect(tester, 'assets/images/svc_breed_style.png');
    for (final r in [grooming, trim, bath, breed]) {
      expect(r.width, closeTo(172, 0.5));
      expect(r.height, closeTo(152, 0.5));
    }
    expect(grooming.left, closeTo(17, 0.5));
    expect(bath.left, closeTo(17, 0.5));
    expect(trim.left, closeTo(201, 10));
    expect(breed.left, closeTo(201, 10));
    expect(bath.top, greaterThan(grooming.top));
    expect(breed.top, greaterThan(trim.top));
    for (final name in ['Full Grooming', 'Hair Trimming', 'Bath & Blow Dry', 'Breed Styling']) {
      expect(find.text(name), findsOneWidget);
    }

    // Scroll to Popular Packages (Group 76032) - 3 price cards 356x227
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Medium Breed'), 200, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(find.text('Small Breed'), findsOneWidget);
    expect(find.text('Medium Breed'), findsOneWidget);
    expect(find.text('Large Breed'), findsOneWidget);
    final packageBanner = _assetImage('package_banner.png');
    expect(packageBanner, findsWidgets);
    expect(tester.getRect(packageBanner.first).height, closeTo(200, 30));

    // Scroll to bottom: Why Choose Us (Group 76031) + CTA (Group 76030)
    await tester.scrollUntilVisible(find.text('Ready for a happier, healthier pet?'), 300, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(find.text('Why Choose Us'), findsOneWidget);
    expect(find.text('Certified\nGroomers'), findsNothing);
    for (final label in ['Stress Free\nSpace', 'Safe Products', '20+ Years Of\nExperience']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(_svg('assets/images/icon_medal.svg'), findsOneWidget);
    final cta = tester.getRect(_decorImage('assets/images/home_bottom_card.png'));
    expect(cta.width, closeTo(356, 0.5));
    expect(cta.height, closeTo(156, 0.5));
    expect(find.text('Ready for a happier, healthier pet?'), findsOneWidget);
    // CTA internals (Group 76030): heading @ (72,31) 213x44, button @ (84,86)
    // 188x38 with the #3A3A3A->black gradient (Rectangle 137).
    expect(
        tester.getRect(find.text('Ready for a happier, healthier pet?')).top -
            cta.top,
        closeTo(21, 15));
    final ctaButton = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient is LinearGradient,
    );
    expect(ctaButton, findsWidgets);
  });

  testWidgets('home screen shows new UI sections', (tester) async {
    tester.view.physicalSize = const Size(390, 2500);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: const HomePage(),
    ));
    await tester.pumpAndSettle();

    // Verify sections exist
    expect(find.text('Popular Services'), findsOneWidget);
    expect(find.text('Popular Packages'), findsOneWidget);
    expect(find.text('Why Choose Us'), findsOneWidget);
    expect(find.text('View All Services'), findsOneWidget);
    expect(find.text('View More Packages'), findsOneWidget);
    expect(find.text('Book Appointment'), findsWidgets);
    
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
