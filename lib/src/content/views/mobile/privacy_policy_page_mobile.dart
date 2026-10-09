import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/account/models/content_model.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

class PrivacyPolicyPageMobile extends StatefulWidget {
  const PrivacyPolicyPageMobile({super.key});

  @override
  State<PrivacyPolicyPageMobile> createState() => _PrivacyPolicyPageMobileState();
}

class _PrivacyPolicyPageMobileState extends State<PrivacyPolicyPageMobile> {
  bool _isLoading = true;
  String? _errorMessage;
  ContentModel? _content;

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
      final data = await ServicesLocator.contentRepository.getPrivacyPolicy();
      if (!mounted) return;

      setState(() {
        _content = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load Privacy Policy.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed(RouteNames.settings);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          title: Text(
            'Privacy & Policy',
            style: AppFonts.parkinsans(size: 20, weight: FontWeight.w600, height: 26.949 / 20),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 21),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(RouteNames.settings);
              }
            },
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

    if (_errorMessage != null && _content == null) {
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
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loadContent,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final content = _content ?? ContentModel.privacyPolicyFallback();

    return RefreshIndicator(
      onRefresh: _loadContent,
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.title.isNotEmpty) ...[
              Text(
                content.title,
                style: AppFonts.parkinsans(size: 18, weight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 8),
            ],
            if (content.effectiveDate != null && content.effectiveDate!.isNotEmpty) ...[
              Text(
                'Effective Date: ${content.effectiveDate}',
                style: AppFonts.poppins(size: 12, weight: FontWeight.w500, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
            ],
            ...content.paragraphs.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    p,
                    style: AppFonts.poppins(
                      size: 14,
                      weight: FontWeight.w400,
                      color: Colors.black.withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),
                )),
            ...content.sections.map((sec) => _buildSection(sec)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ContentSection sec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sec.heading,
            style: AppFonts.parkinsans(
              size: 16,
              weight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sec.body,
            style: AppFonts.poppins(
              size: 14,
              weight: FontWeight.w400,
              color: Colors.black.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
