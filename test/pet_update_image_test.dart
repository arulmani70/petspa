import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';

class MockApiRepository extends ApiRepository {
  FormData? lastPutMultipartFormData;
  String? lastPutMultipartPath;
  FormData? lastPostMultipartFormData;
  String? lastPostMultipartPath;

  List<Map<String, dynamic>> mockPets = [];
  Map<int, Map<String, dynamic>> mockPetById = {};

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/pets') {
      return {
        'success': true,
        'data': {
          'pets': mockPets,
        },
      };
    }
    if (path.startsWith('/api/pets/')) {
      final id = int.tryParse(path.replaceFirst('/api/pets/', ''));
      if (id != null && mockPetById.containsKey(id)) {
        return mockPetById[id];
      }
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> postMultipart(String path, FormData data) async {
    lastPostMultipartPath = path;
    lastPostMultipartFormData = data;
    return {'success': true, 'data': {'id': 789}};
  }

  @override
  Future<bool> putMultipart(String path, FormData data) async {
    lastPutMultipartPath = path;
    lastPutMultipartFormData = data;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiRepository mockApi;
  late PetRepository petRepo;

  setUp(() async {
    mockApi = MockApiRepository();
    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ApiRepository>(mockApi);

    petRepo = PetRepository();
  });

  group('PetRepository Image Update Tests', () {
    test('updatePet attaches profilePicture file and sends multipart/form-data to PUT /api/pets/:id', () async {
      final petData = <String, dynamic>{
        Constants.database.COLUMN_PET_NAME: 'Max',
        Constants.database.COLUMN_BREED: 'Poodle',
        Constants.database.COLUMN_WEIGHT: '10kg',
        'age': '2 Years',
        'gender': 'male',
        Constants.database.COLUMN_NOTES: 'No allergies',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'true',
        'behaviorNotes': 'Friendly and calm',
      };

      final result = await petRepo.updatePet(123, petData);

      expect(result, equals(1));
      expect(mockApi.lastPutMultipartPath, equals('/api/pets/123'));
      expect(mockApi.lastPutMultipartFormData, isNotNull);
      
      final fields = Map.fromEntries(mockApi.lastPutMultipartFormData!.fields);
      expect(fields['petName'], equals('Max'));
      expect(fields['breed'], equals('Poodle'));

      final files = mockApi.lastPutMultipartFormData!.files;
      expect(files.any((f) => f.key == 'profilePicture'), isTrue);
    });

    test('createPet attaches profilePicture file and sends multipart/form-data to POST /api/pets', () async {
      final petData = <String, dynamic>{
        Constants.database.COLUMN_PET_NAME: 'Charlie',
        Constants.database.COLUMN_BREED: 'Beagle',
        Constants.database.COLUMN_WEIGHT: '15kg',
        'age': '3 Years',
        'gender': 'female',
        Constants.database.COLUMN_NOTES: 'None',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'true',
        'behaviorNotes': 'Playful',
      };

      final result = await petRepo.createPet(petData);

      expect(result, equals(789));
      expect(mockApi.lastPostMultipartPath, equals('/api/pets'));
      expect(mockApi.lastPostMultipartFormData, isNotNull);

      final files = mockApi.lastPostMultipartFormData!.files;
      expect(files.any((f) => f.key == 'profilePicture'), isTrue);
    });

    test('getAllPets extracts profilePictureUrl and assigns to photo_url and profilePicture', () async {
      mockApi.mockPets = [
        {
          'id': 1,
          'petName': 'Bella',
          'breed': 'Labrador',
          'weight': '22kg',
          'profilePictureUrl': 'https://example.com/uploads/bella.jpg',
          'age': '4 Years',
          'gender': 'female',
          'allVaccinatedCurrent': true,
        }
      ];

      final pets = await petRepo.getAllPets();
      expect(pets.length, equals(1));
      expect(pets.first[Constants.database.COLUMN_PHOTO_URL], equals('https://example.com/uploads/bella.jpg'));
      expect(pets.first['profilePictureUrl'], equals('https://example.com/uploads/bella.jpg'));
      expect(pets.first['profilePicture'], equals('https://example.com/uploads/bella.jpg'));
    });

    test('PetBloc UpdatePet updates pet and reloads pets list', () async {
      mockApi.mockPets = [
        {
          'id': 10,
          'petName': 'Rocky',
          'breed': 'Bulldog',
          'weight': '18kg',
          'profilePictureUrl': 'https://example.com/uploads/rocky.jpg',
          'age': '1 Year',
          'gender': 'male',
          'allVaccinatedCurrent': true,
        }
      ];

      final bloc = PetBloc(repository: petRepo);
      bloc.add(UpdatePet(
        petId: 10,
        pet: {
          Constants.database.COLUMN_PET_NAME: 'Rocky',
          Constants.database.COLUMN_BREED: 'Bulldog',
          Constants.database.COLUMN_WEIGHT: '19kg',
          Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
          'age': '1 Year',
          'gender': 'male',
          'allVaccinatedCurrent': 'true',
        },
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<PetState>((s) => s.status == PetStatus.loading),
          predicate<PetState>((s) =>
              s.status == PetStatus.success &&
              s.pets.isNotEmpty &&
              s.pets.first[Constants.database.COLUMN_PHOTO_URL] == 'https://example.com/uploads/rocky.jpg'),
        ]),
      );
    });

    test('getPetById extracts pet profile picture correctly from nested data.pet structure', () async {
      mockApi.mockPetById[55] = {
        'success': true,
        'data': {
          'pet': {
            'id': 55,
            'petName': 'Daisy',
            'breed': 'Shih Tzu',
            'weight': '6kg',
            'petProfilePicture': '/uploads/pets/daisy_profile.jpg',
            'age': '3 Years',
            'gender': 'female',
            'allVaccinatedCurrent': true,
          }
        }
      };

      final pet = await petRepo.getPetById(55);
      expect(pet, isNotNull);
      expect(pet!['name'], equals('Daisy'));
      expect(pet[Constants.database.COLUMN_PHOTO_URL], equals('/uploads/pets/daisy_profile.jpg'));
      expect(pet['profilePictureUrl'], equals('/uploads/pets/daisy_profile.jpg'));
      expect(pet['petProfilePicture'], equals('/uploads/pets/daisy_profile.jpg'));
    });

    test('updatePet with local file attaches MultipartFile without sending invalid HTTP GET', () async {
      final tempDir = Directory.systemTemp.createTempSync('pet_test_');
      final localFile = File('${tempDir.path}/test_pet_avatar.jpg');
      localFile.writeAsBytesSync([1, 2, 3, 4, 5]);

      try {
        final petData = <String, dynamic>{
          Constants.database.COLUMN_PET_NAME: 'Buddy',
          Constants.database.COLUMN_BREED: 'Golden Retriever',
          Constants.database.COLUMN_WEIGHT: '30kg',
          'age': '2 Years',
          'gender': 'male',
          Constants.database.COLUMN_PHOTO_URL: localFile.path,
        };

        final result = await petRepo.updatePet(99, petData);
        expect(result, equals(1));
        expect(mockApi.lastPutMultipartPath, equals('/api/pets/99'));
        expect(mockApi.lastPutMultipartFormData, isNotNull);

        final files = mockApi.lastPutMultipartFormData!.files;
        expect(files.any((f) => f.key == 'profilePicture'), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('updatePet preserves existing remote photo URL and does not overwrite with default asset', () async {
      final petData = <String, dynamic>{
        Constants.database.COLUMN_PET_NAME: 'Max',
        Constants.database.COLUMN_BREED: 'Poodle',
        Constants.database.COLUMN_WEIGHT: '12kg',
        'age': '3 Years',
        'gender': 'male',
        Constants.database.COLUMN_PHOTO_URL: 'https://example.com/uploads/max_existing.jpg',
      };

      final result = await petRepo.updatePet(101, petData);
      expect(result, equals(1));
      expect(mockApi.lastPutMultipartPath, equals('/api/pets/101'));
      expect(mockApi.lastPutMultipartFormData, isNotNull);

      final files = mockApi.lastPutMultipartFormData!.files;
      // When existing remote photo is unchanged, no new profilePicture binary file is attached
      expect(files.any((f) => f.key == 'profilePicture'), isFalse);
      // Photo URL is passed in fields so server knows the current picture
      final fields = Map.fromEntries(mockApi.lastPutMultipartFormData!.fields);
      expect(fields['profilePictureUrl'], equals('https://example.com/uploads/max_existing.jpg'));
    });
  });
}
