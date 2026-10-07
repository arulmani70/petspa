import 'dart:io';
import 'package:dio/dio.dart';
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
    return {
      Constants.database.COLUMN_ID: apiData['id'] ?? apiData['_id'],
      Constants.database.COLUMN_PET_NAME: apiData['petName'],
      Constants.database.COLUMN_BREED: apiData['breed'],
      Constants.database.COLUMN_WEIGHT: apiData['weight'],
      Constants.database.COLUMN_NOTES: apiData['notesAllergies'],
      Constants.database.COLUMN_BIRTH_DATE: apiData['dateOfBirth'],
      Constants.database.COLUMN_PHOTO_URL: apiData['profilePictureUrl'] ?? apiData['profilePicture'],
      'age': apiData['age'],
      'gender': apiData['gender'],
      'allVaccinatedCurrent': apiData['allVaccinatedCurrent'],
      'lastVaccinatedDate': apiData['lastVaccinatedDate'],
      'behaviorNotes': apiData['behaviorNotes'],
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
      
      final dataObj = response['data'];
      if (dataObj == null || dataObj is! Map) {
        log.w("PetRepository::getAllPets::No data object found");
        return [];
      }
      
      final petsList = dataObj['pets'];
      if (petsList == null || petsList is! List) {
        log.w("PetRepository::getAllPets::No pets list found");
        return [];
      }

      log.d("PetRepository::getAllPets::Extracted ${petsList.length} pets from response.data.pets");
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

      final formData = FormData.fromMap(map);
      bool hasNewFile = false;

      final photoPath = petData[Constants.database.COLUMN_PHOTO_URL] as String?;
      if (photoPath != null && photoPath.isNotEmpty) {
        if (!photoPath.startsWith('http') && !photoPath.startsWith('assets/')) {
          try {
            final file = File(photoPath);
            if (file.existsSync()) {
              hasNewFile = true;
              final fileName = photoPath.split(RegExp(r'[/\\]')).last;
              formData.files.add(
                MapEntry(
                  'profilePicture',
                  await MultipartFile.fromFile(photoPath, filename: fileName),
                ),
              );
            }
          } catch (e) {
            log.w("PetRepository::createPet::Error attaching photo file: $e");
          }
        }
      }

      Map<String, dynamic>? response;
      if (hasNewFile) {
        response = await _api.postMultipart('/api/pets', formData);
      } else {
        response = await _api.post('/api/pets', map);
        if (response == null || response['success'] == false) {
          response = await _api.postMultipart('/api/pets', formData);
        }
      }

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

      final formData = FormData.fromMap(map);
      bool hasNewFile = false;

      final photoPath = petData[Constants.database.COLUMN_PHOTO_URL] as String?;
      if (photoPath != null && photoPath.isNotEmpty) {
        if (!photoPath.startsWith('http') && !photoPath.startsWith('assets/')) {
          try {
            final file = File(photoPath);
            if (file.existsSync()) {
              hasNewFile = true;
              final fileName = photoPath.split(RegExp(r'[/\\]')).last;
              formData.files.add(
                MapEntry(
                  'profilePicture',
                  await MultipartFile.fromFile(photoPath, filename: fileName),
                ),
              );
            }
          } catch (e) {
            log.w("PetRepository::updatePet::Error attaching photo file: $e");
          }
        }
      }

      bool success = false;
      if (hasNewFile) {
        success = await _api.putMultipart('/api/pets/$petId', formData);
      } else {
        // Try standard JSON PUT first when no new file is uploaded
        final putResp = await _api.putData('/api/pets/$petId', map);
        if (putResp != null && putResp['success'] != false) {
          success = true;
        } else {
          success = await _api.putMultipart('/api/pets/$petId', formData);
        }
      }

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
