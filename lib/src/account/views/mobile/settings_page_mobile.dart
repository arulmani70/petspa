import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';

class SettingsPageMobile extends StatelessWidget {
  const SettingsPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(67),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 67,
            titleSpacing: 0,
            title: Text(
              'Settings',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w600,
                height: 26.949 / 20,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 21),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.home);
                }
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(17, 18, 17, 130),
          children: [
            _buildProfileCard(context),
            const SizedBox(height: 22),
            Text(
              'ACCOUNT',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w400,
                height: 22 / 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            _buildAccountCard(context),
            const SizedBox(height: 22),
            Text(
              'ABOUT & SUPPORT',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w400,
                height: 22 / 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            _buildSupportCard(context),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Follow Us On Social Media',
                style: AppFonts.poppins(
                  size: 16,
                  weight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _socialIcon(
                  'assets/images/fi_2111463_1_2515.svg',
                  Icons.facebook,
                ),
                const SizedBox(width: 15),
                _socialIcon(
                  'assets/images/fi_174855_1_2517.svg',
                  Icons.camera_alt,
                ),
                const SizedBox(width: 15),
                _socialIcon('assets/images/fi_3256013_1_2519.svg', Icons.chat),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Shear Heaven App · v1.0.0',
                style: AppFonts.poppins(
                  size: 14,
                  weight: FontWeight.w400,
                  color: const Color(0xFF9F9F9F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(String asset, IconData fallback) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        asset,
        width: 20,
        height: 20,
        errorBuilder: (context, error, stackTrace) =>
            Icon(fallback, size: 20, color: Colors.black),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Account',
          style: AppFonts.parkinsans(
            size: 18,
            weight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete your account? All your personal profile data, pet records, and booking history will be permanently removed. This action cannot be undone.',
          style: AppFonts.poppins(
            size: 14,
            color: const Color(0xFF374151),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(const DeleteAccountSubmitted());
              context.goNamed(RouteNames.welcome);
            },
            child: Text(
              'Delete Account',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final isLoggedIn = ServicesLocator.sessionService.isLoggedIn;
    final user = ServicesLocator.sessionService.getSessionUser();
    final name = isLoggedIn
        ? (user?[Constants.database.COLUMN_NAME]?.toString() ?? 'Alexander')
        : 'Guest User';
    final email = isLoggedIn
        ? (user?[Constants.database.COLUMN_EMAIL]?.toString() ?? 'alexander@gmail.com')
        : 'Sign in to access your account & bookings';

    return Container(
      key: const Key('settings_profile_card'),
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 63,
              height: 63,
              child: isLoggedIn
                  ? FigmaImage(
                      asset: 'assets/images/common/avatar.png',
                      fit: BoxFit.cover,
                      fallback: Container(
                        color: const Color(0xFFEEEEEE),
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                          style: AppFonts.poppins(size: 24, weight: FontWeight.w600),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFF3F4F6),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_outline,
                        size: 32,
                        color: Color(0xFF6B7280),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? 'Hi, $name' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    size: 18,
                    weight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isLoggedIn ? Icons.mail_outline : Icons.info_outline,
                      size: 11,
                      color: const Color(0xFF343434),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w300,
                          color: const Color(0xFF343434),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isLoggedIn)
            GestureDetector(
              onTap: () => context.pushNamed(RouteNames.login),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Sign In',
                  style: AppFonts.parkinsans(
                    size: 12,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _item(Widget iconWidget, String label, VoidCallback onTap, {Color? textColor}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 32,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 55,
              child: Align(alignment: Alignment.centerLeft, child: iconWidget),
            ),
            Expanded(
              child: Text(
                label,
                style: AppFonts.poppins(
                  size: 18,
                  weight: FontWeight.w400,
                  height: 1.0,
                  color: textColor ?? Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    return Container(
      key: const Key('settings_account_card'),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _item(
            SvgPicture.asset(
              'assets/images/common/fi_1144760_1_2311.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                Colors.black,
                BlendMode.srcIn,
              ),
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.person_outline,
                size: 32,
                color: Colors.black,
              ),
            ),
            'Profile',
            () => context.pushNamed(RouteNames.profile),
          ),
          const SizedBox(height: 19),
          _item(
            const Icon(Icons.pets, size: 27, color: Colors.black),
            'My Pets',
            () => context.pushNamed(RouteNames.myPets),
          ),
          const SizedBox(height: 19),
          _item(
            const Icon(Icons.calendar_today, size: 27, color: Colors.black),
            'My Bookings',
            () => context.goNamed(RouteNames.myBookings),
          ),
          const SizedBox(height: 19),
          _item(
            const Icon(Icons.notifications_none, size: 27, color: Colors.black),
            'Notifications',
            () => context.pushNamed(RouteNames.notifications),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    final isLoggedIn = ServicesLocator.sessionService.isLoggedIn;

    return Container(
      key: const Key('settings_support_card'),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _item(
            const Icon(Icons.info_outline, size: 27, color: Colors.black),
            'About Us',
            () => context.pushNamed(RouteNames.aboutUs),
          ),
          const SizedBox(height: 19),
          _item(
            const Icon(
              Icons.headset_mic_outlined,
              size: 27,
              color: Colors.black,
            ),
            'Help & Support',
            () => context.pushNamed(RouteNames.helpSupport),
          ),
          const SizedBox(height: 19),
          _item(
            const Icon(
              Icons.privacy_tip_outlined,
              size: 27,
              color: Colors.black,
            ),
            'Privacy & Policy',
            () => context.pushNamed(RouteNames.privacyPolicy),
          ),
          const SizedBox(height: 19),
          _item(
            const Icon(
              Icons.description_outlined,
              size: 27,
              color: Colors.black,
            ),
            'Terms & Condition',
            () => context.pushNamed(RouteNames.termsCondition),
          ),
          if (isLoggedIn) ...[
            const SizedBox(height: 19),
            _item(
              const Icon(Icons.logout, size: 27, color: Colors.red),
              'Log Out',
              () {
                context.read<AuthBloc>().add(const LogoutSubmitted());
                context.go('/${RouteNames.login}');
              },
              textColor: Colors.red,
            ),
            const SizedBox(height: 19),
            _item(
              const Icon(Icons.delete_forever_outlined, size: 27, color: Colors.red),
              'Delete Account',
              () => _showDeleteAccountDialog(context),
              textColor: Colors.red,
            ),
          ] else ...[
            const SizedBox(height: 19),
            _item(
              const Icon(Icons.login, size: 27, color: Color(0xFF111827)),
              'Log In / Register',
              () => context.pushNamed(RouteNames.login),
            ),
          ],
        ],
      ),
    );
  }
}


