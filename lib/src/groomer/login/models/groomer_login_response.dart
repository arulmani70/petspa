import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';

class GroomerLoginResponse {
  final String accessToken;
  final String refreshToken;
  final bool mustChangePassword;
  final GroomerUser groomer;
  final String? tempLoginId;
  final String? tempPassword;

  const GroomerLoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.mustChangePassword,
    required this.groomer,
    this.tempLoginId,
    this.tempPassword,
  });

  factory GroomerLoginResponse.fromJson(Map<String, dynamic> json) {
    final rawMustChange = json['mustChangePassword'];
    final mustChangeBool = rawMustChange is bool
        ? rawMustChange
        : (rawMustChange?.toString().toLowerCase() == 'true' || rawMustChange?.toString() == '1');

    final groomerMap = json['groomer'] is Map<String, dynamic>
        ? json['groomer'] as Map<String, dynamic>
        : (json['groomer'] is Map ? Map<String, dynamic>.from(json['groomer'] as Map) : <String, dynamic>{});

    return GroomerLoginResponse(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      mustChangePassword: mustChangeBool,
      groomer: GroomerUser.fromJson(groomerMap),
      tempLoginId: json['tempLoginId']?.toString() ?? groomerMap['tempLoginId']?.toString(),
      tempPassword: json['tempPassword']?.toString() ?? groomerMap['tempPassword']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'mustChangePassword': mustChangePassword,
    'groomer': groomer.toJson(),
    if (tempLoginId != null) 'tempLoginId': tempLoginId,
    if (tempPassword != null) 'tempPassword': tempPassword,
  };
}
