import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/account/models/content_model.dart';
import 'package:shear_heaven_pet_spa/src/account/models/store_contact_info_model.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

class TermsConditionPageMobile extends StatefulWidget {
  const TermsConditionPageMobile({super.key});

  @override
  State<TermsConditionPageMobile> createState() => _TermsConditionPageMobileState();
}

class _TermsConditionPageMobileState extends State<TermsConditionPageMobile> {
  bool _isLoading = true;
  String? _errorMessage;
  ContentModel? _content;
  StoreContactInfo? _contactInfo;

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
        ServicesLocator.contentRepository.getTermsConditions(),
        ServicesLocator.contentRepository.getStoreContactInfo(),
      ]);

      if (!mounted) return;

      final terms = results[0] as ContentModel;
      final contact = results[1] as StoreContactInfo;

      setState(() {
        _content = terms.isNotEmpty ? terms : ContentModel.termsConditionsFallback();
        _contactInfo = contact;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _content = ContentModel.termsConditionsFallback();
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
            'Terms & Conditions',
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
        : ContentModel.termsConditionsFallback();

    final effectiveDate = content.effectiveDate ?? 'January 1, 2026';

    return RefreshIndicator(
      onRefresh: _loadContent,
      color: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderBanner(content, effectiveDate),
            const SizedBox(height: 18),
            _buildIntroCard(content),
            const SizedBox(height: 18),
            ...content.sections.map((sec) => _buildSectionCard(sec)),
            const SizedBox(height: 12),
            _buildFooterContactCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(ContentModel content, String effectiveDate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Effective: $effectiveDate',
                  style: AppFonts.poppins(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Terms & Conditions',
            style: AppFonts.parkinsans(
              size: 22,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content.subtitle ??
                'Please review our terms of service, appointment guidelines, and pet care policies.',
            style: AppFonts.poppins(
              size: 13,
              weight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard(ContentModel content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content.paragraphs.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
        ).toList(),
      ),
    );
  }

  Widget _buildSectionCard(ContentSection sec) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sec.heading,
            style: AppFonts.parkinsans(
              size: 15.5,
              weight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sec.body,
            style: AppFonts.poppins(
              size: 13,
              weight: FontWeight.w400,
              color: const Color(0xFF4B5563),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterContactCard() {
    final contact = _contactInfo ?? StoreContactInfo.defaultInfo();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Questions About These Terms?',
            style: AppFonts.parkinsans(
              size: 15.5,
              weight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'If you have questions regarding our salon policies, terms of service, or appointments, please reach out to us:',
            style: AppFonts.poppins(
              size: 12.5,
              weight: FontWeight.w400,
              color: const Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 16, color: Colors.black87),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contact.email,
                  style: AppFonts.poppins(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: Colors.black87),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contact.phone,
                  style: AppFonts.poppins(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

