import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/views/mobile/package_detail_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/services/views/mobile/service_detail_page_mobile.dart';

class _MockServiceRepo extends ServiceRepository {
  final Map<String, dynamic> mockService;
  final Map<String, dynamic> mockPackage;

  _MockServiceRepo({
    required this.mockService,
    required this.mockPackage,
  });

  @override
  Future<Map<String, dynamic>?> getServiceById(int id) async {
    if (id == mockService['id']) return mockService;
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getPackageById(int id) async {
    if (id == mockPackage['id']) return mockPackage;
    return null;
  }
}

void main() {
  group('ServiceRepository.resolveImageUrl', () {
    test('resolves localhost URLs to devapi domain', () {
      const raw = 'http://localhost:3464/services_img/svc_full_grooming.png';
      final resolved = ServiceRepository.resolveImageUrl(raw);
      expect(resolved, 'https://devapi.shearheavenpetspa.com/services_img/svc_full_grooming.png');
    });

    test('resolves 127.0.0.1 URLs to devapi domain', () {
      const raw = 'http://127.0.0.1:3000/images/test.png';
      final resolved = ServiceRepository.resolveImageUrl(raw);
      expect(resolved, 'https://devapi.shearheavenpetspa.com/images/test.png');
    });

    test('resolves relative URLs starting with / to devapi domain', () {
      const raw = '/services_img/pkg_small_dog.png';
      final resolved = ServiceRepository.resolveImageUrl(raw);
      expect(resolved, 'https://devapi.shearheavenpetspa.com/services_img/pkg_small_dog.png');
    });

    test('resolves relative URLs not starting with /', () {
      const raw = 'services_img/pkg_medium_dog.png';
      final resolved = ServiceRepository.resolveImageUrl(raw);
      expect(resolved, 'https://devapi.shearheavenpetspa.com/services_img/pkg_medium_dog.png');
    });

    test('keeps valid external https URLs intact', () {
      const raw = 'https://images.unsplash.com/photo-123.jpg';
      final resolved = ServiceRepository.resolveImageUrl(raw);
      expect(resolved, raw);
    });

    test('returns null for null or empty input', () {
      expect(ServiceRepository.resolveImageUrl(null), isNull);
      expect(ServiceRepository.resolveImageUrl(''), isNull);
      expect(ServiceRepository.resolveImageUrl('   '), isNull);
    });
  });

  group('Service Details & Package Details BLoC and UI', () {
    final testServiceMap = <String, dynamic>{
      'id': 1,
      'is_package': false,
      'is_addon': false,
      'service_name': 'Full Grooming',
      'name': 'Full Grooming',
      'description': 'Comprehensive bath, haircut, and styling.',
      'price': 55.0,
      'priceDisplay': '\$55.00',
      'price_display': '\$55.00',
      'durationMinutes': 60,
      'duration_minutes': 60,
      'includes': ['Bath with premium shampoo', 'Blow dry', 'Haircut & Styling', 'Nail trim'],
      'image_url': 'https://devapi.shearheavenpetspa.com/services_img/svc_full_grooming.png',
      'imageUrl': 'https://devapi.shearheavenpetspa.com/services_img/svc_full_grooming.png',
    };

    final testPackageMap = <String, dynamic>{
      'id': 1,
      'is_package': true,
      'is_addon': false,
      'package_name': 'Small Dog Spa Package',
      'service_name': 'Small Dog Spa Package',
      'name': 'Small Dog Spa Package',
      'description': 'Special care for small dogs under 25 lbs.',
      'price': 65.0,
      'priceDisplay': '\$65.00',
      'price_display': '\$65.00',
      'durationMinutes': 75,
      'duration_minutes': 75,
      'includes': ['Gentle bath', 'Nail clipping', 'Ear cleaning', 'Teeth brushing'],
      'image_url': 'https://devapi.shearheavenpetspa.com/services_img/pkg_small_dog.png',
      'imageUrl': 'https://devapi.shearheavenpetspa.com/services_img/pkg_small_dog.png',
    };

    test('ServiceBloc handles GetServiceDetail correctly', () async {
      final repo = _MockServiceRepo(mockService: testServiceMap, mockPackage: testPackageMap);
      final bloc = ServiceBloc(repository: repo);

      bloc.add(const GetServiceDetail(1));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ServiceState>().having((s) => s.detailStatus, 'status', ServiceStatus.loading),
          isA<ServiceState>()
              .having((s) => s.detailStatus, 'status', ServiceStatus.loaded)
              .having((s) => s.selectedService?['service_name'], 'service_name', 'Full Grooming')
              .having((s) => s.selectedService?['price_display'], 'price_display', '\$55.00'),
        ]),
      );
    });

    test('ServiceBloc handles GetPackageDetail correctly', () async {
      final repo = _MockServiceRepo(mockService: testServiceMap, mockPackage: testPackageMap);
      final bloc = ServiceBloc(repository: repo);

      bloc.add(const GetPackageDetail(1));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ServiceState>().having((s) => s.detailStatus, 'status', ServiceStatus.loading),
          isA<ServiceState>()
              .having((s) => s.detailStatus, 'status', ServiceStatus.loaded)
              .having((s) => s.selectedPackage?['service_name'], 'service_name', 'Small Dog Spa Package')
              .having((s) => s.selectedPackage?['price_display'], 'price_display', '\$65.00')
              .having((s) => s.selectedPackage?['is_package'], 'is_package', true),
        ]),
      );
    });

    testWidgets('ServiceDetailPageMobile renders service details and price badge', (tester) async {
      final repo = _MockServiceRepo(mockService: testServiceMap, mockPackage: testPackageMap);
      final bloc = ServiceBloc(repository: repo);
      bloc.add(const GetServiceDetail(1));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ServiceBloc>.value(
            value: bloc,
            child: const ServiceDetailPageMobile(serviceId: '1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Full Grooming'), findsWidgets);
      expect(find.text('\$55.00'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('Comprehensive bath, haircut, and styling.'), findsOneWidget);
      expect(find.text('What\'s Included'), findsOneWidget);
      expect(find.text('Bath with premium shampoo'), findsOneWidget);
      expect(find.text('Book Appointment'), findsOneWidget);
    });

    testWidgets('PackageDetailPageMobile renders package details, inclusions and book button', (tester) async {
      final repo = _MockServiceRepo(mockService: testServiceMap, mockPackage: testPackageMap);
      final bloc = ServiceBloc(repository: repo);
      bloc.add(const GetPackageDetail(1));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ServiceBloc>.value(
            value: bloc,
            child: const PackageDetailPageMobile(packageId: '1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Small Dog Spa Package'), findsWidgets);
      expect(find.text('\$65.00'), findsOneWidget);
      expect(find.text('Approximately 75 minutes'), findsOneWidget);
      expect(find.text('Special care for small dogs under 25 lbs.'), findsOneWidget);
      expect(find.text('What\'s Included'), findsOneWidget);
      expect(find.text('Gentle bath'), findsOneWidget);
      expect(find.text('Nail clipping'), findsOneWidget);
      expect(find.text('Book Appointment'), findsOneWidget);
    });

    testWidgets('ServiceDetailPageMobile renders clicked service immediately via initialService', (tester) async {
      final clickedService = <String, dynamic>{
        'id': 24,
        'service_name': 'Breath Freshener Spray',
        'name': 'Breath Freshener Spray',
        'description': 'Refreshing dental spray for instant breath refreshment.',
        'price': 6.0,
        'priceDisplay': '\$6',
        'price_display': '\$6',
        'durationMinutes': 5,
        'includes': ['Breath Freshener Spray'],
        'imageUrl': 'assets/images/common/svc_teeth_brush.png',
      };

      final repo = _MockServiceRepo(mockService: testServiceMap, mockPackage: testPackageMap);
      final bloc = ServiceBloc(repository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ServiceBloc>.value(
            value: bloc,
            child: ServiceDetailPageMobile(
              serviceId: '24',
              initialService: clickedService,
            ),
          ),
        ),
      );

      // Verify that clicked service details render immediately
      expect(find.text('Breath Freshener Spray'), findsWidgets);
      expect(find.text('\$6'), findsOneWidget);
      expect(find.text('Refreshing dental spray for instant breath refreshment.'), findsOneWidget);

      // Verify image cover and center alignment
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsWidgets);
      final imageWidget = tester.widget<Image>(imageFinder.first);
      expect(imageWidget.fit, BoxFit.cover);
      expect(imageWidget.alignment, Alignment.center);
    });

    test('BookingServicesResult.fallback has unique IDs within each category', () {
      final fallback = BookingServicesResult.fallback();
      final serviceIds = <int>{};
      for (final s in fallback.breeds) {
        expect(serviceIds.add(s.id), isTrue, reason: 'Duplicate breed id: ${s.id}');
      }
      for (final s in fallback.walkIn) {
        expect(serviceIds.add(s.id), isTrue, reason: 'Duplicate walkIn id: ${s.id}');
      }
      final addOnIds = <int>{};
      for (final s in fallback.addOns) {
        expect(addOnIds.add(s.id), isTrue, reason: 'Duplicate addOn id: ${s.id}');
      }
    });
  });
}
