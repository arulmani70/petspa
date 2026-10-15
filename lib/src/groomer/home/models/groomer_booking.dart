import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';

class GroomerBooking {
  final int bookingId;
  final String status;
  final String bookingDate; // YYYY-MM-DD
  final String startTime;
  final String endTime;
  final int? petId;
  final String petName;
  final String breed;
  final String? profilePicture;
  final int? userId;
  final String customerName;
  final String customerEmail;
  final String customerMobile;
  final int? serviceId;
  final String serviceName;
  final int? packageId;
  final String? packageName;
  final List<String> addOns;
  final double totalPrice;
  final int totalDurationMinutes;
  final String storeId;
  final String? createdAt;
  final String? cancellationReason;
  final int? groomerId;
  final String? groomerName;
  final String? groomerCode;

  const GroomerBooking({
    required this.bookingId,
    required this.status,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.petId,
    required this.petName,
    this.breed = '',
    this.profilePicture,
    this.userId,
    required this.customerName,
    this.customerEmail = '',
    this.customerMobile = '',
    this.serviceId,
    required this.serviceName,
    this.packageId,
    this.packageName,
    this.addOns = const [],
    this.totalPrice = 0.0,
    this.totalDurationMinutes = 30,
    this.storeId = '',
    this.createdAt,
    this.cancellationReason,
    this.groomerId,
    this.groomerName,
    this.groomerCode,
  });

  String get effectiveGroomerName {
    if (groomerName != null && groomerName!.trim().isNotEmpty) {
      return groomerName!.trim();
    }
    if (groomerId != null && groomerId! > 0) {
      final name = BookingDateUtils.resolveGroomerNameById(groomerId!);
      if (name != null && name.isNotEmpty) return name;
      return 'Groomer #$groomerId';
    }
    if (groomerCode != null && groomerCode!.trim().isNotEmpty) {
      return 'Groomer ${groomerCode!.trim()}';
    }
    return 'Assigned Staff';
  }

  String get formattedBookingDate =>
      BookingDateUtils.formatBookingDateDisplay(bookingDate);

  String get formattedTimeRange {
    try {
      final start = _formatSingleTime(startTime);
      final end = _formatSingleTime(endTime);
      return '$start – $end';
    } catch (_) {
      return '$startTime – $endTime';
    }
  }

  static String _formatSingleTime(String timeStr) {
    final clean = timeStr.trim();
    if (clean.toLowerCase().contains('am') || clean.toLowerCase().contains('pm')) {
      return clean;
    }
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final dt = DateTime(2026, 1, 1, hour, minute);
      return DateFormat('hh:mm a').format(dt);
    }
    return clean;
  }

  String get fullServiceDescription {
    final buffer = StringBuffer(serviceName);
    if (packageName != null && packageName!.isNotEmpty) {
      buffer.write(' ($packageName)');
    }
    if (addOns.isNotEmpty) {
      buffer.write(' + ${addOns.join(', ')}');
    }
    return buffer.toString();
  }

  static String? _normalizeImageUrl(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'undefined') return null;
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return str;
    }
    if (str.startsWith('assets/')) {
      return str;
    }
    final base = Constants.app.BASE_URL;
    if (str.startsWith('/')) {
      return '$base$str';
    }
    return '$base/$str';
  }

  factory GroomerBooking.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['bookingId'] != null) {
      parsedId = int.tryParse(json['bookingId'].toString()) ?? 0;
    } else if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 0;
    }

    // Parse Pet
    String pName = 'Pet';
    String pBreed = '';
    String? pPic;
    int? pId = int.tryParse(json['petId']?.toString() ?? json['pet_id']?.toString() ?? '');
    if (json['pet'] is Map<String, dynamic>) {
      final petMap = json['pet'] as Map<String, dynamic>;
      pName = petMap['petName']?.toString() ?? petMap['name']?.toString() ?? 'Pet';
      pBreed = petMap['breed']?.toString() ?? petMap['petBreed']?.toString() ?? '';
      final rawPic = petMap['profilePictureUrl'] ??
          petMap['profilePicture'] ??
          petMap['petProfilePicture'] ??
          petMap['photoUrl'] ??
          petMap['petPhotoUrl'] ??
          petMap['pet_photo_url'] ??
          petMap['image'] ??
          petMap['avatar'];
      pPic = _normalizeImageUrl(rawPic);
      pId ??= int.tryParse(petMap['id']?.toString() ?? petMap['petId']?.toString() ?? '');
    } else {
      pName = json['petName']?.toString() ??
          json['pet_name']?.toString() ??
          'Pet';
      pBreed = json['breed']?.toString() ??
          json['petBreed']?.toString() ??
          json['pet_breed']?.toString() ??
          '';
      final rawPic = json['petProfilePicture'] ??
          json['profilePictureUrl'] ??
          json['profilePicture'] ??
          json['petPhotoUrl'] ??
          json['pet_photo_url'] ??
          json['photoUrl'] ??
          json['petImage'];
      pPic = _normalizeImageUrl(rawPic);
    }

    if (pPic == null || pPic.isEmpty) {
      final fallbackRaw = json['petProfilePicture'] ??
          json['profilePictureUrl'] ??
          json['profilePicture'] ??
          json['petPhotoUrl'] ??
          json['pet_photo_url'] ??
          json['photoUrl'] ??
          json['petImage'];
      pPic = _normalizeImageUrl(fallbackRaw);
    }

    // Parse User
    String cName = 'Customer';
    String cEmail = '';
    String cMobile = '';
    int? uId;
    if (json['user'] is Map<String, dynamic>) {
      final userMap = json['user'] as Map<String, dynamic>;
      cName = userMap['name']?.toString() ?? userMap['fullName']?.toString() ?? 'Customer';
      cEmail = userMap['email']?.toString() ?? '';
      cMobile = userMap['mobile']?.toString() ?? userMap['phone']?.toString() ?? '';
      uId = int.tryParse(userMap['id']?.toString() ?? '');
    } else {
      cName = json['customerName']?.toString() ??
          json['customer_name']?.toString() ??
          json['userName']?.toString() ??
          json['user_name']?.toString() ??
          'Customer';
      cEmail = json['customerEmail']?.toString() ??
          json['customer_email']?.toString() ??
          json['userEmail']?.toString() ??
          json['user_email']?.toString() ??
          '';
      cMobile = json['customerMobile']?.toString() ??
          json['customer_mobile']?.toString() ??
          json['userMobile']?.toString() ??
          json['phone']?.toString() ??
          '';
    }

    // Parse Service
    String sName = 'Service';
    int? sId;
    if (json['service'] is Map<String, dynamic>) {
      final serviceMap = json['service'] as Map<String, dynamic>;
      sName = serviceMap['name']?.toString() ?? 'Service';
      sId = int.tryParse(serviceMap['id']?.toString() ?? '');
    } else {
      sName = json['serviceName']?.toString() ?? 'Service';
      sId = int.tryParse(json['serviceId']?.toString() ?? '');
    }

    // Parse Package
    String? pkgName;
    int? pkgId;
    if (json['package'] is Map<String, dynamic>) {
      final pkgMap = json['package'] as Map<String, dynamic>;
      pkgName = pkgMap['name']?.toString();
      pkgId = int.tryParse(pkgMap['id']?.toString() ?? '');
    } else if (json['packageName'] != null) {
      pkgName = json['packageName'].toString();
      pkgId = int.tryParse(json['packageId']?.toString() ?? '');
    }

    // Parse Add-ons
    List<String> parsedAddOns = [];
    if (json['addOns'] is List) {
      parsedAddOns = (json['addOns'] as List).map((e) {
        if (e is Map<String, dynamic>) {
          return e['name']?.toString() ?? '';
        }
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }

    double price = 0.0;
    if (json['totalPrice'] != null) {
      price = double.tryParse(json['totalPrice'].toString()) ?? 0.0;
    } else if (json['totalAmount'] != null) {
      price = double.tryParse(json['totalAmount'].toString()) ?? 0.0;
    }

    // Parse Groomer
    int? gId;
    String? gName;
    String? gCode;
    if (json['groomer'] is Map<String, dynamic>) {
      final gMap = json['groomer'] as Map<String, dynamic>;
      gName = (gMap['name'] ?? '${gMap['firstName'] ?? ''} ${gMap['lastName'] ?? ''}').toString().trim();
      gId = int.tryParse(gMap['id']?.toString() ?? gMap['groomerId']?.toString() ?? '');
      gCode = (gMap['groomerCode'] ?? gMap['code'] ?? gMap['GroomerId'] ?? '').toString().trim();
    } else {
      gName = json['groomerName']?.toString() ??
          json['assignedGroomer']?.toString() ??
          (json['groomer'] is String ? json['groomer'] as String : null);
      gId = int.tryParse(json['groomerId']?.toString() ?? json['groomer_id']?.toString() ?? '');
      gCode = (json['groomerCode'] ?? json['groomer_code'] ?? '').toString().trim();
    }

    if (gId == null && (gCode.isNotEmpty || (gName != null && gName.isNotEmpty))) {
      gId = BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: gCode, groomerName: gName);
    }
    if ((gName == null || gName.isEmpty) && gId != null && gId > 0) {
      gName = BookingDateUtils.resolveGroomerNameById(gId);
    }

    return GroomerBooking(
      bookingId: parsedId,
      status: json['status']?.toString() ?? 'pending',
      bookingDate: json['bookingDate']?.toString() ?? json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '09:00 AM',
      endTime: json['endTime']?.toString() ?? '10:00 AM',
      petId: pId,
      petName: pName,
      breed: pBreed,
      profilePicture: pPic,
      userId: uId,
      customerName: cName,
      customerEmail: cEmail,
      customerMobile: cMobile,
      serviceId: sId,
      serviceName: sName,
      packageId: pkgId,
      packageName: pkgName,
      addOns: parsedAddOns,
      totalPrice: price,
      totalDurationMinutes: int.tryParse(json['totalDurationMinutes']?.toString() ?? '30') ?? 30,
      storeId: json['storeId']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      cancellationReason: json['cancellationReason']?.toString() ?? json['cancellation_reason']?.toString(),
      groomerId: gId,
      groomerName: (gName != null && gName.isNotEmpty) ? gName : null,
      groomerCode: gCode.isNotEmpty ? gCode : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'bookingId': bookingId,
    'status': status,
    'bookingDate': bookingDate,
    'startTime': startTime,
    'endTime': endTime,
    'petId': petId,
    'petName': petName,
    'breed': breed,
    'profilePicture': profilePicture,
    'userId': userId,
    'customerName': customerName,
    'customerEmail': customerEmail,
    'customerMobile': customerMobile,
    'serviceId': serviceId,
    'serviceName': serviceName,
    'packageId': packageId,
    'packageName': packageName,
    'addOns': addOns,
    'totalPrice': totalPrice,
    'totalDurationMinutes': totalDurationMinutes,
    'storeId': storeId,
    'createdAt': createdAt,
    'cancellationReason': cancellationReason,
    if (groomerId != null) 'groomerId': groomerId,
    if (groomerName != null) 'groomerName': groomerName,
    if (groomerCode != null) 'groomerCode': groomerCode,
  };

  GroomerBooking copyWith({
    int? bookingId,
    String? status,
    String? bookingDate,
    String? startTime,
    String? endTime,
    int? petId,
    String? petName,
    String? breed,
    String? profilePicture,
    int? userId,
    String? customerName,
    String? customerEmail,
    String? customerMobile,
    int? serviceId,
    String? serviceName,
    int? packageId,
    String? packageName,
    List<String>? addOns,
    double? totalPrice,
    int? totalDurationMinutes,
    String? storeId,
    String? createdAt,
    String? cancellationReason,
    int? groomerId,
    String? groomerName,
    String? groomerCode,
  }) {
    return GroomerBooking(
      bookingId: bookingId ?? this.bookingId,
      status: status ?? this.status,
      bookingDate: bookingDate ?? this.bookingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      breed: breed ?? this.breed,
      profilePicture: profilePicture ?? this.profilePicture,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerMobile: customerMobile ?? this.customerMobile,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      addOns: addOns ?? this.addOns,
      totalPrice: totalPrice ?? this.totalPrice,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      storeId: storeId ?? this.storeId,
      createdAt: createdAt ?? this.createdAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      groomerId: groomerId ?? this.groomerId,
      groomerName: groomerName ?? this.groomerName,
      groomerCode: groomerCode ?? this.groomerCode,
    );
  }
}
