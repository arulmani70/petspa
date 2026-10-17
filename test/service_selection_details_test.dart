import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/views/mobile/service_detail_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/services/views/service_detail_page.dart';

class _FakeServiceRepositoryWithCatalog extends ServiceRepository {
  final BookingServicesResult catalog;

  _FakeServiceRepositoryWithCatalog(this.catalog);

  @override
  Future<BookingServicesResult> getBookingServices() async {
    return catalog;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingServicesResult testCatalog;
  late _FakeServiceRepositoryWithCatalog testRepo;

  setUp(() {
    testCatalog = BookingServicesResult.fallback();
    testRepo = _FakeServiceRepositoryWithCatalog(testCatalog);
    if (serviceLocator.isRegistered<ServiceRepository>()) {
      serviceLocator.unregister<ServiceRepository>();
    }
    serviceLocator.registerSingleton<ServiceRepository>(testRepo);
  });

  tearDown(() {
    if (serviceLocator.isRegistered<ServiceRepository>()) {
      serviceLocator.unregister<ServiceRepository>();
    }
  });

  group('Service Selection and ID Resolution (No Overlap / Mismatch)', () {
    test('getServiceDetail resolves correct Add-On even when ID equals a Breed ID', () async {
      // Breed ID 1 is "Small Dog (Under 20 lbs) — Grooming"
      // Add-on ID 1 is "Nail Grinding"
      final addOn1 = testCatalog.addOns.firstWhere((a) => a.id == 1);
      final breed1 = testCatalog.breeds.firstWhere((b) => b.id == 1);

      expect(addOn1.id, equals(1));
      expect(breed1.id, equals(1));

      // Query specifically for Add-on ID 1
      final resolvedAddOn = await testRepo.getServiceDetail(
        id: addOn1.id,
        code: addOn1.code,
        name: addOn1.name,
        isAddOn: true,
        initialService: addOn1.toMap(),
      );

      expect(resolvedAddOn, isNotNull);
      expect(resolvedAddOn!['name'], equals('Nail Grinding'));
      expect(resolvedAddOn['isAddOn'], isTrue);
      expect(resolvedAddOn['name'], isNot(equals(breed1.name)));

      // Query specifically for Breed ID 1
      final resolvedBreed = await testRepo.getServiceDetail(
        id: breed1.id,
        name: breed1.name,
        isAddOn: false,
        initialService: breed1.toMap(),
      );

      expect(resolvedBreed, isNotNull);
      expect(resolvedBreed!['name'], equals('Small Dog (Under 20 lbs) — Grooming'));
      expect(resolvedBreed['isAddOn'], isFalse);
    });

    test('getServiceDetail resolves Teeth Brushing (AddOn id: 2) instead of Breed id: 2', () async {
      final addOn2 = testCatalog.addOns.firstWhere((a) => a.id == 2);
      final breed2 = testCatalog.breeds.firstWhere((b) => b.id == 2);

      expect(addOn2.id, equals(2));
      expect(addOn2.name, equals('Teeth Brushing'));
      expect(breed2.id, equals(2));
      expect(breed2.name, contains('Bathing'));

      final resolved = await testRepo.getServiceDetail(
        id: addOn2.id,
        code: addOn2.code,
        name: addOn2.name,
        isAddOn: true,
        initialService: addOn2.toMap(),
      );

      expect(resolved, isNotNull);
      expect(resolved!['name'], equals('Teeth Brushing'));
      expect(resolved['id'], equals(2));
      expect(resolved['isAddOn'], isTrue);
    });

    test('ServiceBloc loads correct Add-On details without collision with Breed service', () async {
      final bloc = ServiceBloc(repository: testRepo);
      final addOn = testCatalog.addOns[1]; // Teeth Brushing (id: 2)

      final futureExpect = expectLater(
        bloc.stream,
        emitsThrough(
          isA<ServiceState>()
              .having((s) => s.detailStatus, 'detailStatus', ServiceStatus.loaded)
              .having((s) => s.selectedService?['name'], 'name', 'Teeth Brushing')
              .having((s) => s.selectedService?['isAddOn'], 'isAddOn', true),
        ),
      );

      bloc.add(GetServiceDetail(
        addOn.id,
        initialService: addOn.toMap(),
      ));

      await futureExpect;
    });

    test('ServiceBloc preserves initialService if repository returns a name mismatch', () async {
      final bloc = ServiceBloc(repository: testRepo);
      final clickedService = <String, dynamic>{
        'id': 99,
        'name': 'Custom Specialty Cut',
        'service_name': 'Custom Specialty Cut',
        'description': 'Unique hand-scissored styling',
        'price': 60.0,
        'priceDisplay': '\$60',
        'durationMinutes': 45,
        'isAddOn': false,
      };

      bloc.add(GetServiceDetail(
        99,
        initialService: clickedService,
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<ServiceState>()
              .having((s) => s.detailStatus, 'detailStatus', ServiceStatus.loaded)
              .having((s) => s.selectedService?['name'], 'name', 'Custom Specialty Cut'),
        ),
      );
    });

    test('ServiceBloc does not default invalid service ID to ID 1', () async {
      final bloc = ServiceBloc(repository: testRepo);

      bloc.add(const GetServiceDetail('invalid_nonexistent_id'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ServiceState>().having((s) => s.detailStatus, 'detailStatus', ServiceStatus.loading),
          isA<ServiceState>()
              .having((s) => s.detailStatus, 'detailStatus', ServiceStatus.failure)
              .having((s) => s.selectedService, 'selectedService', isNull)
              .having((s) => s.detailMessage, 'detailMessage', 'Service not found'),
        ]),
      );
    });
  });

  group('UI Validation: Add Button & Rapid Selection Navigation', () {
    testWidgets('Clicking Add on Service A opens Service A, navigating back and clicking Add on Service B opens Service B', (tester) async {
      final serviceA = testCatalog.walkIn[0]; // Full Grooming
      final serviceB = testCatalog.addOns[1]; // Teeth Brushing (id 2)

      // Test Service A Details
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceDetailPage(
            serviceId: serviceA.id.toString(),
            service: serviceA.toMap(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(serviceA.name), findsWidgets);
      expect(find.text('Service Details'), findsOneWidget);
      expect(find.text('Book Appointment'), findsOneWidget);

      // Now simulate navigating to Service B (Teeth Brushing)
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceDetailPage(
            serviceId: 'addon_${serviceB.id}',
            service: serviceB.toMap(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Service B details render and NOT Service A or Breed 2
      expect(find.text(serviceB.name), findsWidgets);
      expect(find.text('Teeth Brushing'), findsWidgets);
      expect(find.text(serviceA.name), findsNothing);
      expect(find.text('Book Appointment'), findsOneWidget);
    });

    testWidgets('Rapid selections and repeated navigation do not display stale service data', (tester) async {
      final s1 = testCatalog.addOns[0]; // Nail Grinding
      final s2 = testCatalog.addOns[1]; // Teeth Brushing
      final s3 = testCatalog.addOns[2]; // Blueberry Facial

      // Select S1
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceDetailPage(
            serviceId: s1.id.toString(),
            service: s1.toMap(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Nail Grinding'), findsWidgets);

      // Rapidly switch to S2 without waiting for full settlement
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceDetailPage(
            serviceId: s2.id.toString(),
            service: s2.toMap(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Teeth Brushing'), findsWidgets);
      expect(find.text('Nail Grinding'), findsNothing);

      // Rapidly switch to S3
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceDetailPage(
            serviceId: s3.id.toString(),
            service: s3.toMap(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Blueberry Facial'), findsWidgets);
      expect(find.text('Teeth Brushing'), findsNothing);
      expect(find.text('Nail Grinding'), findsNothing);
    });

    testWidgets('ServiceDetailPageMobile prevents stale state from overriding clicked initialService', (tester) async {
      // Create a bloc with stale state (e.g. Full Grooming)
      final staleBloc = ServiceBloc(repository: testRepo);
      staleBloc.emit(staleBloc.state.copyWith(
        detailStatus: () => ServiceStatus.loaded,
        selectedService: () => testCatalog.walkIn[0].toMap(), // Full Grooming
      ));

      // User opens ServiceDetailPageMobile for Teeth Brushing
      final clickedService = testCatalog.addOns[1].toMap(); // Teeth Brushing

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ServiceBloc>.value(
            value: staleBloc,
            child: ServiceDetailPageMobile(
              serviceId: '2',
              initialService: clickedService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure Teeth Brushing is rendered, not the stale Full Grooming
      expect(find.text('Teeth Brushing'), findsWidgets);
      expect(find.text('Full Grooming'), findsNothing);
    });
  });
}
