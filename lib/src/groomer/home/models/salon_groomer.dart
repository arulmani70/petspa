import 'package:equatable/equatable.dart';

/// Represents a salon groomer / bather returned dynamically by GET /api/groomer-auth/groomers or /api/groomers
class SalonGroomer extends Equatable {
  final int id;
  final String groomerCode;
  final String firstName;
  final String lastName;
  final String name;
  final String role;
  final String? profilePicture;
  final String? highlights;
  final bool isAvailable;
  final bool isSelf;
  final String? reason;

  const SalonGroomer({
    required this.id,
    required this.groomerCode,
    required this.firstName,
    required this.lastName,
    required this.name,
    this.role = 'Groomer',
    this.profilePicture,
    this.highlights,
    this.isAvailable = true,
    this.isSelf = false,
    this.reason,
  });

  factory SalonGroomer.fromJson(Map<String, dynamic> json) {
    // 1. Parse groomer code / ID
    final rawCode = (json['groomerCode'] ??
            json['GroomerCode'] ??
            json['GroomerId'] ??
            json['BatherId'] ??
            '')
        .toString()
        .trim();

    // 2. Parse numeric catalog ID (groomerId takes priority as it is the catalog ID 1-4)
    int parsedId = 0;
    if (json['groomerId'] is int && (json['groomerId'] as int) > 0) {
      parsedId = json['groomerId'] as int;
    } else if (json['groomerId'] != null) {
      parsedId = int.tryParse(json['groomerId'].toString()) ?? 0;
    }

    if (parsedId == 0 && rawCode.isNotEmpty) {
      if (rawCode.toUpperCase().startsWith('B')) {
        final digits = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
        final bNum = int.tryParse(digits) ?? 1;
        parsedId = bNum + 3; // B001 -> 4
      } else {
        final digits = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
        parsedId = int.tryParse(digits) ?? 0;
      }
    }

    if (parsedId == 0 && json['id'] != null) {
      final dbId = int.tryParse(json['id'].toString()) ?? 0;
      parsedId = (dbId >= 1 && dbId <= 4) ? dbId : (dbId > 0 ? dbId : 1);
    }

    // 3. Parse names
    final fName = (json['FirstName'] ?? json['firstName'] ?? '').toString().trim();
    final lName = (json['LastName'] ?? json['lastName'] ?? '').toString().trim();
    String fullName = (json['name'] ?? '$fName $lName').toString().trim();
    if (fullName.isEmpty) {
      fullName = rawCode.isNotEmpty ? 'Groomer $rawCode' : (parsedId > 0 ? 'Groomer #$parsedId' : 'Groomer');
    }

    // 4. Parse role & profile picture & availability & isSelf
    final parsedRole = (json['Role'] ?? json['role'] ?? 'Groomer').toString().trim();
    final pic = (json['ProfilePicture'] ??
            json['profilePicture'] ??
            json['image'] ??
            json['avatar'])
        ?.toString()
        .trim();
    final hlights = (json['Highlights'] ?? json['highlights'])?.toString().trim();
    final isAvail = json['available'] == null && json['isAvailable'] == null
        ? true
        : (json['available'] == true || json['isAvailable'] == true);
    final isSelfGroomer = json['isSelf'] == true;
    final reasonText = json['reason']?.toString();

    return SalonGroomer(
      id: parsedId,
      groomerCode: rawCode.isNotEmpty
          ? rawCode
          : (parsedId > 0 ? 'G00$parsedId' : ''),
      firstName: fName,
      lastName: lName,
      name: fullName,
      role: parsedRole.isNotEmpty ? parsedRole : 'Groomer',
      profilePicture: (pic != null && pic.isNotEmpty) ? pic : null,
      highlights: (hlights != null && hlights.isNotEmpty) ? hlights : null,
      isAvailable: isAvail,
      isSelf: isSelfGroomer,
      reason: (reasonText != null && reasonText.isNotEmpty) ? reasonText : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groomerId': id,
      'GroomerId': groomerCode,
      'groomerCode': groomerCode,
      'FirstName': firstName,
      'firstName': firstName,
      'LastName': lastName,
      'lastName': lastName,
      'name': name,
      'Role': role,
      'role': role,
      'ProfilePicture': profilePicture,
      'profilePicture': profilePicture,
      'Highlights': highlights,
      'available': isAvailable,
      'isAvailable': isAvailable,
      'isSelf': isSelf,
      'reason': reason,
    };
  }

  @override
  List<Object?> get props => [
        id,
        groomerCode,
        firstName,
        lastName,
        name,
        role,
        profilePicture,
        highlights,
        isAvailable,
        isSelf,
        reason,
      ];
}
