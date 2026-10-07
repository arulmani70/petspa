import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/bloc/groomer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_login_response.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/repo/groomer_repository.dart';

class MockApiRepository extends ApiRepository {
  String? lastPostPath;
  dynamic lastPostData;
  Map<String, dynamic>? mockPostResponse;
  bool shouldThrowPostError = false;

  String? lastGetPath;
  Map<String, dynamic>? mockGetResponse;

  String? lastPutPath;
  Map<String, dynamic>? lastPutData;
  bool mockPutSuccess = true;

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    lastGetPath = path;
    return mockGetResponse;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPostPath = path;
    lastPostData = data;
    if (shouldThrowPostError) {
      throw Exception('Network connection failed');
    }
    return mockPostResponse;
  }

  @override
  Future<bool> put(String path, Map<String, dynamic> data) async {
    lastPutPath = path;
    lastPutData = data;
    return mockPutSuccess;
  }

  String? lastPutDataPath;
  Map<String, dynamic>? lastPutDataBody;
  Map<String, dynamic>? mockPutDataResponse = {'success': true};

  @override
  Future<Map<String, dynamic>?> putData(String path, Map<String, dynamic> data) async {
    lastPutDataPath = path;
    lastPutDataBody = data;
    return mockPutDataResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiRepository mockApi;
  late SessionService sessionService;
  late GroomerAuthRepository groomerRepo;

  setUp(() async {
    await GetIt.instance.reset();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    mockApi = MockApiRepository();
    sessionService = SessionService();
    await sessionService.initialize();

    groomerRepo = GroomerAuthRepository();

    GetIt.instance.registerSingleton<ApiRepository>(mockApi);
    GetIt.instance.registerSingleton<SessionService>(sessionService);
    GetIt.instance.registerSingleton<GroomerAuthRepository>(groomerRepo);
  });

  group('GroomerUser Model Tests', () {
    test('parses full groomer JSON successfully', () {
      final json = {
        'id': 1,
        'groomerCode': 'G001',
        'firstName': 'Merisa',
        'lastName': 'Brown',
        'email': 'g001@shearheaven.com',
        'mobile': '9876543210',
        'role': 'Lead Groomer',
        'highlights': 'Best lead groomer in town',
        'type': 'Groomer',
        'isActive': true,
        'multiBookingEnabled': true,
        'slotBookingLimit': 3,
        'mustChangePassword': false,
        'clientId': 'SHEAR-001',
        'regionId': 'DWG-001',
        'storeId': 'SHEAR-001',
      };

      final groomer = GroomerUser.fromJson(json);

      expect(groomer.id, 1);
      expect(groomer.groomerCode, 'G001');
      expect(groomer.firstName, 'Merisa');
      expect(groomer.lastName, 'Brown');
      expect(groomer.fullName, 'Merisa Brown');
      expect(groomer.email, 'g001@shearheaven.com');
      expect(groomer.role, 'Lead Groomer');
      expect(groomer.highlights, 'Best lead groomer in town');
      expect(groomer.isActive, isTrue);
      expect(groomer.multiBookingEnabled, isTrue);
      expect(groomer.slotBookingLimit, 3);
      expect(groomer.mustChangePassword, isFalse);
    });

    test('serializes GroomerUser to JSON correctly', () {
      const groomer = GroomerUser(
        id: 2,
        groomerCode: 'G002',
        firstName: 'John',
        lastName: 'Doe',
        email: 'g002@shearheaven.com',
        role: 'Assistant Groomer',
        multiBookingEnabled: false,
        slotBookingLimit: 1,
      );

      final json = groomer.toJson();

      expect(json['id'], 2);
      expect(json['groomerCode'], 'G002');
      expect(json['firstName'], 'John');
      expect(json['lastName'], 'Doe');
      expect(json['multiBookingEnabled'], false);
      expect(json['slotBookingLimit'], 1);
    });
  });

  group('GroomerLoginResponse Model Tests', () {
    test('parses login response JSON with mustChangePassword flag', () {
      final json = {
        'accessToken': 'test-access-token',
        'refreshToken': 'test-refresh-token',
        'mustChangePassword': true,
        'groomer': {
          'id': 1,
          'groomerCode': 'G001',
          'firstName': 'Merisa',
          'lastName': 'Brown',
          'email': 'g001@shearheaven.com',
        },
      };

      final response = GroomerLoginResponse.fromJson(json);

      expect(response.accessToken, 'test-access-token');
      expect(response.refreshToken, 'test-refresh-token');
      expect(response.mustChangePassword, isTrue);
      expect(response.groomer.fullName, 'Merisa Brown');
    });
  });

  group('GroomerAuthRepository Tests', () {
    test('login sends POST /api/groomer-auth/login and stores session on success', () async {
      mockApi.mockPostResponse = {
        'success': true,
        'message': 'Groomer logged in successfully',
        'data': {
          'accessToken': 'access-token-xyz',
          'refreshToken': 'refresh-token-xyz',
          'mustChangePassword': false,
          'groomer': {
            'id': 1,
            'groomerCode': 'G001',
            'firstName': 'Merisa',
            'lastName': 'Brown',
            'email': 'g001@shearheaven.com',
            'role': 'Lead Groomer',
            'multiBookingEnabled': true,
            'slotBookingLimit': 3,
          },
        },
      };

      final result = await groomerRepo.login(
        email: 'g001@shearheaven.com',
        password: 'Groomer@123',
      );

      expect(mockApi.lastPostPath, '/api/groomer-auth/login');
      expect(mockApi.lastPostData?['email'], 'g001@shearheaven.com');
      expect(mockApi.lastPostData?['password'], 'Groomer@123');
      expect(result, isNotNull);
      expect(result!.mustChangePassword, isFalse);
      expect(result.groomer.firstName, 'Merisa');

      // Verify stored session
      final storedGroomer = groomerRepo.getCurrentGroomer();
      expect(storedGroomer, isNotNull);
      expect(storedGroomer!.groomerCode, 'G001');
      expect(storedGroomer.multiBookingEnabled, isTrue);
      expect(storedGroomer.slotBookingLimit, 3);
    });

    test('setupAccount sends POST /api/groomer-auth/setup-account with full credentials', () async {
      mockApi.mockPostResponse = {
        'success': true,
        'message': 'Account setup completed successfully',
        'data': {
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
          'mustChangePassword': false,
          'groomer': {
            'id': 1,
            'groomerCode': 'G001',
            'firstName': 'Merisa',
            'lastName': 'Brown',
            'email': 'g001@shearheaven.com',
            'role': 'Lead Groomer',
          },
        },
      };

      final result = await groomerRepo.setupAccount(
        tempLoginId: 'g00112345@temp.com',
        tempPassword: 'Tmp@123',
        email: 'g001@shearheaven.com',
        password: 'NewPassword@123',
        confirmPassword: 'NewPassword@123',
      );

      expect(mockApi.lastPostPath, '/api/groomer-auth/setup-account');
      expect(mockApi.lastPostData?['tempLoginId'], 'g00112345@temp.com');
      expect(mockApi.lastPostData?['password'], 'NewPassword@123');
      expect(result, isNotNull);
      expect(result!.accessToken, 'new-access-token');
    });

    test('getProfile sends GET /api/groomer-auth/profile and updates stored groomer data', () async {
      mockApi.mockGetResponse = {
        'success': true,
        'data': {
          'id': 1,
          'groomerCode': 'G001',
          'firstName': 'Merisa',
          'lastName': 'Brown',
          'email': 'g001@shearheaven.com',
          'role': 'Lead Groomer',
          'multiBookingEnabled': true,
          'slotBookingLimit': 3,
        },
      };

      final profile = await groomerRepo.getProfile();

      expect(mockApi.lastGetPath, '/api/groomer-auth/profile');
      expect(profile, isNotNull);
      expect(profile!.firstName, 'Merisa');
      expect(profile.multiBookingEnabled, isTrue);
      expect(profile.slotBookingLimit, 3);
    });

    test('refreshToken sends POST /api/groomer-auth/refresh-token with refresh token', () async {
      await sessionService.saveGroomerSession(
        accessToken: 'old-access-tok',
        refreshToken: 'valid-refresh-tok',
        groomerData: {'id': 1, 'firstName': 'Merisa'},
      );

      mockApi.mockPostResponse = {
        'success': true,
        'data': {
          'accessToken': 'fresh-new-access-tok',
        },
      };

      final ok = await groomerRepo.refreshToken();

      expect(mockApi.lastPostPath, '/api/groomer-auth/refresh-token');
      expect(mockApi.lastPostData?['refreshToken'], 'valid-refresh-tok');
      expect(ok, isTrue);

      final updatedTok = await sessionService.getGroomerAccessToken();
      expect(updatedTok, 'fresh-new-access-tok');
    });

    test('login throws exception on failure or invalid credentials', () async {
      mockApi.mockPostResponse = {
        'success': false,
        'message': 'Invalid email or password',
      };

      expect(
        () => groomerRepo.login(email: 'wrong@example.com', password: 'bad'),
        throwsException,
      );
    });

    test('logout clears groomer session data and tokens', () async {
      mockApi.mockPostResponse = {
        'success': true,
        'message': 'Groomer logged in successfully',
        'data': {
          'accessToken': 'tok1',
          'refreshToken': 'tok2',
          'mustChangePassword': false,
          'groomer': {
            'id': 1,
            'groomerCode': 'G001',
            'firstName': 'Merisa',
            'lastName': 'Brown',
            'email': 'g001@shearheaven.com',
          },
        },
      };

      await groomerRepo.login(email: 'g001@shearheaven.com', password: 'pw');
      expect(groomerRepo.getCurrentGroomer(), isNotNull);
      expect(sessionService.isGroomerLoggedIn, isTrue);

      await groomerRepo.logout();
      expect(groomerRepo.getCurrentGroomer(), isNull);
      expect(sessionService.isGroomerLoggedIn, isFalse);
    });

    test('isGroomerLoggedIn persists across new repository instances without re-login', () async {
      expect(sessionService.isGroomerLoggedIn, isFalse);

      await sessionService.saveGroomerSession(
        accessToken: 'saved-token',
        refreshToken: 'saved-refresh',
        groomerData: {
          'id': 1,
          'groomerCode': 'G001',
          'firstName': 'Merisa',
          'lastName': 'Brown',
          'email': 'g001@shearheaven.com',
          'mustChangePassword': false,
        },
      );

      // App re-launches / creates new GroomerAuthRepository
      final freshRepo = GroomerAuthRepository();
      expect(sessionService.isGroomerLoggedIn, isTrue);
      final restoredGroomer = freshRepo.getCurrentGroomer();
      expect(restoredGroomer, isNotNull);
      expect(restoredGroomer!.firstName, 'Merisa');
    });

    test('getUpcomingBookings parses live groomer bookings correctly', () async {
      mockApi.mockGetResponse = {
        'success': true,
        'message': 'Upcoming bookings retrieved successfully',
        'data': [
          {
            'bookingId': 25,
            'status': 'pending',
            'bookingDate': '2026-08-22',
            'startTime': '14:30',
            'endTime': '15:30',
            'pet': {
              'id': 2,
              'petName': 'Simba',
              'breed': 'German Shepherd',
              'profilePicture': 'pet-simba.jpg',
            },
            'user': {
              'id': 2,
              'name': 'Arul',
              'email': 'arul77231@gmail.com',
              'mobile': '9876543210',
            },
            'serviceId': 1,
            'serviceName': 'Small Breeds - Grooming',
            'addOns': [
              {'id': 1, 'name': 'Nail Grinding'},
            ],
            'totalPrice': 63.0,
            'totalDurationMinutes': 60,
          },
        ],
      };

      final bookings = await groomerRepo.getUpcomingBookings();
      expect(mockApi.lastGetPath, '/api/groomer-auth/bookings/upcoming');
      expect(bookings.length, 1);
      expect(bookings.first.bookingId, 25);
      expect(bookings.first.petName, 'Simba');
      expect(bookings.first.customerName, 'Arul');
      expect(bookings.first.formattedTimeRange, contains('PM'));
      expect(bookings.first.fullServiceDescription, contains('Nail Grinding'));
    });

    test('approveBooking and rejectBooking execute correct endpoints', () async {
      mockApi.mockPostResponse = {
        'success': true,
        'message': 'Booking approved successfully',
      };

      final approved = await groomerRepo.approveBooking(25);
      expect(mockApi.lastPostPath, '/api/groomer-auth/bookings/25/approve');
      expect(approved, isTrue);

      final rejected = await groomerRepo.rejectBooking(25);
      expect(mockApi.lastPostPath, '/api/groomer-auth/bookings/25/reject');
      expect(rejected, isTrue);
    });

    test('approveCancellation and rejectCancellation execute correct endpoints', () async {
      mockApi.mockPostResponse = {
        'success': true,
        'message': 'Cancellation request processed',
      };

      final approved = await groomerRepo.approveCancellation(25);
      expect(mockApi.lastPostPath, '/api/groomer-auth/bookings/25/approve-cancellation');
      expect(approved, isTrue);

      final rejected = await groomerRepo.rejectCancellation(25);
      expect(mockApi.lastPostPath, '/api/groomer-auth/bookings/25/reject-cancellation');
      expect(rejected, isTrue);
    });

    test('createBookingForUser sends correct payload and endpoint', () async {
      mockApi.mockPostResponse = {
        'success': true,
        'data': {
          'bookingId': 99,
          'status': 'confirmed',
        },
      };

      final res = await groomerRepo.createBookingForUser(
        userId: 1,
        petId: 2,
        serviceId: 12,
        packageId: 1,
        addOnIds: [2],
        bookingDate: '2026-08-25',
        startTime: '10:00',
        endTime: '11:00',
      );

      expect(mockApi.lastPostPath, '/api/groomer-auth/bookings/create-for-user');
      expect(res?['bookingId'], 99);
      expect(mockApi.lastPostData['userId'], 1);
      expect(mockApi.lastPostData['serviceId'], 12);
    });

    test('getAvailability sends correct query params', () async {
      mockApi.mockGetResponse = {
        'success': true,
        'data': {
          'date': '2026-08-25',
          'slots': [
            {'startTime': '08:00', 'endTime': '09:00', 'isAvailable': true, 'bookingCount': 1, 'maxBookings': 3},
          ],
        },
      };

      final res = await groomerRepo.getAvailability(
        date: '2026-08-25',
        groomerId: 1,
        durationMinutes: 60,
      );

      expect(mockApi.lastGetPath, '/api/groomer-availability');
      expect(res?['slots'], isNotEmpty);
    });

    test('getServiceHours parses operating schedule correctly', () async {
      mockApi.mockGetResponse = {
        'success': true,
        'data': {
          'ClientID': 'SHEAR-001',
          'RegionId': 'DWG-001',
          'StoreId': 'SHEAR-001',
          'HolidayList': [
            {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '05:30'},
            {'Day': 'Sunday', 'Open': 'No', 'Start': '', 'End': ''},
          ],
        },
      };

      final hours = await groomerRepo.getServiceHours();
      expect(mockApi.lastGetPath, '/api/service-hours');
      expect(hours.length, 2);
      expect(hours[0].dayOfWeek, 'Monday');
      expect(hours[0].isOpen, isTrue);
      expect(hours[0].startTime, '08:00');
      expect(hours[1].dayOfWeek, 'Sunday');
      expect(hours[1].isOpen, isFalse);
    });

    test('getHolidays parses store holidays correctly', () async {
      mockApi.mockGetResponse = {
        'success': true,
        'data': {
          'ClientID': 'SHEAR-001',
          'RegionId': 'DWG-001',
          'StoreId': 'SHEAR-001',
          'HolidayList': [
            {
              'HolidayId': 'H001',
              'Name': 'Independence Day',
              'Date': '07/04/2026',
              'Description': 'Day of Independence',
            },
          ],
        },
      };

      final holidays = await groomerRepo.getHolidays();
      expect(mockApi.lastGetPath, '/api/holidays');
      expect(holidays.length, 1);
      expect(holidays[0].holidayId, 'H001');
      expect(holidays[0].name, 'Independence Day');
    });

    test('notifications methods call correct endpoints', () async {
      mockApi.mockGetResponse = {
        'success': true,
        'data': [
          {'id': 1, 'title': 'Test Notice', 'isRead': false},
        ],
      };

      final notifs = await groomerRepo.getNotifications();
      expect(mockApi.lastGetPath, '/api/notifications');
      expect(notifs.length, 1);

      mockApi.mockPutDataResponse = {'success': true};
      final readOne = await groomerRepo.markNotificationRead(1);
      expect(mockApi.lastPutDataPath, '/api/notifications/1/read');
      expect(readOne, isTrue);

      final readAll = await groomerRepo.markAllNotificationsRead();
      expect(mockApi.lastPutDataPath, '/api/notifications/read-all');
      expect(readAll, isTrue);
    });
  });

  group('GroomerBloc Tests', () {
    late GroomerRepository groomerRepo;
    late MockApiRepository mockApi;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final session = SessionService();
      await session.initialize();

      mockApi = MockApiRepository();
      await mockApi.initialize();

      GetIt.I.allowReassignment = true;
      GetIt.I.registerSingleton<SessionService>(session);
      GetIt.I.registerSingleton<ApiRepository>(mockApi);

      groomerRepo = GroomerRepository();
      await groomerRepo.initialize();
      GetIt.I.registerSingleton<GroomerRepository>(groomerRepo);
    });

    test('initial state has initial status and current date', () {
      final bloc = GroomerBloc(repository: groomerRepo);
      expect(bloc.state.status, GroomerStatus.initial);
      expect(bloc.state.upcomingBookings, isEmpty);
      expect(bloc.state.pendingBookings, isEmpty);
      bloc.close();
    });

    test('GroomerSelectDateEvent updates selectedDate in state', () async {
      final bloc = GroomerBloc(repository: groomerRepo);
      final targetDate = DateTime(2026, 9, 15);
      final expectation = expectLater(
        bloc.stream,
        emits(predicate<GroomerState>((s) => s.selectedDate == targetDate)),
      );
      bloc.add(GroomerSelectDateEvent(targetDate));
      await expectation;
      await bloc.close();
    });

    test('GroomerSwitchTabEvent updates currentTabIndex in state', () async {
      final bloc = GroomerBloc(repository: groomerRepo);
      final expectation = expectLater(
        bloc.stream,
        emits(predicate<GroomerState>((s) => s.currentTabIndex == 2)),
      );
      bloc.add(const GroomerSwitchTabEvent(2));
      await expectation;
      await bloc.close();
    });
  });
}



