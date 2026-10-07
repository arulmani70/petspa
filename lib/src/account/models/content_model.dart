class ContentSection {
  final String heading;
  final String body;

  const ContentSection({required this.heading, required this.body});

  factory ContentSection.fromMap(Map<String, dynamic> map) {
    return ContentSection(
      heading: map['heading']?.toString() ?? map['title']?.toString() ?? '',
      body:
          map['body']?.toString() ??
          map['content']?.toString() ??
          map['description']?.toString() ??
          '',
    );
  }
}

class ContentModel {
  final String title;
  final String content;
  final String? effectiveDate;
  final List<String> paragraphs;
  final List<ContentSection> sections;

  const ContentModel({
    required this.title,
    required this.content,
    this.effectiveDate,
    this.paragraphs = const [],
    this.sections = const [],
  });

  factory ContentModel.fromJson(
    Map<String, dynamic> json, {
    String defaultTitle = '',
    String defaultContent = '',
  }) {
    final title =
        json['title']?.toString() ??
        json['heading']?.toString() ??
        json['name']?.toString() ??
        defaultTitle;

    final rawContent =
        json['content']?.toString() ??
        json['body']?.toString() ??
        json['description']?.toString() ??
        json['text']?.toString() ??
        defaultContent;

    final effectiveDate =
        json['effectiveDate']?.toString() ??
        json['lastUpdated']?.toString() ??
        json['updatedAt']?.toString() ??
        json['date']?.toString();

    List<String> paragraphs = [];
    if (json['paragraphs'] is List) {
      paragraphs = (json['paragraphs'] as List)
          .map((p) => p.toString())
          .toList();
    } else if (rawContent.isNotEmpty) {
      paragraphs = rawContent
          .split('\n\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }

    List<ContentSection> sections = [];
    if (json['sections'] is List) {
      for (final s in json['sections']) {
        if (s is Map) {
          sections.add(ContentSection.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    } else if (json['items'] is List) {
      for (final s in json['items']) {
        if (s is Map) {
          sections.add(ContentSection.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    }

    return ContentModel(
      title: title,
      content: rawContent,
      effectiveDate: effectiveDate,
      paragraphs: paragraphs,
      sections: sections,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    if (effectiveDate != null) 'effectiveDate': effectiveDate,
    'paragraphs': paragraphs,
    'sections': sections
        .map((s) => {'heading': s.heading, 'body': s.body})
        .toList(),
  };

  factory ContentModel.aboutUsFallback() {
    return const ContentModel(
      title: 'About Us',
      content:
          'Shear Heaven Pet Spa is dedicated to providing luxury grooming services...',
      paragraphs: [
        'At Shear Heaven Pet Spa, we believe pets are family. Founded with love and dedication to animal wellness, our mission is to provide gentle, stress-free grooming and spa services that keep your beloved companions feeling their best.',
        'Our certified groomers use premium, non-toxic, hypoallergenic organic products tailored specifically to your pet\'s coat and skin needs. From gentle baths to stylish breed-standard trims, we treat every pet with gentle hands and full devotion.',
        'We operate with strict hygiene, individual sanitization routines, and climate-controlled resting areas so you can rest assured your pet is in the safest, most caring environment.',
      ],
    );
  }

  factory ContentModel.helpSupportFallback() {
    return const ContentModel(
      title: 'Help & Support',
      content: 'Find answers to common questions or reach out to our team.',
      paragraphs: [
        'How do I book an appointment?\nChoose your pet, select the desired package or add-on, pick a date and time slot, choose an available groomer, and confirm your booking.',
        'What is your cancellation policy?\nYou may cancel pending appointments immediately. For confirmed appointments, cancellations can be requested up to 3 hours before your scheduled time.',
        'Are walk-in services available?\nYes, we welcome walk-in nail trims, ear cleaning, and quick touch-ups during regular operating hours subject to stylist availability.',
        'Need direct help?\nReach our customer care team anytime via in-app chat, email, or telephone listed above.',
      ],
    );
  }

  factory ContentModel.privacyPolicyFallback() {
    return const ContentModel(
      title: 'Privacy & Policy',
      content: '',
      effectiveDate: 'January 1, 2026',
      sections: [
        ContentSection(
          heading: '1. Information We Collect',
          body:
              'We collect personal information you provide when creating an account, registering your pets, booking grooming sessions, or contacting support. This includes your name, email, phone number, pet medical/allergy details, and payment confirmation details.',
        ),
        ContentSection(
          heading: '2. How We Use Your Information',
          body:
              'Your information is used strictly to fulfill grooming appointments, send confirmation and reminder notifications, process transactions, and personalize your pet care experience.',
        ),
        ContentSection(
          heading: '3. Data Security & Storage',
          body:
              'We adopt strict industry-standard encryption protocols to protect your personal and pet information against unauthorized access, loss, or alteration.',
        ),
        ContentSection(
          heading: '4. Third-Party Sharing',
          body:
              'We never sell or rent your personal information to third parties. Data is shared exclusively with necessary service providers such as SMS gateways and cloud servers.',
        ),
      ],
    );
  }

  factory ContentModel.termsConditionsFallback() {
    return const ContentModel(
      title: 'Terms & Condition',
      content: '',
      effectiveDate: 'January 1, 2026',
      sections: [
        ContentSection(
          heading: '1. Acceptance of Terms',
          body:
              'By accessing or using the Shear Heaven Pet Spa mobile application, you agree to be bound by these terms and conditions and all applicable laws and regulations.',
        ),
        ContentSection(
          heading: '2. Appointments & Timeliness',
          body:
              'Please arrive 5–10 minutes before your scheduled appointment. Late arrivals exceeding 15 minutes may result in appointment rescheduling or service modification.',
        ),
        ContentSection(
          heading: '3. Pet Vaccinations & Health',
          body:
              'All pets must be up-to-date on standard vaccinations including Rabies. Owners must disclose any pre-existing health conditions, behavioral traits, or allergies.',
        ),
        ContentSection(
          heading: '4. Cancellation & Rescheduling Policy',
          body:
              'Pending bookings may be cancelled at any time without fee. Confirmed bookings require at least 3 hours advance notice to cancel or reschedule.',
        ),
      ],
    );
  }
}
