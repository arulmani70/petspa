import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

class PetRepository {
  final Logger log = Logger();
  ApiRepository get _api => ServicesLocator.apiRepository;

  Future<void> initialize() async {
    try {
      log.d("PetRepository::initialize::Initializing pet repository");
    } catch (error) {
      log.e("PetRepository::initialize::Error: $error");
    }
  }

  // Maps backend API keys back to the Constants.database keys for UI compatibility
  Map<String, dynamic> _mapFromApi(Map<String, dynamic> apiData) {
    final pet = (apiData['data'] is Map ? (apiData['data']['pet'] ?? apiData['data']) : null) ??
        apiData['pet'] ??
        apiData;
    final Map<String, dynamic> map = pet is Map<String, dynamic>
        ? pet
        : Map<String, dynamic>.from(pet as Map);

    final photoUrl = map['profilePictureUrl'] ??
        map['profilePicture'] ??
        map['profile_picture'] ??
        map['profile_picture_url'] ??
        map['photo_url'] ??
        map['photoUrl'] ??
        map['image'] ??
        map['avatar'] ??
        map['petImage'] ??
        map['pet_image'];

    final id = map['id'] ?? map['_id'];
    final name = map['petName'] ?? map['name'];

    return {
      Constants.database.COLUMN_ID: id,
      'id': id,
      '_id': id,
      Constants.database.COLUMN_PET_NAME: name,
      'petName': name,
      'name': name,
      Constants.database.COLUMN_BREED: map['breed'],
      'breed': map['breed'],
      Constants.database.COLUMN_WEIGHT: map['weight'],
      'weight': map['weight'],
      Constants.database.COLUMN_NOTES: map['notesAllergies'] ?? map['notes'],
      'notesAllergies': map['notesAllergies'] ?? map['notes'],
      'notes': map['notesAllergies'] ?? map['notes'],
      Constants.database.COLUMN_BIRTH_DATE: map['dateOfBirth'] ?? map['birthDate'],
      'dateOfBirth': map['dateOfBirth'] ?? map['birthDate'],
      Constants.database.COLUMN_PHOTO_URL: photoUrl,
      'profilePictureUrl': photoUrl,
      'profilePicture': photoUrl,
      'profile_picture': photoUrl,
      'profile_picture_url': photoUrl,
      'photo_url': photoUrl,
      'photoUrl': photoUrl,
      'image': photoUrl,
      'avatar': photoUrl,
      'petImage': photoUrl,
      'pet_image': photoUrl,
      'age': map['age'],
      'gender': map['gender'],
      'allVaccinatedCurrent': map['allVaccinatedCurrent'],
      'lastVaccinatedDate': map['lastVaccinatedDate'],
      'behaviorNotes': map['behaviorNotes'],
    };
  }

  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async {
    try {
      log.d("PetRepository::getAllPets::Fetching all pets");

      final response = await _api.get('/api/pets');
      if (response == null) {
        log.w("PetRepository::getAllPets::Null response");
        return [];
      }
      
      dynamic petsList;
      if (response['data'] is List) {
        petsList = response['data'];
      } else if (response['data'] is Map) {
        petsList = response['data']['pets'] ?? response['data']['pet'];
      } else if (response['pets'] is List) {
        petsList = response['pets'];
      }
      
      if (petsList == null || petsList is! List) {
        log.w("PetRepository::getAllPets::No pets list found");
        return [];
      }

      log.d("PetRepository::getAllPets::Extracted ${petsList.length} pets from response");
      return petsList.map((e) => _mapFromApi(e as Map<String, dynamic>)).toList();
    } catch (error) {
      log.e("PetRepository::getAllPets::Error: $error");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPetById(int id) async {
    try {
      log.d("PetRepository::getPetById::Fetching pet: $id");
      final result = await _api.get('/api/pets/$id');
      if (result == null) return null;
      return _mapFromApi(result);
    } catch (error) {
      log.e("PetRepository::getPetById::Error: $error");
      rethrow;
    }
  }

  Future<MultipartFile?> _resolvePhotoMultipart(String? photoPath) async {
    if (photoPath == null || photoPath.trim().isEmpty || photoPath == 'null') {
      return null;
    }
    final trimmed = photoPath.trim();

    // 1. Network URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));
        final response = await dio.get<List<int>>(
          trimmed,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null && response.data!.isNotEmpty) {
          String fileName = trimmed.split('?').first.split('/').last;
          if (!fileName.contains('.')) fileName = '$fileName.jpg';
          return MultipartFile.fromBytes(response.data!, filename: fileName);
        }
      } catch (e) {
        log.w("PetRepository::_resolvePhotoMultipart::Failed to download network image: $e");
      }
    }

    // 2. Relative server upload URL (e.g. /uploads/pets/xyz.jpg)
    if (trimmed.startsWith('/uploads/') ||
        trimmed.startsWith('uploads/') ||
        trimmed.contains('/uploads/') ||
        trimmed.endsWith('.jpg') ||
        trimmed.endsWith('.jpeg') ||
        trimmed.endsWith('.png') ||
        trimmed.endsWith('.webp')) {
      try {
        final clean = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
        final fullUrl = clean.startsWith('http') ? clean : '${Constants.app.BASE_URL}/$clean';
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));
        final response = await dio.get<List<int>>(
          fullUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data != null && response.data!.isNotEmpty) {
          String fileName = clean.split('?').first.split('/').last;
          if (!fileName.contains('.')) fileName = '$fileName.jpg';
          return MultipartFile.fromBytes(response.data!, filename: fileName);
        }
      } catch (e) {
        log.w("PetRepository::_resolvePhotoMultipart::Failed to download relative image: $e");
      }
    }

    // 3. Local file
    if (!trimmed.startsWith('assets/')) {
      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          final fileName = trimmed.split(RegExp(r'[/\\]')).last;
          return await MultipartFile.fromFile(trimmed, filename: fileName);
        }
      } catch (e) {
        log.w("PetRepository::_resolvePhotoMultipart::Error reading local file: $e");
      }
    }

    // 4. Asset bundle fallback
    try {
      final assetPath = trimmed.startsWith('assets/') ? trimmed : 'assets/images/common/pet_1.png';
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      final fileName = assetPath.split('/').last;
      return MultipartFile.fromBytes(bytes, filename: fileName);
    } catch (e) {
      log.w("PetRepository::_resolvePhotoMultipart::Failed to load asset fallback: $e");
    }

    return null;
  }

  Future<int> createPet(Map<String, dynamic> petData) async {
    try {
      log.d("PetRepository::createPet::Creating pet via API");

      final map = <String, dynamic>{
        'petName': petData[Constants.database.COLUMN_PET_NAME]?.toString().trim() ?? '',
        'breed': petData[Constants.database.COLUMN_BREED]?.toString().trim() ?? '',
        'weight': petData[Constants.database.COLUMN_WEIGHT]?.toString().trim() ?? '',
        'age': petData['age']?.toString().trim() ?? '',
        'gender': petData['gender']?.toString().trim() ?? 'male',
        'notesAllergies': petData[Constants.database.COLUMN_NOTES]?.toString().trim() ?? '',
        'allVaccinatedCurrent': petData['allVaccinatedCurrent']?.toString().trim() ?? 'true',
        'behaviorNotes': petData['behaviorNotes']?.toString().trim() ?? '',
      };

      final birthDate = petData[Constants.database.COLUMN_BIRTH_DATE]?.toString().trim();
      if (birthDate != null && birthDate.isNotEmpty && birthDate != 'null') {
        map['dateOfBirth'] = birthDate;
      }

      final lastVacDate = petData['lastVaccinatedDate']?.toString().trim();
      if (lastVacDate != null && lastVacDate.isNotEmpty && lastVacDate != 'null') {
        map['lastVaccinatedDate'] = lastVacDate;
      }

      final photoPath = (petData[Constants.database.COLUMN_PHOTO_URL] ??
              petData['profilePicture'] ??
              petData['profilePictureUrl'] ??
              petData['photo_url'] ??
              petData['photoUrl'] ??
              petData['image'])
          ?.toString()
          .trim();

      final formData = FormData.fromMap(map);

      final photoFile = await _resolvePhotoMultipart(photoPath);
      if (photoFile != null) {
        formData.files.add(MapEntry('profilePicture', photoFile));
      }

      final response = await _api.postMultipart('/api/pets', formData);

      if (response == null || response['success'] == false) {
        throw Exception("Failed to create pet");
      }
      log.d("PetRepository::createPet::Created pet successfully");
      return response['id'] ?? response['_id'] ?? response['data']?['id'] ?? 1;
    } catch (error) {
      log.e("PetRepository::createPet::Error: $error");
      rethrow;
    }
  }

  Future<int> updatePet(int petId, Map<String, dynamic> petData) async {
    try {
      log.d("PetRepository::updatePet::Updating pet: $petId via API");

      final map = <String, dynamic>{
        'petName': petData[Constants.database.COLUMN_PET_NAME]?.toString().trim() ?? '',
        'breed': petData[Constants.database.COLUMN_BREED]?.toString().trim() ?? '',
        'weight': petData[Constants.database.COLUMN_WEIGHT]?.toString().trim() ?? '',
        'age': petData['age']?.toString().trim() ?? '',
        'gender': petData['gender']?.toString().trim() ?? 'male',
        'notesAllergies': petData[Constants.database.COLUMN_NOTES]?.toString().trim() ?? '',
        'allVaccinatedCurrent': petData['allVaccinatedCurrent']?.toString().trim() ?? 'true',
        'behaviorNotes': petData['behaviorNotes']?.toString().trim() ?? '',
      };

      final birthDate = petData[Constants.database.COLUMN_BIRTH_DATE]?.toString().trim();
      if (birthDate != null && birthDate.isNotEmpty && birthDate != 'null') {
        map['dateOfBirth'] = birthDate;
      }

      final lastVacDate = petData['lastVaccinatedDate']?.toString().trim();
      if (lastVacDate != null && lastVacDate.isNotEmpty && lastVacDate != 'null') {
        map['lastVaccinatedDate'] = lastVacDate;
      }

      final photoPath = (petData[Constants.database.COLUMN_PHOTO_URL] ??
              petData['profilePicture'] ??
              petData['profilePictureUrl'] ??
              petData['photo_url'] ??
              petData['photoUrl'] ??
              petData['image'])
          ?.toString()
          .trim();

      final formData = FormData.fromMap(map);

      final photoFile = await _resolvePhotoMultipart(photoPath);
      if (photoFile != null) {
        formData.files.add(MapEntry('profilePicture', photoFile));
      }

      final success = await _api.putMultipart('/api/pets/$petId', formData);

      if (!success) {
        throw Exception("Failed to update pet");
      }
      log.d("PetRepository::updatePet::Updated pet successfully");
      return 1;
    } catch (error) {
      log.e("PetRepository::updatePet::Error: $error");
      rethrow;
    }
  }

  Future<int> deletePet(int petId) async {
    try {
      log.d("PetRepository::deletePet::Deleting pet: $petId via API");
      final success = await _api.delete('/api/pets/$petId');
      if (!success) {
        throw Exception("Failed to delete pet");
      }
      log.d("PetRepository::deletePet::Deleted pet successfully");
      return 1;
    } catch (error) {
      log.e("PetRepository::deletePet::Error: $error");
      rethrow;
    }
  }
}
