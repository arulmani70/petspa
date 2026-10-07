import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';

class _MockApiRepository extends ApiRepository {
  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/holidays') {
      return {
        'success': true,
        'data': {
          'HolidayList': [
            {"HolidayId": "H001", "Name": "Independence Day", "Date": "07/04/2026", "Description": "Day of Independence"},
            {"HolidayId": "H002", "Name": "Easter", "Date": "4/28/2026", "Description": "Easter"},
            {"HolidayId": "H003", "Name": "Invalid Date", "Date": null},
            {"HolidayId": "H004", "Name": "Missing Date"}
          ]
        }
      };
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();

    final apiRepo = _MockApiRepository();
    await apiRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);
  });

  test('StoreRepository parses holydas.json safely and checks holidays', () async {
    final repo = StoreRepository();

    // 1. holydas.json loads successfully through StoreRepository.
    final holidays = await repo.getHolidays();
    
    // 2. Holiday records are parsed using the actual JSON structure.
    expect(holidays.length, 4);
    expect(holidays[0]['HolidayId'], 'H001');

    // 4. A date matching a holiday is correctly identified.
    expect(repo.isHoliday(DateTime(2026, 7, 4)), isTrue);
    expect(repo.isHoliday(DateTime(2026, 4, 28)), isTrue);

    // 5. A non-holiday date is not incorrectly identified.
    expect(repo.isHoliday(DateTime(2026, 7, 5)), isFalse);

    // 6. Edge case / Malformed records do not cause a crash.
    expect(repo.isHoliday(DateTime(2026, 1, 1)), isFalse);
  });
}
