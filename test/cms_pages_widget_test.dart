import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/account/models/content_model.dart';
import 'package:shear_heaven_pet_spa/src/account/models/store_contact_info_model.dart';
import 'package:shear_heaven_pet_spa/src/account/repos/content_repository.dart';
import 'package:shear_heaven_pet_spa/src/account/views/mobile/about_us_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/account/views/mobile/help_support_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/account/views/mobile/privacy_policy_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/account/views/mobile/terms_condition_page_mobile.dart';

class _FakeContentRepository extends ContentRepository {
  StoreContactInfo contactInfo = const StoreContactInfo(
    storeName: 'Shear Heaven Arlington',
    address: '2218 S. Bowen, Arlington, TX 76013',
    phone: '(817) 277-8433',
    email: 'shearheaven.dwg@gmail.com',
    operatingHours: 'Mon - Sat: 9:00 AM - 6:00 PM',
  );

  ContentModel aboutUs = const ContentModel(
    title: 'About Shear Heaven',
    content: 'Providing loving dog grooming care.\n\nOver 20 years in business.',
    paragraphs: [
      'Providing loving dog grooming care.',
      'Over 20 years in business.',
    ],
  );

  ContentModel helpSupport = const ContentModel(
    title: 'Customer Support FAQ',
    content: 'Frequently asked questions.\n\nContact us for assistance.',
    paragraphs: [
      'Frequently asked questions.',
      'Contact us for assistance.',
    ],
  );

  ContentModel privacyPolicy = const ContentModel(
    title: 'Privacy Policy Document',
    content: 'Your privacy matters to us.\n\nWe encrypt all data.',
    effectiveDate: 'March 1, 2026',
    paragraphs: [
      'Your privacy matters to us.',
      'We encrypt all data.',
    ],
  );

  ContentModel termsConditions = const ContentModel(
    title: 'Terms of Service',
    content: 'App terms of service.\n\nCancellation policy details.',
    effectiveDate: 'March 1, 2026',
    paragraphs: [
      'App terms of service.',
      'Cancellation policy details.',
    ],
  );

  @override
  Future<StoreContactInfo> getStoreContactInfo() async => contactInfo;

  @override
  Future<ContentModel> getAboutUs() async => aboutUs;

  @override
  Future<ContentModel> getHelpSupport() async => helpSupport;

  @override
  Future<ContentModel> getPrivacyPolicy() async => privacyPolicy;

  @override
  Future<ContentModel> getTermsConditions() async => termsConditions;
}

void main() {
  late _FakeContentRepository fakeContentRepo;

  setUpAll(() {
    fakeContentRepo = _FakeContentRepository();
    if (GetIt.I.isRegistered<ContentRepository>()) {
      GetIt.I.unregister<ContentRepository>();
    }
    GetIt.I.registerSingleton<ContentRepository>(fakeContentRepo);
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('CMS Pages Widget Tests', () {
    testWidgets('HelpSupportPageMobile renders contact details and operating hours',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(const HelpSupportPageMobile()));
      await tester.pumpAndSettle();

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Contact Details'), findsOneWidget);
      expect(find.textContaining('2218 S. Bowen, Arlington, TX 76013'), findsOneWidget);
      expect(find.textContaining('(817) 277-8433'), findsOneWidget);
      expect(find.textContaining('shearheaven.dwg@gmail.com'), findsOneWidget);
      expect(find.text('Operating Hours'), findsOneWidget);
      expect(find.text('Mon - Sat: 9:00 AM - 6:00 PM'), findsOneWidget);
      expect(find.text('Customer Support FAQ'), findsOneWidget);
      expect(find.text('Frequently asked questions.'), findsOneWidget);
    });

    testWidgets('AboutUsPageMobile renders dynamic content from API',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AboutUsPageMobile()));
      await tester.pumpAndSettle();

      expect(find.text('About Shear Heaven'), findsOneWidget);
      expect(find.text('Providing loving dog grooming care.'), findsOneWidget);
      expect(find.text('Over 20 years in business.'), findsOneWidget);
    });

    testWidgets('AboutUsPageMobile renders website fallback when API content is empty',
        (tester) async {
      fakeContentRepo.aboutUs = const ContentModel(title: '', content: '');
      await tester.pumpWidget(buildTestableWidget(const AboutUsPageMobile()));
      await tester.pumpAndSettle();

      expect(find.text('Where Every Dog Gets the Royal Treatment'), findsOneWidget);
      expect(find.text('Why Dog Owners Choose Shear Heaven'), findsOneWidget);
      expect(find.text('Our Story & Passion'), findsOneWidget);
      expect(find.text('Experienced Groomers'), findsWidgets);
    });

    testWidgets('PrivacyPolicyPageMobile renders dynamic privacy policy from API',
        (tester) async {
      fakeContentRepo.privacyPolicy = const ContentModel(
        title: 'Privacy Policy Document',
        content: 'Your privacy matters to us.\n\nWe encrypt all data.',
        effectiveDate: 'March 1, 2026',
        paragraphs: [
          'Your privacy matters to us.',
          'We encrypt all data.',
        ],
      );
      await tester.pumpWidget(buildTestableWidget(const PrivacyPolicyPageMobile()));
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Effective: March 1, 2026'), findsOneWidget);
      expect(find.text('Your privacy matters to us.'), findsOneWidget);
      expect(find.text('We encrypt all data.'), findsOneWidget);
    });

    testWidgets('PrivacyPolicyPageMobile renders website fallback when API content is empty',
        (tester) async {
      fakeContentRepo.privacyPolicy = const ContentModel(title: '', content: '');
      await tester.pumpWidget(buildTestableWidget(const PrivacyPolicyPageMobile()));
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('1. Information We Collect'), findsOneWidget);
      expect(find.text('2. How We Use Your Information'), findsOneWidget);
      expect(find.text('Questions About Your Privacy?'), findsOneWidget);
    });

    testWidgets('TermsConditionPageMobile renders dynamic terms and conditions from API',
        (tester) async {
      fakeContentRepo.termsConditions = const ContentModel(
        title: 'Terms of Service',
        content: 'App terms of service.\n\nCancellation policy details.',
        effectiveDate: 'March 1, 2026',
        paragraphs: [
          'App terms of service.',
          'Cancellation policy details.',
        ],
      );
      await tester.pumpWidget(buildTestableWidget(const TermsConditionPageMobile()));
      await tester.pumpAndSettle();

      expect(find.text('Terms & Conditions'), findsWidgets);
      expect(find.text('Effective: March 1, 2026'), findsOneWidget);
      expect(find.text('App terms of service.'), findsOneWidget);
      expect(find.text('Cancellation policy details.'), findsOneWidget);
    });

    testWidgets('TermsConditionPageMobile renders website fallback when API content is empty',
        (tester) async {
      fakeContentRepo.termsConditions = const ContentModel(title: '', content: '');
      await tester.pumpWidget(buildTestableWidget(const TermsConditionPageMobile()));
      await tester.pumpAndSettle();

      expect(find.text('Terms & Conditions'), findsWidgets);
      expect(find.text('1. Acceptance of Terms'), findsOneWidget);
      expect(find.text('2. Services'), findsOneWidget);
      expect(find.text('Questions About These Terms?'), findsOneWidget);
    });
  });
}

