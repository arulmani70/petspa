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
  });
}
