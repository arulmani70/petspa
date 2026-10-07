part of 'content_bloc.dart';

sealed class ContentEvent extends Equatable {
  const ContentEvent();

  @override
  List<Object?> get props => [];
}

class FetchStoreContactInfo extends ContentEvent {
  const FetchStoreContactInfo();
}

class FetchAboutUsContent extends ContentEvent {
  const FetchAboutUsContent();
}

class FetchHelpSupportContent extends ContentEvent {
  const FetchHelpSupportContent();
}

class FetchPrivacyPolicyContent extends ContentEvent {
  const FetchPrivacyPolicyContent();
}

class FetchTermsConditionsContent extends ContentEvent {
  const FetchTermsConditionsContent();
}

class FetchAllCmsContent extends ContentEvent {
  const FetchAllCmsContent();
}
