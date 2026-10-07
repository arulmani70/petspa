import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Load the actual JSON directly from the file system to avoid needing a mocked asset bundle.
  Future<Map<String, List<Map<String, dynamic>>>> parseTestJson(String jsonString) async {
    final Map<String, dynamic> data = json.decode(jsonString);

    List<Map<String, dynamic>> breeds = [];
    if (data['Breeds'] != null) {
      for (var b in data['Breeds']) {
        final breedType = b['BreedType'] ?? 'Unknown Breed';
        final breedId = b['BreedTypeId'] ?? 'unknown';

        if (b['Grooming'] != null) {
          breeds.add({
            Constants.database.COLUMN_ID: 'breed_${breedId}_grooming',
            Constants.database.COLUMN_SERVICE_NAME: '$breedType - Grooming',
            Constants.database.COLUMN_DESCRIPTION: 'Full grooming service',
            'price': '\$${b['Grooming']['Price']}',
            'duration': '${b['Grooming']['TimeinMinutes']} min',
          });
        }
        if (b['Bathing'] != null) {
          breeds.add({
            Constants.database.COLUMN_ID: 'breed_${breedId}_bathing',
            Constants.database.COLUMN_SERVICE_NAME: '$breedType - Bathing',
            Constants.database.COLUMN_DESCRIPTION: 'Refreshing bath service',
            'price': '\$${b['Bathing']['Price']}',
            'duration': '${b['Bathing']['TimeinMinutes']} min',
          });
        }
        if (b['GroomingAndBathing'] != null) {
          breeds.add({
            Constants.database.COLUMN_ID: 'breed_${breedId}_grooming_bathing',
            Constants.database.COLUMN_SERVICE_NAME: '$breedType - Grooming & Bathing',
            Constants.database.COLUMN_DESCRIPTION: 'Complete grooming and bathing package',
            'price': '\$${b['GroomingAndBathing']['Price']}',
            'duration': '${b['GroomingAndBathing']['TimeinMinutes']} min',
          });
        }
      }
    }

    List<Map<String, dynamic>> packages = [];
    if (data['Packages'] != null && data['Packages'] is List) {
      for (var p in data['Packages']) {
        if (p is Map) {
          final packageId = p['PackageId'] ?? p['PackageName'] ?? 'unknown_pkg_${packages.length}';
          var packageName = p['PackageName']?.toString() ?? '';
          if (packageName.isEmpty) packageName = 'Custom Package';

          String description = 'Standard package';
          if (p['Includes'] != null && p['Includes'] is List) {
            final includes = (p['Includes'] as List)
                .where((e) => e != null && e.toString().trim().isNotEmpty)
                .map((e) => e.toString().trim())
                .toList();
            if (includes.isNotEmpty) description = includes.join(', ');
          }

          final price = p['Price']?.toString() ?? '';
          final timeInMinutes = p['TimeinMinutes']?.toString() ?? '';
          final duration = timeInMinutes.isNotEmpty ? '$timeInMinutes min' : '';

          packages.add({
            Constants.database.COLUMN_ID: packageId,
            Constants.database.COLUMN_SERVICE_NAME: packageName,
            Constants.database.COLUMN_DESCRIPTION: description,
            'price': price,
            'duration': duration,
          });
        }
      }
    }

    List<Map<String, dynamic>> addons = [];
    if (data['AddOns'] != null && data['AddOns'] is List) {
      for (var a in data['AddOns']) {
        if (a is Map) {
          final addonId = a['AddOnId'] ?? 'unknown_addon_${addons.length}';
          var name = a['Name']?.toString() ?? '';
          if (name.isEmpty) name = 'Add-on';

          String description = 'Add-on service';
          if (a['Includes'] != null && a['Includes'] is List) {
            final includes = (a['Includes'] as List)
                .where((e) => e != null && e.toString().trim().isNotEmpty)
                .map((e) => e.toString().trim())
                .toList();
            if (includes.isNotEmpty) description = includes.join(', ');
          }

          final basePrice = a['Price']?.toString() ?? '';
          final suffix = a['Sufix']?.toString() ?? '';
          final price = '$basePrice$suffix'.trim();

          final timeInMinutes = a['TimeinMinutes']?.toString() ?? '';
          final duration = (timeInMinutes.isNotEmpty && timeInMinutes.toLowerCase() != 'not applicable')
              ? '$timeInMinutes min'
              : '';

          addons.add({
            Constants.database.COLUMN_ID: addonId,
            Constants.database.COLUMN_SERVICE_NAME: name,
            Constants.database.COLUMN_DESCRIPTION: description,
            'price': price,
            'duration': duration,
          });
        }
      }
    }

    return {
      'breeds': breeds,
      'packages': packages,
      'addons': addons,
    };
  }

  group('Service Data Mapping Tests', () {
    late String jsonContent;

    setUpAll(() {
      final file = File('assets/data/services.json');
      jsonContent = file.readAsStringSync();
    });

    test('Breeds are mapped correctly to 3 services each', () async {
      final result = await parseTestJson(jsonContent);
      final breeds = result['breeds']!;
      
      expect(breeds.isNotEmpty, true);
      // Small Breeds should have Grooming, Bathing, Grooming & Bathing
      expect(breeds[0][Constants.database.COLUMN_SERVICE_NAME], 'Small Breeds - Grooming');
      expect(breeds[0]['price'], '\$45');
      expect(breeds[0]['duration'], '60 min');
      
      expect(breeds[1][Constants.database.COLUMN_SERVICE_NAME], 'Small Breeds - Bathing');
      expect(breeds[1]['price'], '\$75');
      expect(breeds[1]['duration'], '30 min');
      
      expect(breeds[2][Constants.database.COLUMN_SERVICE_NAME], 'Small Breeds - Grooming & Bathing');
      expect(breeds[2]['price'], '\$110');
      expect(breeds[2]['duration'], '75 min');
    });

    test('Packages are mapped with robust fallback for empty names', () async {
      final result = await parseTestJson(jsonContent);
      final packages = result['packages']!;
      
      expect(packages.isNotEmpty, true);
      // First package has empty Name in the original JSON
      expect(packages[0][Constants.database.COLUMN_SERVICE_NAME], 'Custom Package');
      expect(packages[0]['price'], '\$24.00');
      expect(packages[0]['duration'], '60 min');
      expect(packages[0][Constants.database.COLUMN_DESCRIPTION], 'Standard package');
    });

    test('Add-ons correctly handle Includes arrays and suffixes', () async {
      final result = await parseTestJson(jsonContent);
      final addons = result['addons']!;
      
      expect(addons.isNotEmpty, true);
      
      // "Nail Grinding"
      expect(addons[0][Constants.database.COLUMN_SERVICE_NAME], 'Nail Grinding');
      expect(addons[0]['price'], '\$18.00 & up');
      
      // "Dental Package" - includes "Teeth Brushing Dental Spray & Treat"
      final dental = addons.firstWhere((a) => a[Constants.database.COLUMN_ID] == 'A0006');
      expect(dental[Constants.database.COLUMN_DESCRIPTION], 'Teeth Brushing Dental Spray & Treat');
      
      // "Brush/Dematt" - Duration should be hidden if "Not Applicable"
      final brush = addons.firstWhere((a) => a[Constants.database.COLUMN_ID] == 'A0009');
      expect(brush['price'], '\$10.00Per 15 minutes');
      expect(brush['duration'], ''); // Because 'Not Applicable' is stripped out
    });
  });
}
