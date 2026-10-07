import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/account/models/content_model.dart';
import 'package:shear_heaven_pet_spa/src/account/models/store_contact_info_model.dart';
import 'package:shear_heaven_pet_spa/src/account/repos/content_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class _MockApiRepository extends ApiRepository {
  final Map<String, dynamic> responses = {};

  @override
  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (responses.containsKey(path)) {
      return responses[path];
    }
    return null;
  }
}

void main() {
  late ContentRepository contentRepo;
  late _MockApiRepository mockApi;

  setUpAll(() {
    mockApi = _MockApiRepository();
    if (GetIt.I.isRegistered<ApiRepository>()) {
      GetIt.I.unregister<ApiRepository>();
    }
    GetIt.I.registerSingleton<ApiRepository>(mockApi);
  });

  setUp(() {
    contentRepo = ContentRepository();
    mockApi.responses.clear();
  });

  group('StoreContactInfo Model', () {
    test('parses from standard JSON response', () {
      final json = {
        'storeName': 'Shear Heaven Arlington',
        'address': '123 Pet St, Arlington, TX',
        'phone': '(817) 555-0199',
        'email': 'arlington@shearheaven.com',
        'operatingHours': 'Mon - Sat: 8:00 AM - 7:00 PM',
        'website': 'https://shearheaven.com',
      };

      final info = StoreContactInfo.fromJson(json);
      expect(info.storeName, 'Shear Heaven Arlington');
      expect(info.address, '123 Pet St, Arlington, TX');
      expect(info.phone, '(817) 555-0199');
      expect(info.email, 'arlington@shearheaven.com');
      expect(info.operatingHours, 'Mon - Sat: 8:00 AM - 7:00 PM');
      expect(info.website, 'https://shearheaven.com');
    });

    test('parses fallback defaults when JSON is empty', () {
      final info = StoreContactInfo.fromJson({});
      expect(info.storeName, 'Shear Heaven Pet Spa');
      expect(info.address, '2218 S. Bowen, Arlington, TX 76013');
      expect(info.phone, '(817) 277-8433');
      expect(info.email, 'shearheaven.dwg@gmail.com');
      expect(info.operatingHours, 'Mon - Sat: 9:00 AM - 6:00 PM');
    });

    test('toJson serializes correctly', () {
      const info = StoreContactInfo(
        storeName: 'Test Store',
        address: '456 Bow St',
        phone: '123-456-7890',
        email: 'test@example.com',
        operatingHours: '9am - 5pm',
      );

      final map = info.toJson();
      expect(map['storeName'], 'Test Store');
      expect(map['address'], '456 Bow St');
      expect(map['phone'], '123-456-7890');
      expect(map['email'], 'test@example.com');
      expect(map['operatingHours'], '9am - 5pm');
    });
  });

  group('ContentModel Model', () {
    test('parses title and body correctly', () {
      final json = {
        'title': 'About Our Spa',
        'content':
            'We love pets.\n\nProviding 20+ years of grooming excellence.',
        'effectiveDate': '2026-01-01',
      };

      final model = ContentModel.fromJson(json);
      expect(model.title, 'About Our Spa');
      expect(model.paragraphs.length, 2);
      expect(model.paragraphs[0], 'We love pets.');
      expect(
        model.paragraphs[1],
        'Providing 20+ years of grooming excellence.',
      );
      expect(model.effectiveDate, '2026-01-01');
    });

    test('uses fallback defaults when json is empty', () {
      final model = ContentModel.fromJson(
        {},
        defaultTitle: 'Terms & Conditions',
        defaultContent: 'Standard terms applied.',
      );

      expect(model.title, 'Terms & Conditions');
      expect(model.content, 'Standard terms applied.');
      expect(model.paragraphs.length, 1);
      expect(model.paragraphs[0], 'Standard terms applied.');
    });
  });

  group('ContentRepository API Endpoints', () {
    test('getStoreContactInfo calls GET /api/store/contact-info', () async {
      mockApi.responses['/api/store/contact-info'] = {
        'success': true,
        'data': {
          'storeName': 'Shear Heaven Main Branch',
          'address': '2218 S. Bowen, Arlington, TX',
          'phone': '(669)-338-5227',
          'email': 'contact@shearheaven.com',
          'operatingHours': 'Mon - Sat: 9:00 AM - 6:00 PM',
        },
      };

      final result = await contentRepo.getStoreContactInfo();
      expect(result.storeName, 'Shear Heaven Main Branch');
      expect(result.phone, '(817) 277-8433');
      expect(result.email, 'contact@shearheaven.com');
    });

    test('getAboutUs calls GET /api/content/about-us', () async {
      mockApi.responses['/api/content/about-us'] = {
        'success': true,
        'data': {
          'title': 'About Us Dynamic',
          'content': 'Paragraph 1.\n\nParagraph 2.',
        },
      };

      final result = await contentRepo.getAboutUs();
      expect(result.title, 'About Us Dynamic');
      expect(result.paragraphs.length, 2);
    });

    test('getHelpSupport calls GET /api/content/help-support', () async {
      mockApi.responses['/api/content/help-support'] = {
        'success': true,
        'data': {
          'title': 'Help & Support FAQ',
          'content': 'FAQ 1: How to book?\n\nFAQ 2: Cancellation policy?',
        },
      };

      final result = await contentRepo.getHelpSupport();
      expect(result.title, 'Help & Support FAQ');
      expect(result.paragraphs.length, 2);
    });

    test('getPrivacyPolicy calls GET /api/content/privacy-policy', () async {
      mockApi.responses['/api/content/privacy-policy'] = {
        'success': true,
        'data': {
          'title': 'Privacy Policy 2026',
          'content': 'We protect user data.\n\nNo third-party sharing.',
          'effectiveDate': 'January 2026',
        },
      };

      final result = await contentRepo.getPrivacyPolicy();
      expect(result.title, 'Privacy Policy 2026');
      expect(result.effectiveDate, 'January 2026');
    });

    test(
      'getTermsConditions calls GET /api/content/terms-conditions',
      () async {
        mockApi.responses['/api/content/terms-conditions'] = {
          'success': true,
          'data': {
            'title': 'Terms & Conditions 2026',
            'content': 'Terms section 1.\n\nTerms section 2.',
          },
        };

        final result = await contentRepo.getTermsConditions();
        expect(result.title, 'Terms & Conditions 2026');
        expect(result.paragraphs.length, 2);
      },
    );
  });
}
