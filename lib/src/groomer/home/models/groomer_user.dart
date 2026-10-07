class GroomerUser {
  final int id;
  final String groomerCode;
  final String firstName;
  final String lastName;
  final String email;
  final String mobile;
  final String role;
  final String highlights;
  final String type;
  final bool isActive;
  final bool multiBookingEnabled;
  final int slotBookingLimit;
  final bool mustChangePassword;
  final String clientId;
  final String regionId;
  final String storeId;
  final String? avatar;
  final String? profilePicture;

  const GroomerUser({
    required this.id,
    required this.groomerCode,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.mobile = '',
    this.role = 'Groomer',
    this.highlights = '',
    this.type = 'Groomer',
    this.isActive = true,
    this.multiBookingEnabled = false,
    this.slotBookingLimit = 1,
    this.mustChangePassword = false,
    this.clientId = '',
    this.regionId = '',
    this.storeId = '',
    this.avatar,
    this.profilePicture,
  });

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isNotEmpty ? combined : groomerCode;
  }

  factory GroomerUser.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 0;
    }

    final rawMultiBooking = json['multiBookingEnabled'];
    final multiBookingBool = rawMultiBooking is bool
        ? rawMultiBooking
        : (rawMultiBooking?.toString().toLowerCase() == 'true' || rawMultiBooking?.toString() == '1');

    final rawMustChange = json['mustChangePassword'];
    final mustChangeBool = rawMustChange is bool
        ? rawMustChange
        : (rawMustChange?.toString().toLowerCase() == 'true' || rawMustChange?.toString() == '1');

    final rawIsActive = json['isActive'];
    final isActiveBool = rawIsActive is bool
        ? rawIsActive
        : (rawIsActive?.toString().toLowerCase() == 'true' || rawIsActive?.toString() == '1' || rawIsActive == null);

    final avatarUrl = json['avatar']?.toString() ??
        json['profilePicture']?.toString() ??
        json['avatarUrl']?.toString() ??
        json['profilePictureUrl']?.toString();

    return GroomerUser(
      id: parsedId,
      groomerCode: json['groomerCode']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Groomer',
      highlights: json['highlights']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Groomer',
      isActive: isActiveBool,
      multiBookingEnabled: multiBookingBool,
      slotBookingLimit: int.tryParse(json['slotBookingLimit']?.toString() ?? '1') ?? 1,
      mustChangePassword: mustChangeBool,
      clientId: json['clientId']?.toString() ?? '',
      regionId: json['regionId']?.toString() ?? '',
      storeId: json['storeId']?.toString() ?? '',
      avatar: avatarUrl,
      profilePicture: avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'groomerCode': groomerCode,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'mobile': mobile,
    'role': role,
    'highlights': highlights,
    'type': type,
    'isActive': isActive,
    'multiBookingEnabled': multiBookingEnabled,
    'slotBookingLimit': slotBookingLimit,
    'mustChangePassword': mustChangePassword,
    'clientId': clientId,
    'regionId': regionId,
    'storeId': storeId,
    if (avatar != null) 'avatar': avatar,
    if (profilePicture != null) 'profilePicture': profilePicture,
  };
}
