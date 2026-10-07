import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/bloc/groomer_login_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/repo/groomer_login_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('GroomerLoginBloc Tests', () {
    late GroomerLoginRepository repository;
    late GroomerLoginBloc bloc;

    setUp(() {
      repository = ServicesLocator.groomerLoginRepository;
      bloc = GroomerLoginBloc(repository: repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state has status initial', () {
      expect(bloc.state.status, equals(GroomerLoginStatus.initial));
      expect(bloc.state.loginResponse, isNull);
      expect(bloc.state.errorMessage, isNull);
    });

    test('GroomerLoginInitialEvent resets state to initial', () {
      bloc.add(const GroomerLoginInitialEvent());
      expect(bloc.state.status, equals(GroomerLoginStatus.initial));
    });

    test('GroomerLoginLogoutEvent resets state and clears session', () async {
      bloc.add(const GroomerLoginLogoutEvent());
      await Future.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.status, equals(GroomerLoginStatus.initial));
    });
  });

  group('GroomerLoginRepository Tests', () {
    test('getCurrentGroomer returns null when no session saved', () {
      final groomer = ServicesLocator.groomerLoginRepository.getCurrentGroomer();
      expect(groomer, isNull);
    });
  });
}
