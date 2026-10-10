import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/account/models/content_model.dart';
import 'package:shear_heaven_pet_spa/src/account/models/store_contact_info_model.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

class AboutUsPageMobile extends StatefulWidget {
  const AboutUsPageMobile({super.key});

  @override
  State<AboutUsPageMobile> createState() => _AboutUsPageMobileState();
}

class _AboutUsPageMobileState extends State<AboutUsPageMobile> {
  bool _isLoading = true;
  String? _errorMessage;
  ContentModel? _content;
  StoreContactInfo? _contactInfo;
  int? _expandedFaqIndex;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ServicesLocator.contentRepository.getAboutUs(),
        ServicesLocator.contentRepository.getStoreContactInfo(),
      ]);

      if (!mounted) return;

      final about = results[0] as ContentModel;
      final contact = results[1] as StoreContactInfo;

      setState(() {
        _content = about.isNotEmpty ? about : ContentModel.aboutUsFallback();
        _contactInfo = contact;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _content = ContentModel.aboutUsFallback();
        _contactInfo = StoreContactInfo.defaultInfo();
        _isLoading = false;
      });
    }
  }

  bool _canPop(BuildContext context) {
    try {
      return context.canPop();
    } catch (_) {
      return Navigator.of(context).canPop();
    }
  }

  void _handleBack(BuildContext context) {
    try {
      if (context.canPop()) {
        context.pop();
        return;
      }
    } catch (_) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }
    }
    try {
      context.goNamed(RouteNames.settings);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = _content?.title.isNotEmpty == true ? _content!.title : 'About Us';

    return PopScope(
      canPop: _canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          centerTitle: false,
          title: Text(
            title,
            style: AppFonts.parkinsans(
              size: 20,
              weight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
            onPressed: () => _handleBack(context),
          ),
        ),
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E1E1E)),
          strokeWidth: 2.5,
        ),
      );
    }

    if (_errorMessage != null && (_content == null || _content!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppFonts.poppins(size: 14, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _loadContent,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final content = (_content != null && _content!.isNotEmpty)
        ? _content!
        : ContentModel.aboutUsFallback();

    final contact = _contactInfo ?? StoreContactInfo.defaultInfo();

    return RefreshIndicator(
      onRefresh: _loadContent,
      color: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroBanner(content),
            const SizedBox(height: 20),
            _buildStorySection(content),
            const SizedBox(height: 24),
            _buildStatsSection(content),
            const SizedBox(height: 24),
            _buildMissionVisionCards(content),
            const SizedBox(height: 24),
            _buildPromiseCard(content),
            const SizedBox(height: 24),
            _buildWhyChooseUsSection(content),
            const SizedBox(height: 24),
            _buildFaqSection(content),
            const SizedBox(height: 24),
            _buildContactCard(contact),
            const SizedBox(height: 20),
            _buildBookNowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(ContentModel content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, size: 14, color: Color(0xFFFBBF24)),
                const SizedBox(width: 6),
                Text(
                  '20+ YEARS OF EXCELLENCE',
                  style: AppFonts.parkinsans(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SvgPicture.asset(
              'assets/images/common/logo.svg',
              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.pets, size: 36, color: Colors.black),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Where Every Dog Gets the Royal Treatment',
            textAlign: TextAlign.center,
            style: AppFonts.parkinsans(
              size: 20,
              weight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.subtitle ?? 'More Than a Grooming Salon. A Place Where Dogs Feel at Home.',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 13,
              weight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorySection(ContentModel content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Our Story & Passion',
                style: AppFonts.parkinsans(
                  size: 17,
                  weight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...content.paragraphs.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                p,
                style: AppFonts.poppins(
                  size: 13.5,
                  weight: FontWeight.w400,
                  color: const Color(0xFF374151),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ContentModel content) {
    final stats = content.stats.isNotEmpty
        ? content.stats
        : [
            {'number': '35K+', 'label': 'Dogs Groomed'},
            {'number': '35K+', 'label': 'Happy Parents'},
            {'number': '20+', 'label': 'Years Experience'},
            {'number': '500+', 'label': '5-Star Reviews'},
          ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final item = stats[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item['number'] ?? '',
                style: AppFonts.parkinsans(
                  size: 24,
                  weight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['label'] ?? '',
                textAlign: TextAlign.center,
                style: AppFonts.poppins(
                  size: 12,
                  weight: FontWeight.w600,
                  color: const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMissionVisionCards(ContentModel content) {
    final missionSec = content.sections.firstWhere(
      (s) => s.heading.toLowerCase().contains('mission'),
      orElse: () => const ContentSection(
        heading: 'Our Mission',
        body:
            'To provide professional Dog Grooming Services that help every dog stay clean, healthy, comfortable, and confident while giving pet owners peace of mind through exceptional care.',
      ),
    );

    final visionSec = content.sections.firstWhere(
      (s) => s.heading.toLowerCase().contains('vision'),
      orElse: () => const ContentSection(
        heading: 'Our Vision',
        body:
            'To be the most trusted Pet Groomer by delivering outstanding service, building lifelong relationships with dog owners, and setting the standard for compassionate grooming.',
      ),
    );

    return Column(
      children: [
        _buildPillCard(
          icon: Icons.track_changes_rounded,
          title: missionSec.heading,
          body: missionSec.body,
          accentColor: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
        ),
        const SizedBox(height: 12),
        _buildPillCard(
          icon: Icons.auto_awesome_rounded,
          title: visionSec.heading,
          body: visionSec.body,
          accentColor: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF5F3FF),
        ),
      ],
    );
  }

  Widget _buildPillCard({
    required IconData icon,
    required String title,
    required String body,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.parkinsans(
                    size: 16,
                    weight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppFonts.poppins(
                    size: 13,
                    weight: FontWeight.w400,
                    color: const Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromiseCard(ContentModel content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 8),
              Text(
                'Our Belief & Promise',
                style: AppFonts.parkinsans(
                  size: 16,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'We Believe Every Dog Deserves Gentle, Professional Grooming.\n\nEvery grooming appointment is handled with patience, experience, and genuine care. From playful puppies to senior dogs, our groomers focus on your pet\'s comfort throughout every step.',
            style: AppFonts.poppins(
              size: 13,
              weight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseUsSection(ContentModel content) {
    final features = content.whyChooseUs.isNotEmpty
        ? content.whyChooseUs
        : [
            {
              'title': 'Experienced Groomers',
              'desc': 'Over 20 years of hands-on experience caring for all breeds and sizes.',
            },
            {
              'title': 'Premium Grooming Products',
              'desc': 'Gentle, hypoallergenic, non-toxic organic shampoos and conditioners.',
            },
            {
              'title': 'Personalized Care',
              'desc': 'Tailored sessions matching your dog\'s coat, health, and comfort.',
            },
            {
              'title': 'Clean & Safe Facility',
              'desc': 'Sanitized tools, secure handling, and climate-controlled resting spaces.',
            },
            {
              'title': 'Flea & Tick Baths',
              'desc': 'Targeted relief baths to eliminate pests safely and gently.',
            },
            {
              'title': 'Honest & Transparent Pricing',
              'desc': 'Accessible, upfront pricing with no hidden charges.',
            },
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHY CHOOSE US',
            style: AppFonts.parkinsans(
              size: 12,
              weight: FontWeight.w700,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Why Dog Owners Choose Shear Heaven',
            style: AppFonts.parkinsans(
              size: 17,
              weight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f['title'] ?? '',
                            style: AppFonts.parkinsans(
                              size: 14,
                              weight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f['desc'] ?? '',
                            style: AppFonts.poppins(
                              size: 12.5,
                              weight: FontWeight.w400,
                              color: const Color(0xFF4B5563),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFaqSection(ContentModel content) {
    final faqs = content.faqs.isNotEmpty
        ? content.faqs
        : [
            {
              'q': 'How Often Should My Dog Be Groomed?',
              'a':
                  'Most dogs benefit from grooming every 4 to 8 weeks, depending on their breed, coat type, and lifestyle.',
            },
            {
              'q': 'Do I Need to Schedule an Appointment?',
              'a':
                  'Yes, we recommend booking appointments in advance to secure your preferred groomer and time slot.',
            },
            {
              'q': 'How Long Does a Grooming Appointment Take?',
              'a':
                  'A typical grooming appointment lasts 2 to 4 hours depending on the dog\'s coat condition and services.',
            },
            {
              'q': 'What Does a Full Service Pet Groom Include?',
              'a':
                  'Includes bath, blow dry, haircut styling, nail trimming, ear cleaning, and gland expression.',
            },
            {
              'q': 'What Grooming Products Do You Use?',
              'a':
                  'We use premium, pet-safe, gentle, and hypoallergenic shampoos and conditioners.',
            },
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FREQUENTLY ASKED QUESTIONS',
            style: AppFonts.parkinsans(
              size: 12,
              weight: FontWeight.w700,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Got Questions? We\'ve Got Answers.',
            style: AppFonts.parkinsans(
              size: 17,
              weight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(faqs.length, (index) {
            final faq = faqs[index];
            final isExpanded = _expandedFaqIndex == index;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isExpanded ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isExpanded ? Colors.black12 : const Color(0xFFE5E7EB),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: Key('faq_$index'),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _expandedFaqIndex = expanded ? index : null;
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isExpanded ? Colors.black : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: AppFonts.parkinsans(
                        size: 12,
                        weight: FontWeight.w700,
                        color: isExpanded ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  title: Text(
                    faq['q'] ?? '',
                    style: AppFonts.poppins(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(
                        faq['a'] ?? '',
                        style: AppFonts.poppins(
                          size: 13,
                          weight: FontWeight.w400,
                          color: const Color(0xFF4B5563),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContactCard(StoreContactInfo contact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 20, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                'Salon Location & Contact',
                style: AppFonts.parkinsans(
                  size: 16,
                  weight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _contactItem(
            Icons.pin_drop_rounded,
            'Address',
            contact.address,
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _contactItem(
            Icons.phone_rounded,
            'Grooming Appointments',
            contact.phone,
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _contactItem(
            Icons.email_outlined,
            'Email Address',
            contact.email,
          ),
          const Divider(height: 20, color: Color(0xFFF3F4F6)),
          _contactItem(
            Icons.access_time_rounded,
            'Operating Hours',
            contact.operatingHours,
          ),
        ],
      ),
    );
  }

  Widget _contactItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppFonts.poppins(
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppFonts.poppins(
                  size: 13.5,
                  weight: FontWeight.w500,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookNowButton() {
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.petSelect),
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Book an Appointment',
              style: AppFonts.parkinsans(
                size: 15.5,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

