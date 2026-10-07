import 'package:intl/intl.dart';

/// Helper to convert "HH:mm" or "hh:mm a" to total minutes from midnight.
int timeToMinutes(String time) {
  final clean = time.trim();
  if (clean.isEmpty) return 0;

  try {
    if (clean.toLowerCase().contains('am') || clean.toLowerCase().contains('pm')) {
      final parsed = DateFormat('h:mm a').parseLoose(clean);
      return parsed.hour * 60 + parsed.minute;
    }
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return h * 60 + m;
    }
  } catch (_) {}
  return 0;
}

/// Helper to format "09:00" or 24h/12h time string to standard "09:00 AM" display.
String formatTimeTo12h(String time) {
  final clean = time.trim();
  if (clean.isEmpty) return '—';

  try {
    if (clean.toLowerCase().contains('am') || clean.toLowerCase().contains('pm')) {
      final parsed = DateFormat('h:mm a').parseLoose(clean);
      return DateFormat('hh:mm a').format(parsed);
    }
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final dt = DateTime(2026, 1, 1, h, m);
      return DateFormat('hh:mm a').format(dt);
    }
  } catch (_) {}
  return clean;
}

/// Helper to format "09:00 AM" back to "09:00" 24h format.
String formatTimeTo24h(String time) {
  final clean = time.trim();
  if (clean.isEmpty) return '';

  try {
    if (clean.toLowerCase().contains('am') || clean.toLowerCase().contains('pm')) {
      final parsed = DateFormat('h:mm a').parseLoose(clean);
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    }
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
  } catch (_) {}
  return clean;
}

class StoreServiceHour {
  final int? id;
  final String dayOfWeek;
  final bool isOpen;
  final String startTime;
  final String endTime;
  final String? lastBookingAvailable;
  final String? clientId;
  final String? regionId;
  final String? storeId;

  const StoreServiceHour({
    this.id,
    required this.dayOfWeek,
    required this.isOpen,
    required this.startTime,
    required this.endTime,
    this.lastBookingAvailable,
    this.clientId,
    this.regionId,
    this.storeId,
  });

  String get startFormatted => isOpen && startTime.isNotEmpty ? formatTimeTo12h(startTime) : '—';
  String get endFormatted => isOpen && endTime.isNotEmpty ? formatTimeTo12h(endTime) : '—';
  int get startMinutes => timeToMinutes(startTime);
  int get endMinutes => timeToMinutes(endTime);

  bool get isValidRange => !isOpen || (startMinutes < endMinutes);

  factory StoreServiceHour.fromJson(Map<String, dynamic> json) {
    int? parsedId;
    if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString());
    }

    String day = json['dayOfWeek']?.toString() ?? json['Day']?.toString() ?? '';
    if (day.toLowerCase() == 'sumday') day = 'Sunday';
    if (day.toLowerCase() == 'tueday') day = 'Tuesday';

    final openVal = json['isOpen'] ?? json['Open'];
    final isOpen = openVal is bool
        ? openVal
        : (openVal?.toString().toLowerCase() == 'yes' ||
            openVal?.toString().toLowerCase() == 'true' ||
            openVal == 1);

    String start = json['startTime']?.toString() ?? json['Start']?.toString() ?? '';
    String end = json['endTime']?.toString() ?? json['End']?.toString() ?? '';

    // If backend returns closing time like "05:30" (meaning 17:30 / 5:30 PM), normalize
    if (end.startsWith('05:') || end.startsWith('5:')) {
      final parts = end.split(':');
      if (parts.length >= 2) {
        end = '17:${parts[1]}';
      }
    }

    final lastBooking = json['lastBookingAvailable']?.toString() ?? json['last_booking_available']?.toString();

    return StoreServiceHour(
      id: parsedId,
      dayOfWeek: day,
      isOpen: isOpen,
      startTime: start,
      endTime: end,
      lastBookingAvailable: lastBooking,
      clientId: json['clientId']?.toString() ?? json['ClientID']?.toString(),
      regionId: json['regionId']?.toString() ?? json['RegionId']?.toString(),
      storeId: json['storeId']?.toString() ?? json['StoreId']?.toString(),
    );
  }

  StoreServiceHour copyWith({
    int? id,
    String? dayOfWeek,
    bool? isOpen,
    String? startTime,
    String? endTime,
    String? lastBookingAvailable,
    String? clientId,
    String? regionId,
    String? storeId,
  }) {
    return StoreServiceHour(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isOpen: isOpen ?? this.isOpen,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      lastBookingAvailable: lastBookingAvailable ?? this.lastBookingAvailable,
      clientId: clientId ?? this.clientId,
      regionId: regionId ?? this.regionId,
      storeId: storeId ?? this.storeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'dayOfWeek': dayOfWeek,
      'isOpen': isOpen,
      'startTime': startTime,
      'endTime': endTime,
      if (lastBookingAvailable != null) 'lastBookingAvailable': lastBookingAvailable,
      if (clientId != null) 'clientId': clientId,
      if (regionId != null) 'regionId': regionId,
      if (storeId != null) 'storeId': storeId,
    };
  }
}

class GroomerBreak {
  final int? id;
  final String groomerCode;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String reason;
  final String leaveType;
  final String? clientId;
  final String? regionId;
  final String? storeId;

  const GroomerBreak({
    this.id,
    required this.groomerCode,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.reason = 'Lunch break',
    this.leaveType = 'break',
    this.clientId,
    this.regionId,
    this.storeId,
  });

  String get startFormatted => formatTimeTo12h(startTime);
  String get endFormatted => formatTimeTo12h(endTime);
  String get formattedRange => '${formatTimeTo12h(startTime)} – ${formatTimeTo12h(endTime)}';
  int get startMinutes => timeToMinutes(startTime);
  int get endMinutes => timeToMinutes(endTime);

  bool get isValidRange => startMinutes < endMinutes;

  factory GroomerBreak.fromJson(Map<String, dynamic> json) {
    int? parsedId;
    if (json['id'] != null || json['scheduleRecordId'] != null) {
      parsedId = int.tryParse((json['id'] ?? json['scheduleRecordId']).toString());
    }

    return GroomerBreak(
      id: parsedId,
      groomerCode: json['groomerCode']?.toString() ?? '',
      dayOfWeek: json['dayOfWeek']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'Break',
      leaveType: json['leaveType']?.toString() ?? 'break',
      clientId: json['clientId']?.toString() ?? json['ClientID']?.toString(),
      regionId: json['regionId']?.toString() ?? json['RegionId']?.toString(),
      storeId: json['storeId']?.toString() ?? json['StoreId']?.toString(),
    );
  }

  GroomerBreak copyWith({
    int? id,
    String? groomerCode,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? reason,
    String? leaveType,
    String? clientId,
    String? regionId,
    String? storeId,
  }) {
    return GroomerBreak(
      id: id ?? this.id,
      groomerCode: groomerCode ?? this.groomerCode,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reason: reason ?? this.reason,
      leaveType: leaveType ?? this.leaveType,
      clientId: clientId ?? this.clientId,
      regionId: regionId ?? this.regionId,
      storeId: storeId ?? this.storeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'groomerCode': groomerCode,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'reason': reason,
      'leaveType': leaveType,
      if (clientId != null) 'clientId': clientId,
      if (regionId != null) 'regionId': regionId,
      if (storeId != null) 'storeId': storeId,
    };
  }
}

class GroomerWorkingHour {
  final int? id;
  final String groomerCode;
  final String dayOfWeek;
  final bool isWorking;
  final String startTime;
  final String endTime;
  final List<GroomerBreak> breaks;
  final String? clientId;
  final String? regionId;
  final String? storeId;

  const GroomerWorkingHour({
    this.id,
    required this.groomerCode,
    required this.dayOfWeek,
    required this.isWorking,
    required this.startTime,
    required this.endTime,
    this.breaks = const [],
    this.clientId,
    this.regionId,
    this.storeId,
  });

  String get startFormatted => isWorking ? formatTimeTo12h(startTime) : '—';
  String get endFormatted => isWorking ? formatTimeTo12h(endTime) : '—';
  int get startMinutes => timeToMinutes(startTime);
  int get endMinutes => timeToMinutes(endTime);

  bool get isValidRange => !isWorking || (startMinutes < endMinutes);

  factory GroomerWorkingHour.fromJson(Map<String, dynamic> json) {
    int? parsedId;
    if (json['id'] != null || json['scheduleRecordId'] != null) {
      parsedId = int.tryParse((json['id'] ?? json['scheduleRecordId']).toString());
    }

    final rawWorking = json['isWorking'] ?? json['working'];
    final isWorking = rawWorking is bool
        ? rawWorking
        : (rawWorking?.toString().toLowerCase() == 'true' ||
            rawWorking?.toString().toLowerCase() == 'yes' ||
            rawWorking == 1);

    final breaksList = <GroomerBreak>[];
    if (json['breaks'] is List) {
      breaksList.addAll((json['breaks'] as List)
          .map((b) => GroomerBreak.fromJson(Map<String, dynamic>.from(b as Map))));
    }

    return GroomerWorkingHour(
      id: parsedId,
      groomerCode: json['groomerCode']?.toString() ?? '',
      dayOfWeek: json['dayOfWeek']?.toString() ?? '',
      isWorking: isWorking,
      startTime: json['startTime']?.toString() ?? '09:00',
      endTime: json['endTime']?.toString() ?? '17:00',
      breaks: breaksList,
      clientId: json['clientId']?.toString() ?? json['ClientID']?.toString(),
      regionId: json['regionId']?.toString() ?? json['RegionId']?.toString(),
      storeId: json['storeId']?.toString() ?? json['StoreId']?.toString(),
    );
  }

  GroomerWorkingHour copyWith({
    int? id,
    String? groomerCode,
    String? dayOfWeek,
    bool? isWorking,
    String? startTime,
    String? endTime,
    List<GroomerBreak>? breaks,
    String? clientId,
    String? regionId,
    String? storeId,
  }) {
    return GroomerWorkingHour(
      id: id ?? this.id,
      groomerCode: groomerCode ?? this.groomerCode,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isWorking: isWorking ?? this.isWorking,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      breaks: breaks ?? this.breaks,
      clientId: clientId ?? this.clientId,
      regionId: regionId ?? this.regionId,
      storeId: storeId ?? this.storeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'scheduleRecordId': id,
      'groomerCode': groomerCode,
      'dayOfWeek': dayOfWeek,
      'isWorking': isWorking,
      'startTime': startTime,
      'endTime': endTime,
      if (breaks.isNotEmpty) 'breaks': breaks.map((b) => b.toJson()).toList(),
      if (clientId != null) 'clientId': clientId,
      if (regionId != null) 'regionId': regionId,
      if (storeId != null) 'storeId': storeId,
    };
  }
}

class StoreHoliday {
  final String holidayId;
  final String name;
  final String date;
  final String description;
  final bool isStoreSpecific;
  final String? clientId;
  final String? regionId;
  final String? storeId;

  const StoreHoliday({
    required this.holidayId,
    required this.name,
    required this.date,
    required this.description,
    this.isStoreSpecific = false,
    this.clientId,
    this.regionId,
    this.storeId,
  });

  factory StoreHoliday.fromJson(Map<String, dynamic> json) {
    final rawStoreSpecific = json['isStoreSpecific'] ?? json['IsStoreSpecific'];
    final isStoreSpecific = rawStoreSpecific is bool
        ? rawStoreSpecific
        : (rawStoreSpecific?.toString().toLowerCase() == 'true' || rawStoreSpecific?.toString() == '1');

    return StoreHoliday(
      holidayId: json['holidayId']?.toString() ?? json['HolidayId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['Name']?.toString() ?? '',
      date: json['date']?.toString() ?? json['Date']?.toString() ?? '',
      description: json['description']?.toString() ?? json['Description']?.toString() ?? '',
      isStoreSpecific: isStoreSpecific,
      clientId: json['clientId']?.toString() ?? json['ClientID']?.toString(),
      regionId: json['regionId']?.toString() ?? json['RegionId']?.toString(),
      storeId: json['storeId']?.toString() ?? json['StoreId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'holidayId': holidayId,
      'name': name,
      'date': date,
      'description': description,
      'isStoreSpecific': isStoreSpecific,
      if (clientId != null) 'clientId': clientId,
      if (regionId != null) 'regionId': regionId,
      if (storeId != null) 'storeId': storeId,
    };
  }
}

