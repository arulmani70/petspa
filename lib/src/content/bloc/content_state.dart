part of 'content_bloc.dart';

enum ContentStatus { initial, loading, loaded, success, failure }

class ContentState extends Equatable {
  final ContentStatus status;
  final String message;
  final StoreContactInfo? contactInfo;
  final ContentModel? aboutUs;
  final ContentModel? helpSupport;
  final ContentModel? privacyPolicy;
  final ContentModel? termsConditions;

  const ContentState({
    required this.status,
    required this.message,
    this.contactInfo,
    this.aboutUs,
    this.helpSupport,
    this.privacyPolicy,
    this.termsConditions,
  });

  static const ContentState initial = ContentState(
    status: ContentStatus.initial,
    message: '',
  );

  ContentState copyWith({
    ContentStatus Function()? status,
    String Function()? message,
    StoreContactInfo? Function()? contactInfo,
    ContentModel? Function()? aboutUs,
    ContentModel? Function()? helpSupport,
    ContentModel? Function()? privacyPolicy,
    ContentModel? Function()? termsConditions,
  }) {
    return ContentState(
      status: status != null ? status() : this.status,
      message: message != null ? message() : this.message,
      contactInfo: contactInfo != null ? contactInfo() : this.contactInfo,
      aboutUs: aboutUs != null ? aboutUs() : this.aboutUs,
      helpSupport: helpSupport != null ? helpSupport() : this.helpSupport,
      privacyPolicy: privacyPolicy != null ? privacyPolicy() : this.privacyPolicy,
      termsConditions: termsConditions != null ? termsConditions() : this.termsConditions,
    );
  }

  @override
  List<Object?> get props => [
        status,
        message,
        contactInfo,
        aboutUs,
        helpSupport,
        privacyPolicy,
        termsConditions,
      ];
}
