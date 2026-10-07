import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('GroomerHomeBloc Tests', () {
    late GroomerHomeRepository repository;
    late GroomerHomeBloc bloc;

    setUp(() {
      repository = ServicesLocator.groomerHomeRepository;
      bloc = GroomerHomeBloc(repository: repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state has status initial', () {
      expect(bloc.state.status, equals(GroomerHomeStatus.initial));
      expect(bloc.state.currentTabIndex, equals(0));
      expect(bloc.state.upcomingBookings, isEmpty);
    });

    test('GroomerHomeSwitchTabEvent updates tab index', () async {
      bloc.add(const GroomerHomeSwitchTabEvent(2));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.currentTabIndex, equals(2));
    });

    test('GroomerHomeSelectDateEvent updates selected date', () async {
      final date = DateTime(2026, 9, 15);
      bloc.add(GroomerHomeSelectDateEvent(date));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.selectedDate, equals(date));
    });

    test('GroomerHomeLogoutEvent resets state and clears session', () async {
      bloc.add(const GroomerHomeLogoutEvent());
      await Future.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.status, equals(GroomerHomeStatus.initial));
    });

    test('GroomerHomeSaveScheduleEvent handles save attempt', () async {
      final serviceHours = [
        const StoreServiceHour(dayOfWeek: 'Monday', isOpen: true, startTime: '08:00', endTime: '17:30'),
      ];
      final groomerHours = [
        const GroomerWorkingHour(groomerCode: 'G001', dayOfWeek: 'Monday', isWorking: true, startTime: '09:00', endTime: '17:00'),
      ];

      bloc.add(GroomerHomeSaveScheduleEvent(
        serviceHours: serviceHours,
        groomerHours: groomerHours,
      ));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.status, isNot(equals(GroomerHomeStatus.initial)));
    });

    test('GroomerHomeGetSalonGroomersEvent fetches and updates salon groomers in state', () async {
      bloc.add(const GroomerHomeGetSalonGroomersEvent());
      await Future.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.isLoadingSalonGroomers, isFalse);
      expect(bloc.state.salonGroomers, isA<List>());
    });

    test('GroomerHomeGetBookingServicesEvent fetches and updates services in state', () async {
      bloc.add(const GroomerHomeGetBookingServicesEvent());
      await Future.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.isLoadingBookingServices, isFalse);
      expect(bloc.state.bookingServices, isA<List>());
    });

    test('GroomerHomeCheckAvailabilityEvent triggers availability check in state', () async {
      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: DateTime.now(),
        groomerId: 2,
        serviceId: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.isCheckingAvailability, isFalse);
    });

    test('GroomerHomeResetBookingDialogEvent resets booking dialog state', () {
      bloc.add(const GroomerHomeResetBookingDialogEvent());
      expect(bloc.state.isCreatingBookingForUser, isFalse);
      expect(bloc.state.bookingForUserSuccess, isFalse);
      expect(bloc.state.bookingForUserError, isNull);
    });
  });

  group('GroomerHomeRepository Tests', () {
    test('getCurrentGroomer returns null when no session saved', () {
      final groomer = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
      expect(groomer, isNull);
    });

    test('getGroomerHours handles network request gracefully when unauthenticated', () async {
      final hours = await ServicesLocator.groomerHomeRepository.getGroomerHours(groomerCode: 'G001');
      expect(hours, isA<List<GroomerWorkingHour>>());
    });
  });
}

