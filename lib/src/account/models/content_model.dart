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
  final String? subtitle;
  final String content;
  final String? effectiveDate;
  final String? bannerUrl;
  final List<String> paragraphs;
  final List<ContentSection> sections;
  final List<Map<String, String>> stats;
  final List<Map<String, String>> whyChooseUs;
  final List<Map<String, String>> faqs;

  const ContentModel({
    required this.title,
    this.subtitle,
    required this.content,
    this.effectiveDate,
    this.bannerUrl,
    this.paragraphs = const [],
    this.sections = const [],
    this.stats = const [],
    this.whyChooseUs = const [],
    this.faqs = const [],
  });

  bool get isEmpty =>
      content.trim().isEmpty &&
      paragraphs.where((p) => p.trim().isNotEmpty).isEmpty &&
      sections
          .where(
            (s) => s.heading.trim().isNotEmpty || s.body.trim().isNotEmpty,
          )
          .isEmpty;

  bool get isNotEmpty => !isEmpty;

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

    final subtitle =
        json['subtitle']?.toString() ??
        json['subheading']?.toString() ??
        json['tagline']?.toString();

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

    final bannerUrl =
        json['bannerUrl']?.toString() ??
        json['banner']?.toString() ??
        json['image']?.toString() ??
        json['imageUrl']?.toString();

    List<String> paragraphs = [];
    if (json['paragraphs'] is List) {
      paragraphs = (json['paragraphs'] as List)
          .map((p) => p.toString())
          .where((p) => p.trim().isNotEmpty)
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

    List<Map<String, String>> stats = [];
    if (json['stats'] is List) {
      for (final item in json['stats']) {
        if (item is Map) {
          stats.add(
            Map<String, String>.from(
              item.map((k, v) => MapEntry(k.toString(), v.toString())),
            ),
          );
        }
      }
    }

    List<Map<String, String>> whyChooseUs = [];
    if (json['whyChooseUs'] is List) {
      for (final item in json['whyChooseUs']) {
        if (item is Map) {
          whyChooseUs.add(
            Map<String, String>.from(
              item.map((k, v) => MapEntry(k.toString(), v.toString())),
            ),
          );
        }
      }
    }

    List<Map<String, String>> faqs = [];
    if (json['faqs'] is List) {
      for (final item in json['faqs']) {
        if (item is Map) {
          faqs.add(
            Map<String, String>.from(
              item.map((k, v) => MapEntry(k.toString(), v.toString())),
            ),
          );
        }
      }
    }

    return ContentModel(
      title: title,
      subtitle: subtitle,
      content: rawContent,
      effectiveDate: effectiveDate,
      bannerUrl: bannerUrl,
      paragraphs: paragraphs,
      sections: sections,
      stats: stats,
      whyChooseUs: whyChooseUs,
      faqs: faqs,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'content': content,
    if (effectiveDate != null) 'effectiveDate': effectiveDate,
    if (bannerUrl != null) 'bannerUrl': bannerUrl,
    'paragraphs': paragraphs,
    'sections': sections
        .map((s) => {'heading': s.heading, 'body': s.body})
        .toList(),
    if (stats.isNotEmpty) 'stats': stats,
    if (whyChooseUs.isNotEmpty) 'whyChooseUs': whyChooseUs,
    if (faqs.isNotEmpty) 'faqs': faqs,
  };

  factory ContentModel.aboutUsFallback() {
    return const ContentModel(
      title: 'About Us',
      subtitle: 'More Than a Grooming Salon. A Place Where Dogs Feel at Home.',
      content:
          'At Shear Heaven Pet Spa, we\'ve built our reputation on one simple belief. Every dog deserves professional care, gentle handling, and a grooming experience that leaves them looking and feeling their very best.\n\nFor over 20 years, we\'ve proudly provided professional Dog Grooming Services to families who trust us with one of the most important members of their family.\n\nAs a trusted Pet Grooming Company, we know grooming is about much more than appearance. A clean coat, healthy skin, trimmed nails, and proper hygiene all contribute to your dog\'s overall health and happiness.\n\nWhether your dog visits us for a refreshing bath, Nail Clipping, Flea Baths, or complete Full Service Pet Grooming, every appointment is personalized to their breed, coat condition, and individual personality.\n\nOur goal isn\'t simply to groom dogs. It\'s to build lasting relationships with every family that walks through our doors.',
      paragraphs: [
        'At Shear Heaven Pet Spa, we\'ve built our reputation on one simple belief. Every dog deserves professional care, gentle handling, and a grooming experience that leaves them looking and feeling their very best.',
        'For over 20 years, we\'ve proudly provided professional Dog Grooming Services to families who trust us with one of the most important members of their family.',
        'As a trusted Pet Grooming Company, we know grooming is about much more than appearance. A clean coat, healthy skin, trimmed nails, and proper hygiene all contribute to your dog\'s overall health and happiness.',
        'Whether your dog visits us for a refreshing bath, Nail Clipping, Flea Baths, or complete Full Service Pet Grooming, every appointment is personalized to their breed, coat condition, and individual personality.',
        'Our goal isn\'t simply to groom dogs. It\'s to build lasting relationships with every family that walks through our doors.',
      ],
      stats: [
        {
          'number': '35K+',
          'label': 'Dogs Groomed',
          'description':
              'Every grooming appointment is completed with care, patience, and attention to detail.',
        },
        {
          'number': '35K+',
          'label': 'Happy Dog Parents',
          'description':
              'Families continue choosing Shear Heaven Pet Spa for dependable Pet Grooming Services.',
        },
        {
          'number': '20+',
          'label': 'Years Of Experience',
          'description':
              'Providing trusted Dog Grooming and personalized care for more than two decades.',
        },
        {
          'number': '500+',
          'label': '5-Star Reviews',
          'description':
              'Real stories from dog owners who trust our experienced Groomers.',
        },
      ],
      sections: [
        ContentSection(
          heading: 'Our Mission',
          body:
              'To provide professional Dog Grooming Services that help every dog stay clean, healthy, comfortable, and confident while giving pet owners peace of mind through exceptional care and personalized service.',
        ),
        ContentSection(
          heading: 'Our Vision',
          body:
              'To be the most trusted Pet Groomer and Pet Grooming Company by delivering outstanding service, building lifelong relationships with dog owners, and setting the standard for compassionate grooming.',
        ),
        ContentSection(
          heading: 'Our Belief & Promise',
          body:
              'We Believe Every Dog Deserves Gentle, Professional Grooming. Every grooming appointment is handled with patience, experience, and genuine care. From playful puppies to senior dogs, our professional Groomers focus on your dog\'s comfort throughout every step of the grooming experience. At Shear Heaven Pet Spa, grooming is more than a service. It is our passion and our promise to every dog we care for.',
        ),
      ],
      whyChooseUs: [
        {
          'title': 'Experienced Groomers',
          'desc':
              'Our experienced Groomers have over 20 years of hands-on experience providing professional Dog Grooming Services for dogs of all breeds and sizes.',
        },
        {
          'title': 'Premium Grooming Products',
          'desc':
              'We use high quality grooming products that help maintain healthy skin and a clean, shiny coat.',
        },
        {
          'title': 'Personalized Dog Grooming',
          'desc':
              'Every dog receives customized care based on breed, coat type, age, activity level, and grooming needs.',
        },
        {
          'title': 'Clean & Safe Facility',
          'desc':
              'We maintain a clean grooming environment with sanitized equipment to provide a safe experience for every dog.',
        },
        {
          'title': 'Flea Baths Available',
          'desc':
              'Our specialized Flea Baths help remove fleas and leave your dog\'s coat feeling fresh and comfortable.',
        },
        {
          'title': 'Affordable Pricing',
          'desc':
              'Quality Pet Grooming should be accessible. We provide honest pricing without compromising on service.',
        },
        {
          'title': 'Trusted Dog Groomers',
          'desc':
              'Thousands of happy dog owners trust Shear Heaven Pet Spa for reliable Dog Grooming, Nail Clipping, and complete Pet Grooming Services.',
        },
      ],
      faqs: [
        {
          'q': 'How Often Should My Dog Be Groomed?',
          'a':
              'Most dogs benefit from grooming every 4 to 8 weeks, depending on their breed, coat type, and lifestyle.',
        },
        {
          'q': 'Do I Need to Schedule an Appointment?',
          'a':
              'Yes, we recommend scheduling appointments in advance to secure your preferred date and time.',
        },
        {
          'q': 'How Long Does a Grooming Appointment Take?',
          'a':
              'A standard grooming appointment typically takes 2 to 4 hours depending on the dog\'s size, breed, coat condition, and services requested.',
        },
        {
          'q': 'What Does a Full Service Pet Groom Include?',
          'a':
              'Full service pet groom includes a refreshing bath, blow dry, haircut styling, nail clipping, ear cleaning, and gland expression.',
        },
        {
          'q': 'What Grooming Products Do You Use?',
          'a':
              'We use pet-safe, gentle, and hypoallergenic shampoos and conditioners formulated specifically for sensitive canine skin.',
        },
      ],
    );
  }

  factory ContentModel.helpSupportFallback() {
    return const ContentModel(
      title: 'Help & Support',
      subtitle:
          'Find answers to common questions or reach out to our friendly team.',
      content: 'Find answers to common questions or reach out to our team.',
      paragraphs: [
        'How do I book an appointment?\nChoose your pet, select the desired package or add-on, pick a date and time slot, choose an available groomer, and confirm your booking.',
        'What is your cancellation policy?\nYou may cancel pending appointments immediately. For confirmed appointments, cancellations can be requested up to 3 hours before your scheduled time.',
        'Are walk-in services available?\nYes, we welcome walk-in nail trims, ear cleaning, and quick touch-ups during regular operating hours subject to stylist availability.',
        'Need direct help?\nReach our customer care team anytime via in-app chat, email, or telephone.',
      ],
      faqs: [
        {
          'q': 'How do I book a grooming appointment?',
          'a':
              'Simply select your pet, choose your desired grooming service, pick an available date and time slot, and confirm your booking.',
        },
        {
          'q': 'What is the cancellation policy?',
          'a':
              'Please notify us at least 3 hours before your appointment to cancel or reschedule without fee.',
        },
        {
          'q': 'What vaccinations are required?',
          'a':
              'All dogs must be up to date on Rabies and standard core vaccinations before grooming.',
        },
        {
          'q': 'How can I contact the salon directly?',
          'a':
              'You can call us at (817) 277-8433 or email shearheaven.dwg@gmail.com.',
        },
      ],
    );
  }

  factory ContentModel.privacyPolicyFallback() {
    return const ContentModel(
      title: 'Privacy Policy',
      subtitle:
          'Learn how Shear Heaven Pet Spa collects, uses, and protects your personal information.',
      content:
          'At Shear Heaven Pet Spa, we value your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, store, and protect the information you provide when you visit our website or use our Dog Grooming Services.\n\nBy using our website and mobile application, you agree to the practices described in this Privacy Policy.',
      effectiveDate: 'January 1, 2026',
      paragraphs: [
        'At Shear Heaven Pet Spa, we value your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, store, and protect the information you provide when you visit our website or use our Dog Grooming Services.',
        'By using our website and mobile application, you agree to the practices described in this Privacy Policy.',
      ],
      sections: [
        ContentSection(
          heading: '1. Information We Collect',
          body:
              'We may collect personal information that you voluntarily provide when you:\n• Book a grooming appointment\n• Complete a contact form\n• Subscribe to our newsletter\n• Contact us by phone, email, or through our website\n\nThe information we collect may include:\n• Name\n• Email address\n• Phone number\n• Dog\'s name and grooming details\n• Appointment requests\n• Any additional information you choose to provide',
        ),
        ContentSection(
          heading: '2. How We Use Your Information',
          body:
              'We use your information to:\n• Schedule and manage grooming appointments\n• Respond to inquiries and customer support requests\n• Provide our Dog Grooming Services\n• Send appointment confirmations or updates\n• Improve our website, mobile app, and customer experience\n• Share promotional offers or newsletters if you have subscribed\n\nWe do not sell or rent your personal information to third parties.',
        ),
        ContentSection(
          heading: '3. Cookies & Website Analytics',
          body:
              'Our website and mobile app may use cookies and similar technologies to improve your browsing experience, remember your preferences, and understand how visitors use our website.\n\nYou can disable cookies through your device or browser settings at any time. However, some features of the service may not function properly if cookies are disabled.',
        ),
        ContentSection(
          heading: '4. Information Sharing',
          body:
              'We do not sell, trade, or rent your personal information.\n\nWe may share your information only when:\n• Required by law\n• Necessary to protect our legal rights\n• Working with trusted service providers who help us operate our website, mobile app, or business, and who agree to keep your information confidential',
        ),
        ContentSection(
          heading: '5. Data Security',
          body:
              'We take reasonable administrative, technical, and physical measures to help protect your personal information from unauthorized access, loss, misuse, or disclosure.\n\nWhile we strive to protect your information, no method of online transmission or electronic storage can be guaranteed to be completely secure.',
        ),
        ContentSection(
          heading: '6. Third-Party Links',
          body:
              'Our website and application may contain links to third-party websites for your convenience.\n\nWe are not responsible for the privacy practices, content, or policies of external websites. We encourage you to review their privacy policies before providing any personal information.',
        ),
        ContentSection(
          heading: '7. Children\'s Privacy',
          body:
              'Our website and services are intended for adults who book grooming services for their dogs. We do not knowingly collect personal information from children under the age of 13.',
        ),
        ContentSection(
          heading: '8. Your Privacy Rights',
          body:
              'You may request to:\n• Access the personal information we hold about you\n• Correct inaccurate information\n• Update your contact details\n• Request deletion of your personal information, where permitted by law\n• Unsubscribe from marketing emails at any time\n\nTo make a request, please contact us using the information below.',
        ),
        ContentSection(
          heading: '9. Changes to This Privacy Policy',
          body:
              'We may update this Privacy Policy from time to time to reflect changes in our business practices or legal requirements.\n\nAny updates will be posted on this page with the revised effective date.',
        ),
        ContentSection(
          heading: '10. Contact Us',
          body:
              'If you have any questions about this Privacy Policy or how we handle your information, please contact us.\n\nShear Heaven Pet Spa\n2218 S. Bowen, Arlington, TX 76013\nPhone: (817) 277-8433\nEmail: shearheaven.dwg@gmail.com',
        ),
      ],
    );
  }

  factory ContentModel.termsConditionsFallback() {
    return const ContentModel(
      title: 'Terms & Conditions',
      subtitle:
          'Please review our terms of service, appointment guidelines, and pet care policies.',
      content:
          'Welcome to Shear Heaven Pet Spa. By accessing our website, booking an appointment, or using our services, you agree to the following Terms & Conditions. Please read them carefully before using our website or scheduling a grooming appointment.',
      effectiveDate: 'January 1, 2026',
      paragraphs: [
        'Welcome to Shear Heaven Pet Spa. By accessing our website, booking an appointment, or using our services, you agree to the following Terms & Conditions. Please read them carefully before using our website or scheduling a grooming appointment.',
      ],
      sections: [
        ContentSection(
          heading: '1. Acceptance of Terms',
          body:
              'By using the Shear Heaven Pet Spa website or booking any of our Dog Grooming Services, you acknowledge that you have read, understood, and agreed to these Terms & Conditions.\n\nIf you do not agree with any part of these terms, please do not use our website or services.',
        ),
        ContentSection(
          heading: '2. Services',
          body:
              'Shear Heaven Pet Spa provides professional dog grooming services, including but not limited to:\n• Full Service Pet Grooming\n• Bath & Blow Dry\n• Hair Trimming & Styling\n• Nail Clipping\n• Ear Cleaning\n• Teeth Brushing\n• Flea Baths\n• Add-on Grooming Services\n\nAll services are subject to availability.',
        ),
        ContentSection(
          heading: '3. Appointments',
          body:
              'Appointments are recommended to ensure availability. While we do our best to accommodate your preferred date and time, appointments are scheduled on a first come, first served basis.\n\nPlease arrive on time for your scheduled appointment. Late arrivals may require rescheduling or adjustments to your grooming service.',
        ),
        ContentSection(
          heading: '4. Cancellation & No-Show Policy',
          body:
              'If you need to cancel or reschedule your appointment, please notify us as early as possible.\n\nRepeated no-shows or last-minute cancellations may require a deposit before future appointments can be scheduled.',
        ),
        ContentSection(
          heading: '5. Pet Health & Safety',
          body:
              'The health and safety of every dog and our team is our highest priority. Before each grooming appointment, owners must inform us of any medical conditions, allergies, injuries, medications, behavioral concerns, or other factors that may affect the grooming process.\n\nAll dogs must be up to date on their required vaccinations before receiving any grooming services at Shear Heaven Pet Spa. Proof of current vaccinations may be requested before or at the time of your appointment. Dogs without current vaccination records may be refused service or asked to reschedule until the required documentation is provided.\n\nShear Heaven Pet Spa reserves the right to refuse or discontinue grooming services if a dog displays aggressive behavior, shows signs of illness, or if grooming may pose a risk to the dog, other dogs, or our staff.\n\nFailure to provide accurate health information or proof of required vaccinations may result in the refusal or discontinuation of grooming services.',
        ),
        ContentSection(
          heading: '6. Vaccination Requirements',
          body:
              'At Shear Heaven Pet Spa, the health and safety of every dog in our care is our highest priority.\n\nAll dogs are required to be up to date on their vaccinations before their grooming appointment. Proof of current vaccinations may be requested prior to or at the time of your appointment.\n\nFor the safety of all dogs and our team, we reserve the right to refuse or reschedule any grooming appointment if the required vaccinations have not been completed or verified.\n\nIt is the owner\'s responsibility to ensure their dog\'s vaccination records are current before visiting our salon.',
        ),
        ContentSection(
          heading: '7. Grooming Results',
          body:
              'Every dog is unique. The final grooming result may vary depending on your dog\'s coat condition, matting, behavior, and overall health.\n\nFor severely matted coats, additional grooming charges may apply. In some cases, shaving may be the safest and most humane option.',
        ),
        ContentSection(
          heading: '8. Pricing',
          body:
              'Prices listed on our website and app are starting prices and may vary depending on:\n• Breed\n• Size\n• Coat length\n• Coat condition\n• Temperament\n• Time required\n• Additional grooming services requested\n\nAny additional charges will be discussed whenever possible before the grooming service begins.',
        ),
        ContentSection(
          heading: '9. Payment',
          body:
              'Payment is due upon completion of the grooming service. We accept approved payment methods available at our salon.',
        ),
        ContentSection(
          heading: '10. Website Content',
          body:
              'All content on this website and app, including text, images, graphics, logos, and design elements, is the property of Shear Heaven Pet Spa unless otherwise stated.\n\nNo content may be copied, reproduced, or distributed without prior written permission.',
        ),
        ContentSection(
          heading: '11. Third-Party Links',
          body:
              'Our website and application may contain links to third-party websites for your convenience. We are not responsible for the content, privacy practices, or policies of those external websites.',
        ),
        ContentSection(
          heading: '12. Limitation of Liability',
          body:
              'While we take every reasonable precaution to ensure your dog\'s safety and comfort, grooming involves the use of professional tools and equipment.\n\nShear Heaven Pet Spa shall not be held liable for pre-existing medical conditions, underlying health issues, or complications that were not disclosed before the grooming appointment.',
        ),
        ContentSection(
          heading: '13. Privacy',
          body:
              'Your personal information is handled in accordance with our Privacy Policy.\n\nWe only collect information necessary to provide our services and communicate with you regarding appointments.',
        ),
        ContentSection(
          heading: '14. Changes to These Terms',
          body:
              'Shear Heaven Pet Spa reserves the right to update or modify these Terms & Conditions at any time without prior notice.\n\nAny changes become effective immediately upon being posted on this website and in the app.',
        ),
        ContentSection(
          heading: '15. Contact Us',
          body:
              'If you have any questions regarding these Terms & Conditions, please contact us.\n\nShear Heaven Pet Spa\n2218 S. Bowen, Arlington, TX 76013\nPhone: (817) 277-8433\nEmail: shearheaven.dwg@gmail.com',
        ),
      ],
    );
  }
}

