class StoreContactInfo {
  final String storeName;
  final String address;
  final String phone;
  final String email;
  final String operatingHours;
  final String? website;

  const StoreContactInfo({
    required this.storeName,
    required this.address,
    required this.phone,
    required this.email,
    this.operatingHours = 'Mon - Sat: 9:00 AM - 6:00 PM',
    this.website,
  });

  factory StoreContactInfo.fromJson(Map<String, dynamic> json) {
    return StoreContactInfo(
      storeName: json['storeName']?.toString() ??
          json['name']?.toString() ??
          'Shear Heaven Pet Spa',
      address: json['address']?.toString() ??
          json['storeAddress']?.toString() ??
          '2218 S. Bowen, Arlington, TX 76013',
      phone: json['phone']?.toString() ??
          json['phoneNumber']?.toString() ??
          json['mobile']?.toString() ??
          '(817) 277-8433',
      email: json['email']?.toString() ??
          json['storeEmail']?.toString() ??
          'shearheaven.dwg@gmail.com',
      operatingHours: json['operatingHours']?.toString() ??
          json['hours']?.toString() ??
          json['serviceHours']?.toString() ??
          'Mon - Sat: 9:00 AM - 6:00 PM',
      website: json['website']?.toString(),
    );
  }

  factory StoreContactInfo.defaultInfo() {
    return const StoreContactInfo(
      storeName: 'Shear Heaven Pet Spa',
      address: '2218 S. Bowen, Arlington, TX 76013',
      phone: '(817) 277-8433',
      email: 'shearheaven.dwg@gmail.com',
      operatingHours: 'Mon - Sat: 9:00 AM - 6:00 PM',
      website: 'https://shearheaven.com',
    );
  }

  Map<String, dynamic> toJson() => {
    'storeName': storeName,
    'address': address,
    'phone': phone,
    'email': email,
    'operatingHours': operatingHours,
    if (website != null) 'website': website,
  };
}
