import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/content_model.dart';
import 'package:shear_heaven_pet_spa/src/account/models/store_contact_info_model.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

class ContentRepository {
  final Logger _log = Logger();

  Future<void> initialize() async {
    _log.d('ContentRepository::initialize::Initialized');
  }

  /// GET /api/store/contact-info
  ///
  /// Retrieves official store contact details (address, phone, email, hours, website).
  /// Requires Bearer accessToken.
  Future<StoreContactInfo> getStoreContactInfo() async {
    try {
      _log.d('ContentRepository::getStoreContactInfo::GET /api/store/contact-info');
      final response = await ServicesLocator.apiRepository.get('/api/store/contact-info');

      if (response != null && response['data'] != null) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          return StoreContactInfo.fromJson(data);
        } else if (data is Map) {
          return StoreContactInfo.fromJson(Map<String, dynamic>.from(data));
        }
      }

      _log.w('ContentRepository::getStoreContactInfo::Empty or unexpected response, using default fallback');
      return StoreContactInfo.defaultInfo();
    } catch (e) {
      _log.e('ContentRepository::getStoreContactInfo::Error: $e');
      return StoreContactInfo.defaultInfo();
    }
  }

  /// GET /api/content/about-us
  ///
  /// Retrieves About Us story and overview.
  /// Requires Bearer accessToken.
  Future<ContentModel> getAboutUs() async {
    try {
      _log.d('ContentRepository::getAboutUs::GET /api/content/about-us');
      final response = await ServicesLocator.apiRepository.get('/api/content/about-us');

      if (response != null && response['data'] != null) {
        final data = response['data'];
        ContentModel? model;
        if (data is Map<String, dynamic>) {
          model = ContentModel.fromJson(data, defaultTitle: 'About Us');
        } else if (data is Map) {
          model = ContentModel.fromJson(Map<String, dynamic>.from(data), defaultTitle: 'About Us');
        }
        if (model != null && model.isNotEmpty) {
          return model;
        }
      }

      _log.w('ContentRepository::getAboutUs::Empty or unexpected response, using default fallback');
      return ContentModel.aboutUsFallback();
    } catch (e) {
      _log.e('ContentRepository::getAboutUs::Error: $e');
      return ContentModel.aboutUsFallback();
    }
  }

  /// GET /api/content/help-support
  ///
  /// Retrieves Help & Support general questions and instructions.
  /// Requires Bearer accessToken.
  Future<ContentModel> getHelpSupport() async {
    try {
      _log.d('ContentRepository::getHelpSupport::GET /api/content/help-support');
      final response = await ServicesLocator.apiRepository.get('/api/content/help-support');

      if (response != null && response['data'] != null) {
        final data = response['data'];
        ContentModel? model;
        if (data is Map<String, dynamic>) {
          model = ContentModel.fromJson(data, defaultTitle: 'Help & Support');
        } else if (data is Map) {
          model = ContentModel.fromJson(Map<String, dynamic>.from(data), defaultTitle: 'Help & Support');
        }
        if (model != null && model.isNotEmpty) {
          return model;
        }
      }

      _log.w('ContentRepository::getHelpSupport::Empty or unexpected response, using default fallback');
      return ContentModel.helpSupportFallback();
    } catch (e) {
      _log.e('ContentRepository::getHelpSupport::Error: $e');
      return ContentModel.helpSupportFallback();
    }
  }

  /// GET /api/content/privacy-policy
  ///
  /// Retrieves Privacy Policy clauses and effective date.
  /// Requires Bearer accessToken.
  Future<ContentModel> getPrivacyPolicy() async {
    try {
      _log.d('ContentRepository::getPrivacyPolicy::GET /api/content/privacy-policy');
      final response = await ServicesLocator.apiRepository.get('/api/content/privacy-policy');

      if (response != null && response['data'] != null) {
        final data = response['data'];
        ContentModel? model;
        if (data is Map<String, dynamic>) {
          model = ContentModel.fromJson(data, defaultTitle: 'Privacy Policy');
        } else if (data is Map) {
          model = ContentModel.fromJson(Map<String, dynamic>.from(data), defaultTitle: 'Privacy Policy');
        }
        if (model != null && model.isNotEmpty) {
          return model;
        }
      }

      _log.w('ContentRepository::getPrivacyPolicy::Empty or unexpected response, using default fallback');
      return ContentModel.privacyPolicyFallback();
    } catch (e) {
      _log.e('ContentRepository::getPrivacyPolicy::Error: $e');
      return ContentModel.privacyPolicyFallback();
    }
  }

  /// GET /api/content/terms-conditions
  ///
  /// Retrieves Terms and Conditions clauses and cancellation policies.
  /// Requires Bearer accessToken.
  Future<ContentModel> getTermsConditions() async {
    try {
      _log.d('ContentRepository::getTermsConditions::GET /api/content/terms-conditions');
      final response = await ServicesLocator.apiRepository.get('/api/content/terms-conditions');

      if (response != null && response['data'] != null) {
        final data = response['data'];
        ContentModel? model;
        if (data is Map<String, dynamic>) {
          model = ContentModel.fromJson(data, defaultTitle: 'Terms & Conditions');
        } else if (data is Map) {
          model = ContentModel.fromJson(Map<String, dynamic>.from(data), defaultTitle: 'Terms & Conditions');
        }
        if (model != null && model.isNotEmpty) {
          return model;
        }
      }

      _log.w('ContentRepository::getTermsConditions::Empty or unexpected response, using default fallback');
      return ContentModel.termsConditionsFallback();
    } catch (e) {
      _log.e('ContentRepository::getTermsConditions::Error: $e');
      return ContentModel.termsConditionsFallback();
    }
  }
}
