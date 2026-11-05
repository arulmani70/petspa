import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

void main() {
  group('Package Image Resolution Tests', () {
    test('serviceAssetFor maps Special Package and Heaven Scent Package correctly', () {
      expect(serviceAssetFor('Special Package'), 'assets/images/home/package_banner_1.png');
      expect(serviceAssetFor('special package'), 'assets/images/home/package_banner_1.png');
      expect(serviceAssetFor('Heaven Scent Package'), 'assets/images/home/package_banner_2.png');
      expect(serviceAssetFor('heaven scent package'), 'assets/images/home/package_banner_2.png');
      expect(serviceAssetFor('Heaven Scent'), 'assets/images/home/package_banner_2.png');
      expect(serviceAssetFor('Spa Package'), 'assets/images/common/svc_spa.png');
      expect(serviceAssetFor('Royal VIP Spa Package 4144'), 'assets/images/common/svc_spa.png');
      expect(serviceAssetFor('Unknown Custom Package'), 'assets/images/packages/package_banner.png');
    });

    testWidgets('Renders image widget for Special Package and Heaven Scent Package', (tester) async {
      const specialPkg = ServiceItem(
        id: 1,
        isPackage: true,
        isAddOn: false,
        name: 'Special Package',
        description: 'Special dog grooming package',
        price: 50.0,
        priceDisplay: '\$50',
        durationMinutes: 60,
      );

      const heavenScentPkg = ServiceItem(
        id: 2,
        isPackage: true,
        isAddOn: false,
        name: 'Heaven Scent Package',
        description: 'Heaven scent aroma bath package',
        price: 65.0,
        priceDisplay: '\$65',
        durationMinutes: 60,
      );

      // Verify asset path resolution matches expectation
      final asset1 = serviceAssetFor(specialPkg.name);
      final asset2 = serviceAssetFor(heavenScentPkg.name);

      expect(asset1, isNotNull);
      expect(asset2, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FigmaImage(asset: asset1!, width: 90, height: 90),
                FigmaImage(asset: asset2!, width: 90, height: 90),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FigmaImage), findsNWidgets(2));
      expect(find.byType(Image), findsNWidgets(2));
    });

    test('resolveImageUrl uses Constants.app.BASE_URL and preserves remote URLs', () {
      expect(
        ServiceRepository.resolveImageUrl('/uploads/packages/pkg1.png'),
        'https://api.shearheavenpetspa.com/uploads/packages/pkg1.png',
      );
      expect(
        ServiceRepository.resolveImageUrl('https://pcmdev.shearheavenpetspa.com/assets/images/home/package_banner_1.png'),
        'https://pcmdev.shearheavenpetspa.com/assets/images/home/package_banner_1.png',
      );
      expect(
        ServiceRepository.resolveImageUrl('assets/images/home/package_banner_1.png'),
        'assets/images/home/package_banner_1.png',
      );
    });
  });
}
