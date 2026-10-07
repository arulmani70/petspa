import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_formatters.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/password_requirements_view.dart';

class GroomerRegisterPageMobile extends StatefulWidget {
  final String? tempLoginId;
  final String? tempPassword;

  const GroomerRegisterPageMobile({
    super.key,
    this.tempLoginId,
    this.tempPassword,
  });

  @override
  State<GroomerRegisterPageMobile> createState() => _GroomerRegisterPageMobileState();
}

class _GroomerRegisterPageMobileState extends State<GroomerRegisterPageMobile> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.tempLoginId != null && widget.tempPassword != null) {
      ServicesLocator.sessionService.saveTempGroomerCredentials(
        tempLoginId: widget.tempLoginId!,
        tempPassword: widget.tempPassword!,
      );
    }
    final groomer = ServicesLocator.groomerRegisterRepository.getCurrentGroomer();
    final savedTempLoginId = widget.tempLoginId ?? ServicesLocator.sessionService.getTempGroomerLoginId();
    if (groomer != null) {
      _fullNameController.text = groomer.fullName;
      _emailController.text = groomer.email;
      if (groomer.mobile.isNotEmpty) {
        _phoneController.text = UsPhoneInputFormatter.formatDigits(groomer.mobile);
      }
    } else if (savedTempLoginId != null && savedTempLoginId.isNotEmpty) {
      _emailController.text = savedTempLoginId;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteSetup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your Email / Login ID.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password.';
      });
      return;
    }

    final missingPwMsg = PasswordValidator.getFirstMissingMessage(password);
    if (missingPwMsg != null) {
      setState(() {
        _errorMessage = missingPwMsg;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match. Please verify.';
      });
      return;
    }

    if (phone.isNotEmpty) {
      final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
      final cleanDigits = (phoneDigits.length == 11 && phoneDigits.startsWith('1'))
          ? phoneDigits.substring(1)
          : phoneDigits;
      if (cleanDigits.length != 10) {
        setState(() {
          _errorMessage = 'Please enter a valid 10-digit US phone number.';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groomer = ServicesLocator.groomerRegisterRepository.getCurrentGroomer();
      final storedTempLoginId = widget.tempLoginId ?? ServicesLocator.sessionService.getTempGroomerLoginId();
      final storedTempPassword = widget.tempPassword ?? await ServicesLocator.sessionService.getTempGroomerPassword();

      final tempLoginId = (widget.tempLoginId != null && widget.tempLoginId!.trim().isNotEmpty)
          ? widget.tempLoginId!.trim()
          : (storedTempLoginId?.trim().isNotEmpty == true
              ? storedTempLoginId!.trim()
              : (groomer?.email.trim().isNotEmpty == true
                  ? groomer!.email.trim()
                  : (email.isNotEmpty ? email : '')));

      final tempPassword = (widget.tempPassword != null && widget.tempPassword!.isNotEmpty)
          ? widget.tempPassword!
          : (storedTempPassword?.isNotEmpty == true
              ? storedTempPassword!
              : '');

      if (tempPassword.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Temporary password is missing. Please log in again to continue setup.';
          _isLoading = false;
        });
        return;
      }

      if (tempLoginId.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Temporary Login ID is missing. Please log in again to continue setup.';
          _isLoading = false;
        });
        return;
      }

      await ServicesLocator.groomerRegisterRepository.setupAccount(
        tempLoginId: tempLoginId,
        tempPassword: tempPassword,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );

      await ServicesLocator.sessionService.clearTempGroomerCredentials();

      if (fullName.isNotEmpty || phone.isNotEmpty) {
        final names = fullName.split(' ');
        final firstName = names.isNotEmpty ? names.first : '';
        final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
        await ServicesLocator.groomerRegisterRepository.updateProfile(
          firstName: firstName.isNotEmpty ? firstName : null,
          lastName: lastName.isNotEmpty ? lastName : null,
          mobile: phone.isNotEmpty ? phone : null,
        );
      }

      if (!mounted) return;
      try {
        context.goNamed(RouteNames.groomerHome);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final err = e.toString().replaceAll('Exception:', '').trim();
        _errorMessage = err.isNotEmpty ? err : 'Setup failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FD),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/common/welcome_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFFF0F8FD)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.70),
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.75),
                    Colors.white.withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // Logo
                  Center(
                    child: SvgPicture.asset(
                      'assets/images/common/logo.svg',
                      width: 146,
                      height: 82,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Complete Your Setup',
                    textAlign: TextAlign.center,
                    style: AppFonts.parkinsans(
                      size: 22,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    'Shear Heaven Pet Spa | Staff Login',
                    textAlign: TextAlign.center,
                    style: AppFonts.poppins(
                      size: 14,
                      weight: FontWeight.w400,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── SECTION 1: ACCOUNT CREDENTIALS ──
                  _buildSectionHeader('ACCOUNT CREDENTIALS'),
                  const SizedBox(height: 14),

                  _buildFieldLabel('Email / Login ID'),
                  const SizedBox(height: 6),
                  _buildPillTextField(
                    controller: _emailController,
                    hintText: 'name@shearheaven.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel('Enter Password'),
                  const SizedBox(height: 6),
                  _buildPillTextField(
                    controller: _passwordController,
                    hintText: '••••••••••••••••',
                    obscureText: true,
                  ),
                  const SizedBox(height: 6),

                  PasswordRequirementsView(
                    controller: _passwordController,
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel('Confirm Password'),
                  const SizedBox(height: 6),
                  _buildPillTextField(
                    controller: _confirmPasswordController,
                    hintText: '••••••••••••••••',
                    obscureText: true,
                  ),
                  const SizedBox(height: 32),

                  // ── SECTION 2: PROFILE DETAILS ──
                  _buildSectionHeader('PROFILE DETAILS'),
                  const SizedBox(height: 18),

                  _buildFieldLabel('Full Name'),
                  const SizedBox(height: 6),
                  _buildPillTextField(
                    controller: _fullNameController,
                    hintText: 'e.g. Ashna Menon',
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel('Phone'),
                  const SizedBox(height: 6),
                  _buildPillTextField(
                    controller: _phoneController,
                    hintText: '(555) 000-0000',
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [
                      UsPhoneInputFormatter(),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppFonts.poppins(
                          size: 13,
                          weight: FontWeight.w500,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Complete Setup Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleCompleteSetup,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Complete Setup',
                              style: AppFonts.poppins(
                                size: 16,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppFonts.poppins(
        size: 13,
        weight: FontWeight.w700,
        color: const Color(0xFF111827),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppFonts.poppins(
        size: 13.5,
        weight: FontWeight.w500,
        color: const Color(0xFF111827),
      ),
    );
  }

  Widget _buildPillTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD1D5DB),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textAlignVertical: TextAlignVertical.center,
        style: AppFonts.poppins(
          size: 13.5,
          weight: FontWeight.w400,
          color: const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          hintText: hintText,
          hintStyle: AppFonts.poppins(
            size: 13.5,
            weight: FontWeight.w400,
            color: const Color(0xFF9CA3AF),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
