class CustomerSummary {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? profilePictureUrl;
  final List<CustomerPetSummary> pets;

  const CustomerSummary({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.profilePictureUrl,
    this.pets = const [],
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] ?? json['userId'] ?? json['_id'] ?? 0;
    final id = idVal is int ? idVal : int.tryParse(idVal.toString()) ?? 0;

    final name = json['name']?.toString() ??
        '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim();

    final phone = json['mobile']?.toString() ??
        json['phone']?.toString() ??
        json['phoneNumber']?.toString();

    final email = json['email']?.toString();
    final profilePicture = json['profilePictureUrl']?.toString() ??
        json['profilePicture']?.toString() ??
        json['photoUrl']?.toString();

    List<CustomerPetSummary> petsList = [];
    if (json['pets'] != null && json['pets'] is List) {
      petsList = (json['pets'] as List)
          .whereType<Map<String, dynamic>>()
          .map((p) => CustomerPetSummary.fromJson(p))
          .toList();
    }

    return CustomerSummary(
      id: id,
      name: name.isNotEmpty ? name : 'Customer #$id',
      email: email,
      phone: phone,
      profilePictureUrl: profilePicture,
      pets: petsList,
    );
  }

  CustomerSummary copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? profilePictureUrl,
    List<CustomerPetSummary>? pets,
  }) {
    return CustomerSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      pets: pets ?? this.pets,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': id,
      'name': name,
      'email': email,
      'phone': phone,
      'mobile': phone,
      'profilePictureUrl': profilePictureUrl,
      'pets': pets.map((p) => p.toJson()).toList(),
    };
  }
}

class CustomerPetSummary {
  final int id;
  final int userId;
  final String name;
  final String breed;
  final String? weight;
  final String? age;
  final String? gender;
  final String? notes;
  final String? profilePictureUrl;

  const CustomerPetSummary({
    required this.id,
    required this.userId,
    required this.name,
    required this.breed,
    this.weight,
    this.age,
    this.gender,
    this.notes,
    this.profilePictureUrl,
  });

  factory CustomerPetSummary.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] ?? json['petId'] ?? json['pet_id'] ?? json['_id'] ?? 0;
    final id = idVal is int ? idVal : int.tryParse(idVal.toString()) ?? 0;

    final userIdVal = json['userId'] ?? json['user_id'] ?? json['customerId'] ?? json['customer_id'] ?? 0;
    final userId = userIdVal is int ? userIdVal : int.tryParse(userIdVal.toString()) ?? 0;

    // Robust name resolution across all backend key conventions
    String resolvedName = '';
    for (final key in [
      'name',
      'petName',
      'pet_name',
      'pet',
      'dogName',
      'dog_name',
      'catName',
      'cat_name',
      'title',
    ]) {
      final v = json[key]?.toString().trim();
      if (v != null && v.isNotEmpty && v.toLowerCase() != 'null') {
        resolvedName = v;
        break;
      }
    }
    if (resolvedName.isEmpty) {
      resolvedName = id > 0 ? 'Pet #$id' : 'Pet';
    }

    // Robust breed resolution
    String resolvedBreed = '';
    for (final key in [
      'breed',
      'petBreed',
      'pet_breed',
      'breedName',
      'breed_name',
      'species',
      'type',
    ]) {
      final v = json[key]?.toString().trim();
      if (v != null && v.isNotEmpty && v.toLowerCase() != 'null') {
        resolvedBreed = v;
        break;
      }
    }
    if (resolvedBreed.isEmpty) {
      resolvedBreed = 'Mixed Breed';
    }

    final weight = json['weight']?.toString();
    final age = json['age']?.toString();
    final gender = json['gender']?.toString();
    final notes = json['notesAllergies']?.toString() ??
        json['notes_allergies']?.toString() ??
        json['notes']?.toString();
    final profilePicture = json['profilePictureUrl']?.toString() ??
        json['profile_picture_url']?.toString() ??
        json['profilePicture']?.toString() ??
        json['profile_picture']?.toString() ??
        json['photoUrl']?.toString() ??
        json['photo_url']?.toString();

    return CustomerPetSummary(
      id: id,
      userId: userId,
      name: resolvedName,
      breed: resolvedBreed,
      weight: weight,
      age: age,
      gender: gender,
      notes: notes,
      profilePictureUrl: profilePicture,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': id,
      'userId': userId,
      'name': name,
      'petName': name,
      'breed': breed,
      'weight': weight,
      'age': age,
      'gender': gender,
      'notesAllergies': notes,
      'profilePictureUrl': profilePictureUrl,
    };
  }
}
