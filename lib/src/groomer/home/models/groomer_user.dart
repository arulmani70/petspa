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
  final String? tempLoginId;

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
    this.tempLoginId,
  });

  bool get isProfileCompleted =>
      !mustChangePassword &&
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      email.trim().isNotEmpty;

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isNotEmpty ? combined : groomerCode;
  }

  String? get avatarUrl {
    if (avatar != null && avatar!.trim().isNotEmpty) {
      return avatar!.trim();
    }
    if (profilePicture != null && profilePicture!.trim().isNotEmpty) {
      return profilePicture!.trim();
    }
    return null;
  }

  GroomerUser copyWith({
    int? id,
    String? groomerCode,
    String? firstName,
    String? lastName,
    String? email,
    String? mobile,
    String? role,
    String? highlights,
    String? type,
    bool? isActive,
    bool? multiBookingEnabled,
    int? slotBookingLimit,
    bool? mustChangePassword,
    String? clientId,
    String? regionId,
    String? storeId,
    String? avatar,
    String? profilePicture,
    String? tempLoginId,
  }) {
    return GroomerUser(
      id: id ?? this.id,
      groomerCode: groomerCode ?? this.groomerCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      highlights: highlights ?? this.highlights,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      multiBookingEnabled: multiBookingEnabled ?? this.multiBookingEnabled,
      slotBookingLimit: slotBookingLimit ?? this.slotBookingLimit,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      clientId: clientId ?? this.clientId,
      regionId: regionId ?? this.regionId,
      storeId: storeId ?? this.storeId,
      avatar: avatar ?? this.avatar,
      profilePicture: profilePicture ?? this.profilePicture,
      tempLoginId: tempLoginId ?? this.tempLoginId,
    );
  }

  factory GroomerUser.fromJson(Map<String, dynamic> rawJson) {
    final Map<String, dynamic> json = rawJson['groomer'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(rawJson['groomer'] as Map)
        : (rawJson['user'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawJson['user'] as Map)
            : rawJson);

    int parsedId = 0;
    final rawId = json['id'] ?? json['Id'] ?? json['groomerId'] ?? json['GroomerId'];
    if (rawId != null) {
      parsedId = int.tryParse(rawId.toString()) ?? 0;
    }

    final rawMultiBooking = json['multiBookingEnabled'] ?? json['MultiBookingEnabled'];
    final multiBookingBool = rawMultiBooking is bool
        ? rawMultiBooking
        : (rawMultiBooking?.toString().toLowerCase() == 'true' || rawMultiBooking?.toString() == '1');

    final rawMustChange = json['mustChangePassword'] ?? json['MustChangePassword'];
    final mustChangeBool = rawMustChange is bool
        ? rawMustChange
        : (rawMustChange?.toString().toLowerCase() == 'true' || rawMustChange?.toString() == '1');

    final rawIsActive = json['isActive'] ?? json['IsActive'];
    final isActiveBool = rawIsActive is bool
        ? rawIsActive
        : (rawIsActive?.toString().toLowerCase() == 'true' || rawIsActive?.toString() == '1' || rawIsActive == null);

    final rawAvatar = json['avatar']?.toString() ??
        json['Avatar']?.toString() ??
        json['profilePicture']?.toString() ??
        json['ProfilePicture']?.toString() ??
        json['avatarUrl']?.toString() ??
        json['profilePictureUrl']?.toString();
    final resolvedAvatar = (rawAvatar != null && rawAvatar.trim().isNotEmpty)
        ? rawAvatar.trim()
        : null;

    final rawSlotLimit = json['slotBookingLimit'] ?? json['SlotBookingLimit'];
    final parsedSlotLimit = int.tryParse(rawSlotLimit?.toString() ?? '1') ?? 1;

    final rawTempLoginId = json['tempLoginId']?.toString() ??
        json['TempLoginId']?.toString() ??
        rawJson['tempLoginId']?.toString();

    return GroomerUser(
      id: parsedId,
      groomerCode: (json['groomerCode'] ?? json['GroomerCode'] ?? json['code'] ?? '').toString(),
      firstName: (json['firstName'] ?? json['FirstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? json['LastName'] ?? '').toString(),
      email: (json['email'] ?? json['Email'] ?? '').toString(),
      mobile: (json['mobile'] ?? json['Mobile'] ?? json['phone'] ?? json['Phone'] ?? '').toString(),
      role: (json['role'] ?? json['Role'] ?? 'Groomer').toString(),
      highlights: (json['highlights'] ?? json['Highlights'] ?? json['bio'] ?? '').toString(),
      type: (json['type'] ?? json['Type'] ?? 'Groomer').toString(),
      isActive: isActiveBool,
      multiBookingEnabled: multiBookingBool,
      slotBookingLimit: parsedSlotLimit > 0 ? parsedSlotLimit : 1,
      mustChangePassword: mustChangeBool,
      clientId: (json['clientId'] ?? json['ClientId'] ?? json['ClientID'] ?? '').toString(),
      regionId: (json['regionId'] ?? json['RegionId'] ?? '').toString(),
      storeId: (json['storeId'] ?? json['StoreId'] ?? '').toString(),
      avatar: resolvedAvatar,
      profilePicture: resolvedAvatar,
      tempLoginId: (rawTempLoginId != null && rawTempLoginId.trim().isNotEmpty) ? rawTempLoginId.trim() : null,
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
    if (tempLoginId != null) 'tempLoginId': tempLoginId,
  };
}
