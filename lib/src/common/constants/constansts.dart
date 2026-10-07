import 'app_constants.dart';
import 'database_constants.dart';

class Constants {
  static const app = AppConstants();

  static const database = DatabaseConstants();

  static const List<String> petBreeds = [
    'Golden Retriever',
    'Labrador Retriever',
    'German Shepherd',
    'French Bulldog',
    'Beagle',
    'Poodle',
    'Pomeranian',
    'Shih Tzu',
    'Corgi',
    'Pug',
    'Mixed Breed',
    'Other',
  ];

  static const List<String> coatTypes = ['Short', 'Medium', 'Long', 'Curly', 'Hairless'];

  static const List<String> serviceTags = ['MOST_BOOKED', 'POPULAR', 'NEW'];
}
