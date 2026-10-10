import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_formatters.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/password_requirements_view.dart';

class ProfilePageMobile extends StatefulWidget {
  const ProfilePageMobile({super.key});

  @override
  State<ProfilePageMobile> createState() => _ProfilePageMobileState();
}

class _ProfilePageMobileState extends State<ProfilePageMobile> {
  final Logger _log = Logger();

  // Profile fields
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _mobileCtrl  = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _gender     = 'Male';
  String? _photoUrl;
  String? _pickedPhotoPath;

  // Change-password fields (inline with OTP verification)
  final _pwCtrl        = TextEditingController();
  final _cpwCtrl       = TextEditingController();
  final _otpCtrl       = TextEditingController();
  final _pwFocusNode   = FocusNode();
  final _otpFocusNode  = FocusNode();
  bool _showPwSection  = false;
  bool _otpSent        = false;
  bool _sendingOtp     = false;
  bool _showPw         = false;
  bool _showCpw        = false;
  bool _changingPw     = false;
  String? _pwError;
  String? _pwSuccess;

  // Page state
  bool    _loading       = true;
  bool    _saving        = false;
  String? _errorMsg;
  String? _successMsg;
  bool    _emailVerified = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _pwCtrl.dispose();
    _cpwCtrl.dispose();
    _otpCtrl.dispose();
    _pwFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // ── GET /api/auth/profile ─────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    if (!ServicesLocator.sessionService.isLoggedIn) {
      if (mounted) {
        setState(() {
          _loading  = false;
          _errorMsg = null;
        });
      }
      return;
    }
    setState(() {
      _loading  = true;
      _errorMsg = null;
    });
    try {
      _log.d('ProfilePage::_loadProfile::GET /api/auth/profile');
      final data = await ServicesLocator.authRepository.getProfile();
      if (!mounted) return;
      final photo = data['profilePictureUrl']?.toString() ??
          data['profilePicture']?.toString() ??
          data['avatar']?.toString() ??
          data['photoUrl']?.toString() ??
          data['image']?.toString();
      setState(() {
        _nameCtrl.text    = data['name']?.toString()    ?? '';
        _emailCtrl.text   = data['email']?.toString()   ?? '';
        _mobileCtrl.text  = data['mobile']?.toString()  ?? '';
        _addressCtrl.text = data['address']?.toString() ?? data['homeAddress']?.toString() ?? '';
        final g           = data['gender']?.toString();
        if (g != null && (g == 'Female' || g == 'female')) {
          _gender = 'Female';
        } else {
          _gender = 'Male';
        }
        _emailVerified   = data['emailVerified'] == true;
        _photoUrl        = (photo != null && photo.isNotEmpty) ? photo : null;
        _pickedPhotoPath = null;
        _loading         = false;
      });
    } catch (e) {
      _log.e('ProfilePage::_loadProfile::Error: $e');
      if (!mounted) return;
      final user        = ServicesLocator.sessionService.getSessionUser();
      _nameCtrl.text    = user?['name']?.toString()    ?? '';
      _emailCtrl.text   = user?['email']?.toString()   ?? '';
      _mobileCtrl.text  = user?['mobile']?.toString()  ?? '';
      _addressCtrl.text = user?['address']?.toString() ?? user?['homeAddress']?.toString() ?? '';
      final g           = user?['gender']?.toString();
      if (g != null && (g == 'Female' || g == 'female')) {
        _gender = 'Female';
      } else {
        _gender = 'Male';
      }
      final photo       = user?['profilePictureUrl']?.toString() ??
          user?['profilePicture']?.toString() ??
          user?['avatar']?.toString() ??
          user?['photoUrl']?.toString() ??
          user?['image']?.toString();
      setState(() {
        _photoUrl = (photo != null && photo.isNotEmpty) ? photo : null;
        _loading  = false;
        _errorMsg = null;
      });
    }
  }

  // ── PUT /api/auth/profile ─────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final name   = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (name.isEmpty) {
      setState(() => _errorMsg = 'Name cannot be empty.');
      return;
    }
    setState(() {
      _saving     = true;
      _errorMsg   = null;
      _successMsg = null;
    });

    try {
      _log.d('ProfilePage::_saveProfile::name=$name mobile=$mobile photoPath=$_pickedPhotoPath');
      final updated = await ServicesLocator.authRepository.updateProfilePut(
        name     : name,
        mobile   : mobile.isNotEmpty ? mobile : null,
        photoPath: _pickedPhotoPath,
      );
      if (!mounted) return;
      final newPhoto = updated['profilePictureUrl']?.toString() ??
          updated['profilePicture']?.toString() ??
          updated['avatar']?.toString() ??
          updated['photoUrl']?.toString();
      setState(() {
        _saving     = false;
        _successMsg = 'Profile updated successfully.';
        if (newPhoto != null && newPhoto.isNotEmpty) {
          _photoUrl = newPhoto;
        } else if (_pickedPhotoPath != null) {
          _photoUrl = _pickedPhotoPath;
        }
        _pickedPhotoPath = null;
      });
    } catch (e) {
      _log.e('ProfilePage::_saveProfile::Error: $e');
      if (!mounted) return;
      setState(() {
        _saving   = false;
        _errorMsg = _msg(e);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _pickedPhotoPath = picked.path;
          _errorMsg = null;
        });
      }
    } catch (e) {
      _log.e('ProfilePage::_pickImage::Error: $e');
      if (mounted) {
        setState(() => _errorMsg = 'Could not access image: $e');
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Profile Photo',
                  style: AppFonts.parkinsans(
                    size: 18,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a photo for your profile',
                  style: AppFonts.poppins(
                    size: 13,
                    color: const Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: Color(0xFF111827), size: 22),
                  ),
                  title: Text('Take Photo',
                      style: AppFonts.poppins(
                          size: 15,
                          weight: FontWeight.w600,
                          color: const Color(0xFF111827))),
                  subtitle: Text('Use camera to take a photo',
                      style: AppFonts.poppins(
                          size: 12, color: const Color(0xFF9CA3AF))),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_outlined,
                        color: Color(0xFF111827), size: 22),
                  ),
                  title: Text('Choose from Gallery',
                      style: AppFonts.poppins(
                          size: 15,
                          weight: FontWeight.w600,
                          color: const Color(0xFF111827))),
                  subtitle: Text('Select an image from device',
                      style: AppFonts.poppins(
                          size: 12, color: const Color(0xFF9CA3AF))),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_pickedPhotoPath != null || (_photoUrl != null && _photoUrl!.isNotEmpty)) ...[
                  const SizedBox(height: 6),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 22),
                    ),
                    title: Text('Remove Photo',
                        style: AppFonts.poppins(
                            size: 15,
                            weight: FontWeight.w600,
                            color: const Color(0xFFEF4444))),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _pickedPhotoPath = null;
                        _photoUrl = null;
                      });
                      final user = Map<String, dynamic>.from(
                        ServicesLocator.sessionService.getSessionUser() ?? {},
                      );
                      user.remove('profilePictureUrl');
                      user.remove('profilePicture');
                      await ServicesLocator.sessionService.saveSession(user);
                    },
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Send OTP for password reset ──────────────────────────────────────────
  Future<void> _sendPasswordOtp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _pwError = 'A valid email address is required to receive OTP.');
      return;
    }

    setState(() {
      _sendingOtp = true;
      _pwError    = null;
      _pwSuccess  = null;
    });

    try {
      _log.d('ProfilePage::_sendPasswordOtp::Sending OTP to $email');
      await ServicesLocator.authRepository.forgotPasswordCheck(email);
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _otpSent    = true;
        _otpCtrl.clear();
        _pwSuccess  = 'Verification code sent to $email';
      });
      ToastUtil.showSuccessToast(context, 'Verification code sent to your email.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNode.requestFocus();
      });
    } catch (e) {
      _log.e('ProfilePage::_sendPasswordOtp::Error: $e');
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _pwError    = _msg(e);
      });
    }
  }

  // ── POST /api/auth/reset-password with OTP ───────────────────────────────
  Future<void> _changePassword() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final otp   = _otpCtrl.text.trim();
    final pw    = _pwCtrl.text;
    final cpw   = _cpwCtrl.text;

    if (otp.isEmpty || otp.length < 6) {
      setState(() => _pwError = 'Please enter the 6-digit OTP sent to your email.');
      return;
    }

    final missingMsg = PasswordValidator.getFirstMissingMessage(pw);
    if (missingMsg != null) {
      setState(() => _pwError = missingMsg);
      return;
    }
    if (pw != cpw) {
      setState(() => _pwError = 'Passwords do not match.');
      return;
    }

    setState(() {
      _changingPw = true;
      _pwError    = null;
      _pwSuccess  = null;
    });

    try {
      _log.d('ProfilePage::_changePassword::email=$email with OTP');
      await ServicesLocator.authRepository.resetPassword(
        email          : email,
        otp            : otp,
        password       : pw,
        confirmPassword: cpw,
      );
      if (!mounted) return;
      _otpCtrl.clear();
      _pwCtrl.clear();
      _cpwCtrl.clear();
      setState(() {
        _changingPw    = false;
        _showPwSection = false;
        _otpSent       = false;
        _pwSuccess     = 'Password updated successfully.';
      });
      ToastUtil.showSuccessToast(context, 'Password updated successfully.');
    } catch (e) {
      _log.e('ProfilePage::_changePassword::Error: $e');
      if (!mounted) return;
      setState(() {
        _changingPw = false;
        _pwError    = _msg(e);
      });
    }
  }

  String _msg(dynamic e) {
    final s = e.toString();
    return s.contains('Exception:')
        ? s.replaceAll('Exception:', '').trim()
        : 'Something went wrong. Please try again.';
  }

  Widget _buildAvatarContent() {
    if (_pickedPhotoPath != null && _pickedPhotoPath!.isNotEmpty) {
      return Image.file(
        File(_pickedPhotoPath!),
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.person_outline,
          size: 44,
          color: Color(0xFF374151),
        ),
      );
    }

    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      final raw = _photoUrl!;
      if (!raw.startsWith('http') && File(raw).existsSync()) {
        return Image.file(
          File(raw),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.person_outline,
            size: 44,
            color: Color(0xFF374151),
          ),
        );
      }
      final fullUrl = raw.startsWith('http')
          ? raw
          : '${Constants.app.BASE_URL}${raw.startsWith('/') ? '' : '/'}$raw';
      return Image.network(
        fullUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.person_outline,
          size: 44,
          color: Color(0xFF374151),
        ),
      );
    }

    return const Icon(
      Icons.person_outline,
      size: 44,
      color: Color(0xFF374151),
    );
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final body = PopScope(
      canPop: _canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor      : Colors.white,
        surfaceTintColor     : Colors.transparent,
        elevation            : 0,
        titleSpacing         : 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 24),
          onPressed: () => _handleBack(context),
        ),
        title: Text('My Profile',
            style: AppFonts.parkinsans(
                size  : 20,
                weight: FontWeight.w700,
                color : const Color(0xFF111827))),
        actions: [
          IconButton(
            icon    : const Icon(Icons.refresh, color: Color(0xFF111827)),
            tooltip : 'Refresh',
            onPressed: _loading ? null : _loadProfile,
          ),
        ],
      ),
      body: !ServicesLocator.sessionService.isLoggedIn
          ? _buildGuestState()
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF111827), strokeWidth: 2.5))
              : SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
                child  : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // ── Avatar ──────────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _showImagePickerModal,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width : 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDEFEF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF111827).withValues(alpha: 0.15),
                                  width: 2.5,
                                ),
                              ),
                              child: ClipOval(
                                child: _buildAvatarContent(),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width : 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_emailVerified) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified,
                                size: 14, color: Color(0xFF111827)),
                            const SizedBox(width: 4),
                            Text('Email Verified',
                                style: AppFonts.poppins(
                                  size  : 12,
                                  weight: FontWeight.w500,
                                  color : const Color(0xFF111827),
                                )),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── Profile error / success ─────────────────────────
                    if (_errorMsg != null) ...[
                      _Banner(msg: _errorMsg!, isError: true),
                      const SizedBox(height: 14),
                    ],
                    if (_successMsg != null) ...[
                      _Banner(msg: _successMsg!, isError: false),
                      const SizedBox(height: 14),
                    ],

                    // ── Full Name ───────────────────────────────────────
                    _Field(
                      label     : 'Full Name',
                      controller: _nameCtrl,
                      hint      : 'Your name',
                    ),
                    const SizedBox(height: 14),

                    // ── Email (read-only) ───────────────────────────────
                    _Field(
                      label    : 'Email Address',
                      controller: _emailCtrl,
                      hint     : 'Email',
                      readOnly : true,
                      trailing : const Icon(Icons.lock_outline,
                          size: 16, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text('Email address cannot be changed.',
                          style: AppFonts.poppins(
                              size : 11,
                              color: const Color(0xFF9CA3AF))),
                    ),
                    const SizedBox(height: 14),

                    // ── Phone Number ────────────────────────────────────
                    _Field(
                      label          : 'Phone Number',
                      controller     : _mobileCtrl,
                      hint           : '(817) 123-4567',
                      type           : TextInputType.phone,
                      inputFormatters: const [
                        UsPhoneInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Gender ──────────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender',
                          style: AppFonts.poppins(
                            size  : 14,
                            weight: FontWeight.w500,
                            color : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _gender = 'Male'),
                                child: Container(
                                  height   : 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _gender == 'Male'
                                        ? const Color(0xFF111827)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(60),
                                    border: Border.all(
                                      color: const Color(0xFF111827),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    'Male',
                                    style: AppFonts.poppins(
                                      size  : 15,
                                      weight: FontWeight.w600,
                                      color : _gender == 'Male'
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _gender = 'Female'),
                                child: Container(
                                  height   : 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _gender == 'Female'
                                        ? const Color(0xFF111827)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(60),
                                    border: Border.all(
                                      color: const Color(0xFF111827),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    'Female',
                                    style: AppFonts.poppins(
                                      size  : 15,
                                      weight: FontWeight.w600,
                                      color : _gender == 'Female'
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Home Address (Optional) ─────────────────────────
                    _Field(
                      label     : 'Home Address (Optional)',
                      controller: _addressCtrl,
                      hint      : 'Add Your Address',
                    ),
                    const SizedBox(height: 20),

                    // ── Change Password (inline, no navigation) ─────────
                    _buildChangePasswordSection(),
                    const SizedBox(height: 14),

                    // ── Save Changes ────────────────────────────────────
                    GestureDetector(
                      onTap: _saving ? null : _saveProfile,
                      child: Container(
                        height    : 52,
                        alignment : Alignment.center,
                        decoration: BoxDecoration(
                          gradient: _saving
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF2B2B2B),
                                    Color(0xFF141414),
                                  ],
                                ),
                          color       : _saving
                              ? const Color(0xFF6B7280)
                              : null,
                          borderRadius: BorderRadius.circular(60),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Save Changes',
                                      style: AppFonts.parkinsans(
                                          size  : 16,
                                          weight: FontWeight.w700,
                                          color : Colors.white)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.save_outlined,
                                      size: 18, color: Colors.white),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Delete Account Button ──
                    SizedBox(
                      height: 48,
                      child: TextButton.icon(
                        onPressed: _showDeleteAccountDialog,
                        icon: const Icon(Icons.delete_forever_outlined, color: Colors.red, size: 20),
                        label: Text(
                          'Delete Account',
                          style: AppFonts.poppins(
                            size: 15,
                            weight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(60),
                            side: const BorderSide(color: Color(0xFFFCA5A5), width: 1),
                          ),
                          backgroundColor: const Color(0xFFFEF2F2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    ),
    );

    try {
      final authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
      return BlocListener<AuthBloc, AuthState>(
        bloc: authBloc,
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
              state.message.isNotEmpty) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
          }
        },
        child: body,
      );
    } catch (_) {
      return body;
    }
  }

  void _showDeleteAccountDialog() {
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

  Widget _buildGuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 48,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign In to Your Account',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in or create an account to view and update your profile details.',
              style: AppFonts.poppins(
                size: 14,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(60),
                  ),
                ),
                onPressed: () => context.pushNamed(RouteNames.login),
                child: Text(
                  'Sign In / Register',
                  style: AppFonts.parkinsans(
                    size: 16,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Change-password inline section ───────────────────────────────────────
  Widget _buildChangePasswordSection() {
    final email = _emailCtrl.text.trim().isNotEmpty
        ? _emailCtrl.text.trim()
        : (ServicesLocator.sessionService.getSessionUser()?['email']?.toString() ?? 'your email');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle header button
        GestureDetector(
          onTap: () => setState(() {
            _showPwSection = !_showPwSection;
            _pwError   = null;
            _pwSuccess = null;
          }),
          child: Container(
            height    : 50,
            alignment : Alignment.center,
            decoration: BoxDecoration(
              color       : Colors.white,
              borderRadius: BorderRadius.circular(60),
              border      : Border.all(
                  color: const Color(0xFF111827), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Change Password',
                    style: AppFonts.parkinsans(
                        size  : 15,
                        weight: FontWeight.w700,
                        color : const Color(0xFF111827))),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns   : _showPwSection ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child   : const Icon(Icons.keyboard_arrow_down,
                      size: 20, color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
        ),

        // Expandable section
        AnimatedSize(
          duration : const Duration(milliseconds: 260),
          curve    : Curves.easeInOut,
          alignment: Alignment.topCenter,
          child    : _showPwSection
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section error / success
                      if (_pwError != null) ...[
                        _Banner(msg: _pwError!, isError: true),
                        const SizedBox(height: 12),
                      ],
                      if (_pwSuccess != null) ...[
                        _Banner(msg: _pwSuccess!, isError: false),
                        const SizedBox(height: 12),
                      ],

                      if (!_otpSent) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shield_outlined,
                                      size: 18, color: Color(0xFF111827)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Security Verification',
                                    style: AppFonts.parkinsans(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  style: AppFonts.poppins(
                                    size: 13,
                                    color: const Color(0xFF4B5563),
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text:
                                          'To change your password, we will send a 6-digit verification code to:\n',
                                    ),
                                    TextSpan(
                                      text: email,
                                      style: AppFonts.poppins(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        GestureDetector(
                          onTap: _sendingOtp ? null : _sendPasswordOtp,
                          child: Container(
                            height    : 50,
                            alignment : Alignment.center,
                            decoration: BoxDecoration(
                              color       : _sendingOtp
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: _sendingOtp
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        color      : Colors.white,
                                        strokeWidth: 2.5))
                                : Text('Send Verification Code',
                                    style: AppFonts.parkinsans(
                                        size  : 15,
                                        weight: FontWeight.w700,
                                        color : Colors.white)),
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Enter Verification Code',
                              style: AppFonts.poppins(
                                size: 13,
                                weight: FontWeight.w500,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            GestureDetector(
                              onTap: _sendingOtp ? null : _sendPasswordOtp,
                              child: Text(
                                _sendingOtp ? 'Sending...' : 'Resend Code',
                                style: AppFonts.poppins(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ).copyWith(decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _Field(
                          label     : '',
                          controller: _otpCtrl,
                          focusNode : _otpFocusNode,
                          hint      : 'Enter 6-digit OTP',
                          type      : TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _Field(
                          label     : 'New Password',
                          controller: _pwCtrl,
                          focusNode : _pwFocusNode,
                          hint      : '••••••••••••••••••••',
                          type      : TextInputType.visiblePassword,
                          obscure   : !_showPw,
                          trailing  : IconButton(
                            icon: Icon(
                              _showPw
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size : 20,
                              color: const Color(0xFF6B7280),
                            ),
                            onPressed: () =>
                                setState(() => _showPw = !_showPw),
                          ),
                        ),

                        PasswordRequirementsView(
                          controller: _pwCtrl,
                          focusNode : _pwFocusNode,
                        ),
                        const SizedBox(height: 14),

                        _Field(
                          label     : 'Confirm New Password',
                          controller: _cpwCtrl,
                          hint      : '••••••••••••••••••••',
                          type      : TextInputType.visiblePassword,
                          obscure   : !_showCpw,
                          trailing  : IconButton(
                            icon: Icon(
                              _showCpw
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size : 20,
                              color: const Color(0xFF6B7280),
                            ),
                            onPressed: () =>
                                setState(() => _showCpw = !_showCpw),
                          ),
                        ),
                        const SizedBox(height: 16),

                        GestureDetector(
                          onTap: _changingPw ? null : _changePassword,
                          child: Container(
                            height    : 50,
                            alignment : Alignment.center,
                            decoration: BoxDecoration(
                              color       : _changingPw
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: _changingPw
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        color      : Colors.white,
                                        strokeWidth: 2.5))
                                : Text('Update Password',
                                    style: AppFonts.parkinsans(
                                        size  : 15,
                                        weight: FontWeight.w700,
                                        color : Colors.white)),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable pill text field
// ─────────────────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String                label;
  final TextEditingController controller;
  final String                hint;
  final TextInputType         type;
  final bool                  readOnly;
  final bool                  obscure;
  final FocusNode?            focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final Widget?               trailing;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.type            = TextInputType.text,
    this.readOnly        = false,
    this.obscure         = false,
    this.focusNode,
    this.inputFormatters,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label,
              style: AppFonts.poppins(
                  size  : 14,
                  weight: FontWeight.w500,
                  color : const Color(0xFF111827))),
          const SizedBox(height: 6),
        ],
        Container(
          height    : 52,
          padding   : const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color       : readOnly ? const Color(0xFFF9FAFB) : Colors.white,
            borderRadius: BorderRadius.circular(60),
            border      : Border.all(
              color: readOnly
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFF111827),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller     : controller,
                  focusNode      : focusNode,
                  keyboardType   : type,
                  readOnly       : readOnly,
                  obscureText    : obscure,
                  inputFormatters: inputFormatters,
                  style          : AppFonts.poppins(
                      size  : 15,
                      weight: FontWeight.w600,
                      color : const Color(0xFF111827)),
                  decoration: InputDecoration(
                    isDense  : true,
                    border   : InputBorder.none,
                    hintText : hint,
                    hintStyle: AppFonts.poppins(
                        size  : 15,
                        weight: FontWeight.w400,
                        color : const Color(0xFF9CA3AF)),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info / error banner
// ─────────────────────────────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  final String msg;
  final bool   isError;
  const _Banner({required this.msg, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding   : const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color       : isError
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : Icons.check_circle_outline,
            size : 16,
            color: isError
                ? const Color(0xFF991B1B)
                : const Color(0xFF166534),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: AppFonts.poppins(
                    size : 13,
                    color: isError
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF166534))),
          ),
        ],
      ),
    );
  }
}
