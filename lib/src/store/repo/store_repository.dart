import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

class StoreRepository {
  final Logger log = Logger();
  
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _schedule = [];
  List<Map<String, dynamic>> _groomers = [];

  List<Map<String, dynamic>> get cachedGroomers => _groomers;

  Future<void> initialize() async {
    try {
      log.d("StoreRepository::initialize::Initializing store repository");
      _holidays = await _loadHolidays();
      _schedule = await getStoreSchedule();
      _groomers = await getGroomers();
    } catch (error) {
      log.e("StoreRepository::initialize::Error: $error");
    }
  }

  Future<List<Map<String, dynamic>>> getGroomers() async {
    try {
      log.d("StoreRepository::getGroomers::Loading from API /api/groomers");
      final response = await ServicesLocator.apiRepository.get('/api/groomers');
      if (response == null || !response.containsKey('data')) throw Exception('Failed to fetch groomers');
      final raw = response['data'];

      List<Map<String, dynamic>> groomers = [];

      void addParsedGroomer(Map rawItem, {String defaultRole = 'Groomer', String defaultType = 'Groomer'}) {
        final item = Map<String, dynamic>.from(rawItem);
        final code = (item['GroomerId'] ?? item['BatherId'] ?? item['groomerCode'] ?? item['code'] ?? '')
            .toString()
            .trim();
        final fName = (item['FirstName'] ?? item['firstName'] ?? '').toString().trim();
        final lName = (item['LastName'] ?? item['lastName'] ?? '').toString().trim();
        final fullName = (item['name'] ?? (lName.isNotEmpty ? '$fName $lName' : fName)).toString().trim();
        final role = (item['Role'] ?? item['role'] ?? defaultRole).toString().trim();
        final type = (item['type'] ?? defaultType).toString().trim();

        int parsedId = 0;
        final rawId = item['id'] ?? item['groomerId'];
        if (rawId != null) {
          parsedId = int.tryParse(rawId.toString()) ?? 0;
        }

        if (parsedId == 0 && code.isNotEmpty) {
          final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
          final numVal = int.tryParse(digits) ?? 0;
          if (numVal > 0) {
            parsedId = code.toUpperCase().startsWith('B') ? numVal + 3 : numVal;
          }
        }

        item['id'] = parsedId > 0 ? parsedId : item['id'];
        item['groomerId'] = parsedId > 0 ? parsedId : item['groomerId'];
        item['groomerCode'] = code.isNotEmpty ? code : item['groomerCode'];
        item['name'] = fullName.isNotEmpty ? fullName : (code.isNotEmpty ? 'Groomer $code' : 'Groomer');
        item['firstName'] = fName;
        item['lastName'] = lName;
        item['role'] = role.isNotEmpty ? role : defaultRole;
        item['type'] = type.isNotEmpty ? type : defaultType;
        groomers.add(item);
      }

      if (raw is List) {
        for (var g in raw) {
          if (g is Map) addParsedGroomer(g);
        }
      } else if (raw is Map) {
        final rawMap = Map<String, dynamic>.from(raw);
        final gList = rawMap['Groomers'] ?? rawMap['groomers'] ?? rawMap['data'];
        if (gList is List) {
          for (var g in gList) {
            if (g is Map) addParsedGroomer(g, defaultRole: 'Lead Groomer', defaultType: 'Groomer');
          }
        }
        final bList = rawMap['Bathers'] ?? rawMap['bathers'];
        if (bList is List) {
          for (var b in bList) {
            if (b is Map) addParsedGroomer(b, defaultRole: 'Bather', defaultType: 'Bather');
          }
        }
      }
      _groomers = groomers;
      return groomers;
    } catch (error) {
      log.e("StoreRepository::getGroomers::Error loading groomers: $error");
      return _groomers;
    }
  }

  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    try {
      log.d("StoreRepository::getStoreSchedule::Loading from API /api/service-hours");
      final response = await ServicesLocator.apiRepository.get('/api/service-hours');
      if (response == null || !response.containsKey('data')) {
        // Fallback to /api/admin/store-hours if /api/service-hours fails
        final adminResp = await ServicesLocator.apiRepository.get('/api/admin/store-hours');
        if (adminResp != null && adminResp.containsKey('data')) {
          return _parseScheduleData(adminResp['data']);
        }
        throw Exception('Failed to fetch service hours');
      }
      return _parseScheduleData(response['data']);
    } catch (error) {
      log.e("StoreRepository::getStoreSchedule::Error loading schedule: $error");
      return _schedule;
    }
  }

  List<Map<String, dynamic>> _parseScheduleData(dynamic raw) {
    List<Map<String, dynamic>> schedule = [];
    if (raw is List) {
      for (var d in raw) {
        if (d is Map) schedule.add(Map<String, dynamic>.from(d));
      }
    } else if (raw is Map) {
      final list = raw['HolidayList'] ?? raw['schedule'] ?? raw['storeHours'] ?? raw['data'];
      if (list is List) {
        for (var d in list) {
          if (d is Map) schedule.add(Map<String, dynamic>.from(d));
        }
      }
    }
    _schedule = schedule;
    return schedule;
  }

  bool _matchesWeekday(String rawDay, int weekday) {
    final clean = rawDay.trim().toLowerCase();
    switch (weekday) {
      case DateTime.monday:
        return clean == 'monday' || clean == 'mon';
      case DateTime.tuesday:
        return clean == 'tuesday' || clean == 'tueday' || clean == 'tue';
      case DateTime.wednesday:
        return clean == 'wednesday' || clean == 'wed';
      case DateTime.thursday:
        return clean == 'thursday' || clean == 'thu' || clean == 'thur';
      case DateTime.friday:
        return clean == 'friday' || clean == 'fri';
      case DateTime.saturday:
        return clean == 'saturday' || clean == 'sat';
      case DateTime.sunday:
        return clean == 'sunday' || clean == 'sumday' || clean == 'sun';
      default:
        return false;
    }
  }

  bool isStoreClosedDay(DateTime date) {
    if (_schedule.isEmpty) return false;
    
    final match = _schedule.firstWhere(
      (s) {
        final dayStr = s['Day']?.toString() ?? s['dayOfWeek']?.toString() ?? s['day']?.toString() ?? '';
        return _matchesWeekday(dayStr, date.weekday);
      },
      orElse: () => <String, dynamic>{},
    );

    if (match.isNotEmpty) {
      // Check 'isOpen' boolean first
      if (match.containsKey('isOpen')) {
        final isOpenVal = match['isOpen'];
        if (isOpenVal == false || isOpenVal == 'false' || isOpenVal == 0 || isOpenVal == '0') {
          return true;
        }
        if (isOpenVal == true || isOpenVal == 'true' || isOpenVal == 1 || isOpenVal == '1') {
          return false;
        }
      }

      // Check 'Open' string / bool
      final open = match['Open']?.toString().trim().toLowerCase();
      if (open == 'no' || open == 'false' || open == '0') {
        return true;
      }
      if (open == 'yes' || open == 'true' || open == '1') {
        return false;
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getPetWeights() async {
    try {
      log.d("StoreRepository::getPetWeights::Loading from API /api/pet-weights");
      final response = await ServicesLocator.apiRepository.get('/api/pet-weights');
      final rawData = response?['data'];

      List<Map<String, dynamic>> petWeights = [];
      if (rawData is List) {
        for (var w in rawData) {
          if (w is Map) {
            petWeights.add(Map<String, dynamic>.from(w));
          }
        }
      } else if (rawData is Map) {
        final list = rawData['petWeights'] ?? rawData['weights'];
        if (list is List) {
          for (var w in list) {
            if (w is Map) {
              petWeights.add(Map<String, dynamic>.from(w));
            }
          }
        }
      }
      return petWeights;
    } catch (error) {
      log.e("StoreRepository::getPetWeights::Error loading pet weights: $error");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getHolidays() async {
    if (_holidays.isEmpty) {
      _holidays = await _loadHolidays();
    }
    return _holidays;
  }

  Future<List<Map<String, dynamic>>> _loadHolidays() async {
    try {
      log.d("StoreRepository::_loadHolidays::Loading from API /api/holidays");
      final response = await ServicesLocator.apiRepository.get('/api/holidays');
      if (response == null || !response.containsKey('data')) throw Exception('Failed to fetch holidays');
      final raw = response['data'];

      List<Map<String, dynamic>> holidays = [];
      if (raw is List) {
        for (var h in raw) {
          if (h is Map) holidays.add(Map<String, dynamic>.from(h));
        }
      } else if (raw is Map) {
        final list = raw['HolidayList'] ?? raw['holidays'] ?? raw['data'];
        if (list is List) {
          for (var h in list) {
            if (h is Map) holidays.add(Map<String, dynamic>.from(h));
          }
        }
      }
      _holidays = holidays;
      return holidays;
    } catch (error) {
      log.e("StoreRepository::_loadHolidays::Error loading holidays: $error");
      return _holidays;
    }
  }

  bool isHoliday(DateTime date) {
    return getHolidayName(date) != null;
  }

  String? getHolidayName(DateTime date) {
    for (var h in _holidays) {
      final dateStr = h['Date']?.toString() ?? h['date']?.toString();
      if (dateStr == null || dateStr.trim().isEmpty) continue;
      
      final cleanDateStr = dateStr.trim();
      
      // Parse M/D/YYYY or MM/DD/YYYY
      final slashParts = cleanDateStr.split('/');
      if (slashParts.length == 3) {
        final month = int.tryParse(slashParts[0]);
        final day = int.tryParse(slashParts[1]);
        final year = int.tryParse(slashParts[2]);
        if (month == date.month && day == date.day && year == date.year) {
          return h['Name']?.toString() ?? h['name']?.toString() ?? 'Holiday';
        }
      }

      // Parse YYYY-MM-DD or ISO timestamp
      final dateOnly = cleanDateStr.split('T')[0];
      final dashParts = dateOnly.split('-');
      if (dashParts.length == 3) {
        final year = int.tryParse(dashParts[0]);
        final month = int.tryParse(dashParts[1]);
        final day = int.tryParse(dashParts[2]);
        if (month == date.month && day == date.day && year == date.year) {
          return h['Name']?.toString() ?? h['name']?.toString() ?? 'Holiday';
        }
      }
    }
    return null;
  }
}
