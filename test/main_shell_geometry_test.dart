import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/common/services/network_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/shell/main_shell.dart';

class _FakeNetworkService extends NetworkService {
  @override
  bool get isOnline => true;
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.white, child: SizedBox.expand());
  }
}

void main() {
  setUpAll(() {
    serviceLocator.registerSingleton<NetworkService>(_FakeNetworkService());
  });

  testWidgets('bottom nav matches Figma Group 75900', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, s) => const _Placeholder())]),
            StatefulShellBranch(routes: [GoRoute(path: '/services', builder: (_, s) => const _Placeholder())]),
            StatefulShellBranch(routes: [GoRoute(path: '/bookings', builder: (_, s) => const _Placeholder())]),
            StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, s) => const _Placeholder())]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Pill (Rectangle 32): 355x78 @ (17.5, 732), radius ~39.
    final pill = tester.getRect(find.byType(BackdropFilter));
    expect(pill.width, closeTo(355, 0.5));
    expect(pill.height, closeTo(78, 0.5));
    expect(pill.top, closeTo(732, 0.5));
    expect(pill.bottom, closeTo(810, 0.5));

    // Pill styling: blur 30, drop shadow, white @ 0.6 fill + border.
    final backdrop = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    final blur = backdrop.filter.toString();
    expect(blur, contains('30'));

    // Selected tab: 50x50 rounded square (radius 16) with the dark gradient,
    // white icon. On /home it sits behind the home icon (center ~56).
    final blockFinder = find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape != BoxShape.circle &&
        (w.decoration as BoxDecoration).gradient is LinearGradient &&
        ((w.decoration as BoxDecoration).gradient as LinearGradient).colors.length == 2 &&
        ((w.decoration as BoxDecoration).gradient as LinearGradient).colors[0] ==
            const Color(0xFF3A3A3A) &&
        ((w.decoration as BoxDecoration).gradient as LinearGradient).colors[1] ==
            Colors.black &&
        (w.decoration as BoxDecoration).borderRadius ==
            const BorderRadius.all(Radius.circular(16)));
    expect(blockFinder, findsOneWidget);
    final blockBox = blockFinder.evaluate().single.renderObject! as RenderBox;
    final blockTopLeft = blockBox.localToGlobal(Offset.zero);
    final blockRect =
        Rect.fromLTWH(blockTopLeft.dx, blockTopLeft.dy, blockBox.size.width, blockBox.size.height);
    expect(blockRect.width, closeTo(50, 0.5));
    expect(blockRect.height, closeTo(50, 0.5));
    expect(blockRect.top, closeTo(746, 0.5));
    expect(blockRect.center.dx, closeTo(56, 6));

    // No cyan border ring anywhere.
    expect(
      find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border is Border &&
          ((w.decoration as BoxDecoration).border as Border).top.color ==
              const Color(0xFF0DC3EE)),
      findsNothing,
    );

    // Inactive tabs are dimmed (0.3 opacity), active is full (4 inactive tabs among 5 items).
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.3),
      findsNWidgets(4),
    ); // Tapping the second tab moves the block to the pets tab (center ~125).
    await tester.tap(find.byIcon(Icons.pets_rounded));
    await tester.pumpAndSettle();
    expect(blockFinder, findsOneWidget);
    final movedBox = blockFinder.evaluate().single.renderObject! as RenderBox;
    final movedCenter =
        movedBox.localToGlobal(Offset.zero).dx + movedBox.size.width / 2;
    expect(movedCenter, closeTo(125, 6));
    expect(find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.3),
        findsNWidgets(4));

    // Profile icon is 28x28
    final profileIcon = find.byWidgetPredicate((w) =>
        w is SvgPicture &&
        w.bytesLoader is SvgAssetLoader &&
        (w.bytesLoader as SvgAssetLoader).assetName.endsWith('fi_1077114_1_486.svg'));
    expect(profileIcon, findsOneWidget);
    final sc = tester.widget<SvgPicture>(profileIcon);
    expect(sc.width, closeTo(28, 0.5));
    expect(sc.height, closeTo(28, 0.5));
  });
}
