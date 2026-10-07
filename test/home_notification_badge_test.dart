import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/account/repos/notification_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/home/views/mobile/home_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class _MockApiRepository extends ApiRepository {
  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/notifications') {
      return {
        'success': true,
        'message': 'Notifications retrieved',
        'data': [
          {'id': 1, 'title': 'Notif 1', 'message': 'Body 1', 'isRead': false},
          {'id': 2, 'title': 'Notif 2', 'message': 'Body 2', 'isRead': false},
          {'id': 3, 'title': 'Notif 3', 'message': 'Body 3', 'isRead': true},
        ]
      };
    }
    return {'success': true, 'data': []};
  }

  @override
  Future<bool> put(String path, Map<String, dynamic> data) async => true;
}

class _FakeAuthRepository extends AuthRepository {
  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => {'id': 1, 'name': 'Alexander'};
}

class _FakeServiceRepository extends ServiceRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllServices() async => [];
  @override
  Future<List<Map<String, dynamic>>> getAllPackages() async => [];
}

class _FakePetRepository extends PetRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationRepository notifRepo;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();

    final apiRepo = _MockApiRepository();
    await apiRepo.initialize();

    notifRepo = NotificationRepository();
    await notifRepo.initialize();

    final getIt = GetIt.I;
    getIt.allowReassignment = true;
    getIt.registerSingleton<SessionService>(session);
    getIt.registerSingleton<ApiRepository>(apiRepo);
    getIt.registerSingleton<NotificationRepository>(notifRepo);
    getIt.registerSingleton<AuthRepository>(_FakeAuthRepository());
    getIt.registerSingleton<ServiceRepository>(_FakeServiceRepository());
    getIt.registerSingleton<PetRepository>(_FakePetRepository());
  });

  testWidgets('Home page displays notification badge with unread count and updates dynamically', (tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc(repository: GetIt.I<AuthRepository>())),
          BlocProvider(create: (_) => ServiceBloc(repository: GetIt.I<ServiceRepository>())),
          BlocProvider(create: (_) => PetBloc(repository: GetIt.I<PetRepository>())),
        ],
        child: const MaterialApp(
          home: HomePageMobile(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify unread count is 2 and rendered on badge
    expect(notifRepo.unreadCount, 2);
    expect(find.text('2'), findsOneWidget);

    // Mark 1 as read
    await notifRepo.markAsRead(1);
    await tester.pumpAndSettle();

    // Verify badge decrements to 1
    expect(notifRepo.unreadCount, 1);
    expect(find.text('1'), findsOneWidget);

    // Mark all as read
    await notifRepo.markAllAsRead();
    await tester.pumpAndSettle();

    // Verify badge disappears when unread count is 0
    expect(notifRepo.unreadCount, 0);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
  });
}
