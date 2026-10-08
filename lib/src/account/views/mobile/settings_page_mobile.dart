import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';

class SettingsPageMobile extends StatelessWidget {
  const SettingsPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ServicesLocator.sessionService.isLoggedIn;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.loading) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing account deletion...'),
              duration: Duration(seconds: 2),
            ),
          );
        } else if (state.status == AuthStatus.unauthenticated &&
            state.message == 'Account deleted successfully') {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been deleted permanently.'),
              backgroundColor: Colors.black87,
            ),
          );
          context.goNamed(RouteNames.welcome);
        } else if (state.status == AuthStatus.authenticated &&
            state.message != null &&
            state.message!.isNotEmpty) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 60,
            titleSpacing: 0,
            centerTitle: false,
            title: Text(
              'Settings',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
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
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
            children: [
              _buildProfileCard(context),
              const SizedBox(height: 20),
              Text(
                'Account',
                style: AppFonts.parkinsans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              _buildAccountCard(context),
              const SizedBox(height: 20),
              Text(
                'About & Support',
                style: AppFonts.parkinsans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              _buildSupportCard(context),
              const SizedBox(height: 24),
              _buildAuthButton(context, isLoggedIn),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Shear Heaven App · v1.0.0',
                  style: AppFonts.poppins(
                    size: 12,
                    weight: FontWeight.w400,
                    color: const Color(0xFF888888),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButton(BuildContext context, bool isLoggedIn) {
    return GestureDetector(
      onTap: () {
        if (isLoggedIn) {
          _showLogoutDialog(context);
        } else {
          context.pushNamed(RouteNames.login);
        }
      },
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
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
              isLoggedIn ? 'Log Out' : 'Sign In / Register',
              style: AppFonts.parkinsans(
                size: 16,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            isLoggedIn
                ? SvgPicture.string(
                    '''<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
                      <polyline points="16 17 21 12 16 7"/>
                      <line x1="21" y1="12" x2="9" y2="12"/>
                    </svg>''',
                  )
                : const Icon(
                    Icons.login_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ],
        ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 58,
              height: 58,
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
                        size: 30,
                        color: Color(0xFF6B7280),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? 'Hi, $name' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.parkinsans(
                    size: 17,
                    weight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline,
                      size: 13,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          size: 12,
                          weight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppFonts.poppins(
                  size: 15,
                  weight: FontWeight.w500,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _item(
            SvgPicture.string(
              '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="9.5"/>
                <circle cx="12" cy="9.2" r="3.2"/>
                <path d="M6.2 18c1.3-2.5 3.3-3.8 5.8-3.8s4.5 1.3 5.8 3.8"/>
              </svg>''',
            ),
            'Profile',
            () => context.pushNamed(RouteNames.profile),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          _item(
            SvgPicture.string(
              '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <ellipse cx="4.8" cy="10.8" rx="2" ry="2.8" transform="rotate(-28 4.8 10.8)"/>
                <ellipse cx="9" cy="5.8" rx="2" ry="3"/>
                <ellipse cx="15" cy="5.8" rx="2" ry="3"/>
                <ellipse cx="19.2" cy="10.8" rx="2" ry="2.8" transform="rotate(28 19.2 10.8)"/>
                <path d="M12 12.5c-2.2 0-4.5-.8-5.8.5-1.3 1.3-1.4 3.5-.5 5 1.1 1.8 3.5 2.5 6.3 2.5s5.2-.7 6.3-2.5c.9-1.5.8-3.7-.5-5-1.3-1.3-3.6-.5-5.8-.5z"/>
              </svg>''',
            ),
            'My Pets',
            () => context.pushNamed(RouteNames.myPets),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          _item(
            SvgPicture.string(
              '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M4.5 7.5 L19 2.5 L21.5 7.5"/>
                <path d="M3 7.5 H21 C21.8 7.5 22.5 8.2 22.5 9 V10 C21.1 10 20 11.1 20 12.5 C20 13.9 21.1 15 22.5 15 V16 C22.5 16.8 21.8 17.5 21 17.5 H3 C2.2 17.5 1.5 16.8 1.5 16 V15 C2.9 15 4 13.9 4 12.5 C4 11.1 2.9 10 1.5 10 V9 C1.5 8.2 2.2 7.5 3 7.5 Z"/>
                <line x1="8.5" y1="9" x2="8.5" y2="16" stroke-dasharray="2 2"/>
              </svg>''',
            ),
            'My Bookings',
            () => context.goNamed(RouteNames.myBookings),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          _item(
            SvgPicture.string(
              '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M12 2.5a1.5 1.5 0 0 1 1.5 1.5v0.8h-3V4A1.5 1.5 0 0 1 12 2.5z"/>
                <path d="M12 4.8c-3.3 0-6 2.7-6 6v3.2c0 1.2-1 2-2 2.5h16c-1-.5-2-1.3-2-2.5V10.8c0-3.3-2.7-6-6-6z"/>
                <path d="M9.5 17.5a2.5 2.5 0 0 0 5 0"/>
                <path d="M3 10.5C2.3 8.8 2.7 6.8 4 5.5"/>
                <path d="M21 10.5c.7-1.7.3-3.7-1-5"/>
              </svg>''',
            ),
            'My Notification',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _item(
            SvgPicture.string(
              '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="9.5"/>
                <circle cx="12" cy="7" r="1.3" fill="black"/>
                <path d="M10.5 11.5 L12 11 V17 M10.5 17 H13.5"/>
              </svg>''',
            ),
            'About Us',
            () => context.pushNamed(RouteNames.aboutUs),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          _item(
            SvgPicture.string(
              '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M3.5 12C3.5 7.3 7.3 3.5 12 3.5s8.5 3.8 8.5 8.5"/>
                <rect x="1.5" y="10.5" width="3" height="5.5" rx="1.5" fill="white"/>
                <rect x="19.5" y="10.5" width="3" height="5.5" rx="1.5" fill="white"/>
                <path d="M21 15v1.5a4.5 4.5 0 0 1-4.5 4.5H15"/>
                <ellipse cx="13.5" cy="21" rx="1.8" ry="1.2" fill="black"/>
                <path d="M6.5 9.5a2.5 2.5 0 0 1 2.5-2.5h6a2.5 2.5 0 0 1 2.5 2.5v2.5a2.5 2.5 0 0 1-2.5 2.5h-4.5l-2.5 2.5v-2.5a2.5 2.5 0 0 1-1.5-2.5z"/>
                <circle cx="9.5" cy="10.8" r="0.8" fill="black"/>
                <circle cx="12" cy="10.8" r="0.8" fill="black"/>
                <circle cx="14.5" cy="10.8" r="0.8" fill="black"/>
              </svg>''',
            ),
            'Help & Support',
            () => context.pushNamed(RouteNames.helpSupport),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          _item(
            SvgPicture.string(
              '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M12 2.5 L4 5.5 V11.5 C4 16.5 7.5 20.5 12 22 C16.5 20.5 20 16.5 20 11.5 V5.5 Z"/>
                <circle cx="12" cy="9.5" r="2.2"/>
                <line x1="12" y1="11.7" x2="12" y2="15.5"/>
              </svg>''',
            ),
            'Privacy & Policy',
            () => context.pushNamed(RouteNames.privacyPolicy),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
          _item(
            SvgPicture.string(
              '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
                <path d="M4 6.5C3.2 6.5 2.5 7.2 2.5 8v12c0 1.1.9 2 2 2h12c.8 0 1.5-.7 1.5-1.5"/>
                <path d="M5.5 4.5A2 2 0 0 1 7.5 2.5h8l5 5v10a2 2 0 0 1-2 2h-11a2 2 0 0 1-2-2z"/>
                <path d="M15.5 2.5v5h5"/>
                <rect x="8" y="6.8" width="1.8" height="1.8" rx="0.3" fill="black"/>
                <line x1="11.5" y1="7.7" x2="14" y2="7.7" stroke-width="1.4"/>
                <rect x="8" y="9.8" width="1.8" height="1.8" rx="0.3" fill="black"/>
                <line x1="11.5" y1="10.7" x2="17.5" y2="10.7" stroke-width="1.4"/>
                <rect x="8" y="12.8" width="1.8" height="1.8" rx="0.3" fill="black"/>
                <line x1="11.5" y1="13.7" x2="17.5" y2="13.7" stroke-width="1.4"/>
                <path d="M7.8 16.5l1.4 1.4 2.2-2.2" stroke-width="1.5"/>
                <rect x="12.5" y="15.4" width="5.5" height="2.6" rx="1.3" stroke-width="1.3"/>
              </svg>''',
            ),
            'Terms & Condition',
            () => context.pushNamed(RouteNames.termsCondition),
          ),
          if (isLoggedIn) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
            _item(
              const Icon(Icons.delete_outline_rounded, size: 26, color: Color(0xFFDC2626)),
              'Delete Account',
              () => _showDeleteAccountDialog(context),
              textColor: const Color(0xFFDC2626),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: AppFonts.parkinsans(
                  size: 18,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete your account, saved pets, booking history, notifications, and chat records. This action is irreversible.',
                style: AppFonts.poppins(
                  size: 13,
                  color: const Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please enter your password to confirm:',
                style: AppFonts.parkinsans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Current Password',
                  hintStyle: AppFonts.poppins(size: 13, color: const Color(0xFF9CA3AF)),
                  errorText: errorMessage,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF6B7280),
                      size: 20,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: AppFonts.parkinsans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                final pwd = passwordController.text.trim();
                if (pwd.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Password is required to delete account';
                  });
                  return;
                }
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(DeleteAccountSubmitted(password: pwd));
              },
              child: Text(
                'Delete Forever',
                style: AppFonts.parkinsans(
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout',
            style: AppFonts.parkinsans(
              size: 20,
              weight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: AppFonts.poppins(
              size: 14,
              weight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.black12),
                ),
              ),
              child: Text(
                'Cancel',
                style: AppFonts.parkinsans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(const LogoutSubmitted());
                context.goNamed(RouteNames.login);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Logout',
                style: AppFonts.parkinsans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
