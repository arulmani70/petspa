import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/bloc/groomer_register_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/repo/groomer_register_repository.dart';

class _MockApiRepository extends ApiRepository {
  String? lastPostPath;
  dynamic lastPostData;
  Map<String, dynamic>? mockPostResponse;

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPostPath = path;
    lastPostData = data;
    return mockPostResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiRepository mockApi;
  late SessionService sessionService;
  late GroomerRegisterRepository repository;
  late GroomerRegisterBloc bloc;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    mockApi = _MockApiRepository();
    sessionService = SessionService();
    await sessionService.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ApiRepository>(mockApi);
    GetIt.I.registerSingleton<SessionService>(sessionService);

    repository = GroomerRegisterRepository();
    await repository.initialize();
    GetIt.I.registerSingleton<GroomerRegisterRepository>(repository);

    bloc = GroomerRegisterBloc(repository: repository);
  });

  tearDown(() {
    bloc.close();
  });

  group('GroomerRegisterBloc Tests', () {
    test('initial state has status initial', () {
      expect(bloc.state.status, equals(GroomerRegisterStatus.initial));
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.successMessage, isNull);
    });

    test('GroomerRegisterInitialEvent resets state to initial', () {
      bloc.add(const GroomerRegisterInitialEvent());
      expect(bloc.state.status, equals(GroomerRegisterStatus.initial));
    });

    test('GroomerRegisterSetupAccountEvent sends exact 5 API fields and emits success', () async {
      mockApi.mockPostResponse = {
        'success': true,
        'message': 'Account setup successful',
        'data': {
          'accessToken': 'mock-setup-token',
          'refreshToken': 'mock-setup-refresh',
          'mustChangePassword': false,
          'groomer': {
            'id': 1,
            'groomerCode': 'G001',
            'firstName': 'Ashna',
            'lastName': 'Menon',
            'email': 'b00161787832259039@temp.shearheaven.com',
            'role': 'Groomer',
          },
        },
      };

      bloc.add(const GroomerRegisterSetupAccountEvent(
        tempLoginId: 'b00161787832259039@temp.shearheaven.com',
        tempPassword: 'Tmp@4e5upw9',
        email: 'b00161787832259039@temp.shearheaven.com',
        password: 'Groomer@123',
        confirmPassword: 'Groomer@123',
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.status, equals(GroomerRegisterStatus.success));
      expect(mockApi.lastPostPath, equals('/api/groomer-auth/setup-account'));

      // Verify the exact 5 outgoing fields
      final outgoingPayload = mockApi.lastPostData as Map<String, dynamic>;
      expect(outgoingPayload.length, equals(5));
      expect(outgoingPayload['tempLoginId'], equals('b00161787832259039@temp.shearheaven.com'));
      expect(outgoingPayload['tempPassword'], equals('Tmp@4e5upw9'));
      expect(outgoingPayload['email'], equals('b00161787832259039@temp.shearheaven.com'));
      expect(outgoingPayload['password'], equals('Groomer@123'));
      expect(outgoingPayload['confirmPassword'], equals('Groomer@123'));
    });
  });

  group('GroomerRegisterRepository Tests', () {
    test('setupAccount sends POST /api/groomer-auth/setup-account with exact 5 payload fields', () async {
      mockApi.mockPostResponse = {
        'success': true,
        'message': 'Account setup successful',
        'data': {
          'accessToken': 'token-123',
          'refreshToken': 'refresh-123',
          'mustChangePassword': false,
          'groomer': {
            'id': 10,
            'groomerCode': 'GRM-10',
            'firstName': 'John',
            'lastName': 'Doe',
            'email': 'john@temp.shearheaven.com',
            'role': 'Groomer',
          },
        },
      };

      final response = await repository.setupAccount(
        tempLoginId: 'b00161787832259039@temp.shearheaven.com',
        tempPassword: 'Tmp@4e5upw9',
        email: 'b00161787832259039@temp.shearheaven.com',
        password: 'Groomer@123',
        confirmPassword: 'Groomer@123',
      );

      expect(response, isNotNull);
      expect(mockApi.lastPostPath, equals('/api/groomer-auth/setup-account'));

      final outgoingPayload = mockApi.lastPostData as Map<String, dynamic>;
      expect(outgoingPayload.keys.toSet(), equals({
        'tempLoginId',
        'tempPassword',
        'email',
        'password',
        'confirmPassword',
      }));
      expect(outgoingPayload['tempLoginId'], equals('b00161787832259039@temp.shearheaven.com'));
      expect(outgoingPayload['tempPassword'], equals('Tmp@4e5upw9'));
      expect(outgoingPayload['email'], equals('b00161787832259039@temp.shearheaven.com'));
      expect(outgoingPayload['password'], equals('Groomer@123'));
      expect(outgoingPayload['confirmPassword'], equals('Groomer@123'));
    });

    test('setupAccount throws Exception defensively when tempPassword is empty', () async {
      expect(
        () => repository.setupAccount(
          tempLoginId: 'temp_user_1',
          tempPassword: '   ',
          email: 'user@test.com',
          password: 'Password@123',
          confirmPassword: 'Password@123',
        ),
        throwsA(isA<Exception>()),
      );
      expect(mockApi.lastPostPath, isNull);
    });

    test('setupAccount throws Exception defensively when tempLoginId is empty', () async {
      expect(
        () => repository.setupAccount(
          tempLoginId: '   ',
          tempPassword: 'TempPassword123!',
          email: 'user@test.com',
          password: 'Password@123',
          confirmPassword: 'Password@123',
        ),
        throwsA(isA<Exception>()),
      );
      expect(mockApi.lastPostPath, isNull);
    });

    test('SessionService saves, retrieves, and clears temporary groomer credentials', () async {
      await sessionService.saveTempGroomerCredentials(
        tempLoginId: 'temp_user_1',
        tempPassword: 'TempPassword123!',
      );

      expect(sessionService.getTempGroomerLoginId(), equals('temp_user_1'));
      expect(await sessionService.getTempGroomerPassword(), equals('TempPassword123!'));

      await sessionService.clearTempGroomerCredentials();
      expect(sessionService.getTempGroomerLoginId(), isNull);
      expect(await sessionService.getTempGroomerPassword(), isNull);
    });

    test('getCurrentGroomer returns null when no session saved', () {
      final groomer = repository.getCurrentGroomer();
      expect(groomer, isNull);
    });
  });
}


