import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/auth_pill_field.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/password_requirements_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flow:
//   Step 1 — Enter email → POST /api/auth/forgot-password
//   Step 2 — Enter 6-digit OTP → POST /api/auth/verify-otp
//   Step 3 — Enter new password → POST /api/auth/reset-password
// ─────────────────────────────────────────────────────────────────────────────
enum _FpStep { email, otp, newPassword }

class ForgotPasswordPageMobile extends StatefulWidget {
  const ForgotPasswordPageMobile({super.key});

  @override
  State<ForgotPasswordPageMobile> createState() =>
      _ForgotPasswordPageMobileState();
}

class _ForgotPasswordPageMobileState extends State<ForgotPasswordPageMobile> {
  final Logger _log = Logger();

  _FpStep _step = _FpStep.email;
  bool _loading = false;
  String? _errorMsg;
  String _email = '';

  // Step 1
  final _emailCtrl = TextEditingController();

  // Step 2
  static const int _otpLength = 6;
  final List<String> _otpDigits = List.filled(_otpLength, '');
  int _otpIndex = 0;

  // Step 3
  final _pwCtrl = TextEditingController();
  final _cpwCtrl = TextEditingController();
  final _pwFocusNode = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _cpwCtrl.dispose();
    _pwFocusNode.dispose();
    super.dispose();
  }

  // ── Step 1: Call POST /api/auth/forgot-password ───────────────────────────
  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      _log.d('ForgotPassword::_submitEmail::Calling /api/auth/forgot-password for $email');
      final exists =
          await ServicesLocator.authRepository.forgotPasswordCheck(email);

      if (!mounted) return;
      if (!exists) {
        setState(() {
          _loading = false;
          _errorMsg = 'No account found with this email address.';
        });
        return;
      }

      setState(() {
        _email = email;
        _step = _FpStep.otp;
        _loading = false;
      });
    } catch (e) {
      _log.e('ForgotPassword::_submitEmail::Error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = _extractMessage(e);
      });
    }
  }

  // ── Step 2: Verify OTP via POST /api/auth/verify-otp ──────────────────────
  Future<void> _submitOtp() async {
    final code = _otpDigits.join();
    if (code.length < _otpLength) {
      setState(() => _errorMsg = 'Please enter the complete 6-digit OTP code.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      _log.d('ForgotPassword::_submitOtp::Verifying OTP for $_email');
      final valid = await ServicesLocator.authRepository.verifyOtp(code);

      if (!mounted) return;
      if (!valid) {
        setState(() {
          _loading = false;
          _errorMsg = 'Invalid or expired OTP. Please try again.';
        });
        return;
      }

      setState(() {
        _step = _FpStep.newPassword;
        _loading = false;
      });
    } catch (e) {
      _log.e('ForgotPassword::_submitOtp::Error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = _extractMessage(e);
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await ServicesLocator.authRepository.sendOtp(_email);
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.showSuccessToast(context, 'OTP resent to your email.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = _extractMessage(e);
      });
    }
  }

  // ── Step 3: Reset password via POST /api/auth/reset-password ─────────────
  Future<void> _submitNewPassword() async {
    final pw = _pwCtrl.text;
    final cpw = _cpwCtrl.text;

    final missingMsg = PasswordValidator.getFirstMissingMessage(pw);
    if (missingMsg != null) {
      setState(() => _errorMsg = missingMsg);
      return;
    }
    if (pw != cpw) {
      setState(() => _errorMsg = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      _log.d('ForgotPassword::_submitNewPassword::Resetting for $_email');
      await ServicesLocator.authRepository.resetPassword(
        email: _email,
        password: pw,
        confirmPassword: cpw,
      );

      if (!mounted) return;
      ToastUtil.showSuccessToast(
        context,
        'Password updated successfully! Please log in.',
      );
      context.goNamed(RouteNames.login);
    } catch (e) {
      _log.e('ForgotPassword::_submitNewPassword::Error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = _extractMessage(e);
      });
    }
  }

  String _extractMessage(dynamic e) {
    final s = e.toString();
    if (s.contains('Exception:')) {
      return s.replaceAll('Exception:', '').trim();
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FD),
      body: Stack(
        children: [
          // ── Background: sky & clouds ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/common/welcome_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) =>
                  const ColoredBox(color: Color(0xFFF0F8FD)),
            ),
          ),
          // ── Gradient overlay ──
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
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Logo
                  SvgPicture.asset(
                    'assets/images/common/logo.svg',
                    width: 146,
                    height: 82,
                  ),
                  const SizedBox(height: 32),

                  // Step indicator dots
                  _buildStepIndicator(),
                  const SizedBox(height: 28),

                  // Animated step content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = _FpStep.values;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final active = steps[i].index <= _step.index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF111827)
                : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _FpStep.email:
        return _buildEmailStep();
      case _FpStep.otp:
        return _buildOtpStep();
      case _FpStep.newPassword:
        return _buildNewPasswordStep();
    }
  }

  // ── Step 1 View: Email ──
  Widget _buildEmailStep() {
    return Column(
      key: const ValueKey('email_step'),
      children: [
        Text(
          'Forgot Password',
          textAlign: TextAlign.center,
          style: AppFonts.parkinsans(
            size: 20,
            weight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your registered email address to receive a verification code',
          textAlign: TextAlign.center,
          style: AppFonts.poppins(
            size: 14,
            weight: FontWeight.w400,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 28),

        AuthPillField(
          label: 'Enter Email ID',
          flutterIcon: Icons.mail,
          hint: 'name@gmail.com',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(_errorMsg!),
        ],
        const SizedBox(height: 24),

        BlackPillButton(
          label: _loading ? '' : 'Send OTP',
          onTap: _loading ? () {} : _submitEmail,
        ),
        const SizedBox(height: 18),

        GestureDetector(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.login);
            }
          },
          child: Text.rich(
            TextSpan(
              text: 'Remember your password? ',
              style: AppFonts.dmSans(
                size: 14,
                weight: FontWeight.w400,
                color: const Color(0xFF111827),
              ),
              children: [
                TextSpan(
                  text: 'Log in',
                  style: AppFonts.parkinsans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 2 View: OTP ──
  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp_step'),
      children: [
        Text(
          'Enter OTP',
          textAlign: TextAlign.center,
          style: AppFonts.parkinsans(
            size: 20,
            weight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppFonts.poppins(
              size: 14,
              weight: FontWeight.w400,
              color: const Color(0xFF374151),
              height: 1.4,
            ),
            children: [
              const TextSpan(
                text: 'A 6-digit code has been sent to\n',
              ),
              TextSpan(
                text: _email,
                style: AppFonts.poppins(
                  size: 14,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 6 Circular OTP Input Bubbles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_otpLength, (index) {
            final isFocused = index == _otpIndex;
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFF111827),
                  width: isFocused ? 2.0 : 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: TextField(
                autofocus: index == 0,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: AppFonts.poppins(
                  size: 20,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  setState(() {
                    _otpDigits[index] = val;
                    if (val.isNotEmpty && index < _otpLength - 1) {
                      _otpIndex = index + 1;
                      FocusScope.of(context).nextFocus();
                    } else if (val.isEmpty && index > 0) {
                      _otpIndex = index - 1;
                      FocusScope.of(context).previousFocus();
                    }
                  });
                  if (_otpDigits.every((d) => d.isNotEmpty)) {
                    _submitOtp();
                  }
                },
              ),
            );
          }),
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(_errorMsg!),
        ],
        const SizedBox(height: 24),

        BlackPillButton(
          label: _loading ? '' : 'Verify OTP',
          onTap: _loading ? () {} : _submitOtp,
        ),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: _loading ? null : _resendOtp,
          child: Text(
            'Resend OTP',
            style: AppFonts.poppins(
              size: 14,
              weight: FontWeight.w600,
              color: const Color(0xFF111827),
            ).copyWith(decoration: TextDecoration.underline),
          ),
        ),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: () => setState(() {
            _step = _FpStep.email;
            _errorMsg = null;
          }),
          child: Text(
            '← Back to email',
            style: AppFonts.poppins(
              size: 13,
              weight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step 3 View: New Password ──
  Widget _buildNewPasswordStep() {
    return Column(
      key: const ValueKey('pw_step'),
      children: [
        Text(
          'Reset Password',
          textAlign: TextAlign.center,
          style: AppFonts.parkinsans(
            size: 20,
            weight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your new password to complete the reset',
          textAlign: TextAlign.center,
          style: AppFonts.poppins(
            size: 14,
            weight: FontWeight.w400,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 28),

        AuthPillField(
          label: 'New Password',
          flutterIcon: Icons.lock,
          hint: '••••••••••••••••••••',
          controller: _pwCtrl,
          focusNode: _pwFocusNode,
          isPassword: true,
        ),

        PasswordRequirementsView(
          controller: _pwCtrl,
          focusNode: _pwFocusNode,
        ),
        const SizedBox(height: 14),

        AuthPillField(
          label: 'Confirm Password',
          flutterIcon: Icons.lock,
          hint: '••••••••••••••••••••',
          controller: _cpwCtrl,
          isPassword: true,
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(_errorMsg!),
        ],
        const SizedBox(height: 24),

        BlackPillButton(
          label: _loading ? '' : 'Update Password',
          onTap: _loading ? () {} : _submitNewPassword,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFF991B1B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppFonts.poppins(
                size: 13,
                color: const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
