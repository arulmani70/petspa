import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/account/models/content_model.dart';
import 'package:shear_heaven_pet_spa/src/account/models/store_contact_info_model.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

class HelpSupportPageMobile extends StatefulWidget {
  const HelpSupportPageMobile({super.key});

  @override
  State<HelpSupportPageMobile> createState() => _HelpSupportPageMobileState();
}

class _HelpSupportPageMobileState extends State<HelpSupportPageMobile> {
  bool _isLoading = true;
  String? _errorMessage;
  StoreContactInfo? _contactInfo;
  ContentModel? _helpContent;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final contactFuture = ServicesLocator.contentRepository.getStoreContactInfo();
      final helpFuture = ServicesLocator.contentRepository.getHelpSupport();

      final results = await Future.wait([contactFuture, helpFuture]);
      if (!mounted) return;

      setState(() {
        _contactInfo = results[0] as StoreContactInfo;
        _helpContent = results[1] as ContentModel;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load Help & Support information.';
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
            'Help & Support',
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

    if (_errorMessage != null && _contactInfo == null) {
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
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final info = _contactInfo ?? StoreContactInfo.defaultInfo();
    final help = _helpContent ?? ContentModel.helpSupportFallback();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Details',
              style: AppFonts.parkinsans(size: 18, weight: FontWeight.w700, color: Colors.black),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.location_on_outlined,
              title: 'Store Location',
              value: info.address,
            ),
            const SizedBox(height: 10),
            _buildContactCard(
              icon: Icons.phone_outlined,
              title: 'Phone Number',
              value: info.phone,
            ),
            const SizedBox(height: 10),
            _buildContactCard(
              icon: Icons.email_outlined,
              title: 'Email Address',
              value: info.email,
            ),
            const SizedBox(height: 10),
            _buildContactCard(
              icon: Icons.access_time_outlined,
              title: 'Operating Hours',
              value: info.operatingHours,
            ),
            const SizedBox(height: 24),
            Text(
              help.title.isNotEmpty ? help.title : 'Frequently Asked Questions',
              style: AppFonts.parkinsans(size: 18, weight: FontWeight.w700, color: Colors.black),
            ),
            const SizedBox(height: 12),
            ...help.paragraphs.map((p) => Padding(
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF0F766E)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.poppins(size: 12, weight: FontWeight.w500, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppFonts.poppins(size: 14, weight: FontWeight.w600, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
