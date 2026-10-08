import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_formatters.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/auth_pill_field.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/password_requirements_view.dart';

class CreateAccountPageMobile extends StatefulWidget {
  const CreateAccountPageMobile({super.key});

  @override
  State<CreateAccountPageMobile> createState() =>
      _CreateAccountPageMobileState();
}

class _CreateAccountPageMobileState extends State<CreateAccountPageMobile> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _acceptableRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.pushNamed(RouteNames.termsCondition);
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.pushNamed(RouteNames.privacyPolicy);
      };
    _acceptableRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.pushNamed(RouteNames.termsCondition);
      };
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _acceptableRecognizer.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FD),
      body: Stack(
        children: [
          // ── Background: sky & clouds texture ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/common/welcome_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFFF0F8FD)),
            ),
          ),
          // ── Gradient overlay to match reference image ──
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
            child: BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state.status == AuthStatus.otpSent) {
                  context.pushNamed(RouteNames.otp);
                } else if (state.status == AuthStatus.unauthenticated &&
                    state.message.isNotEmpty &&
                    state.message != 'Logged out') {
                  ToastUtil.showErrorToast(context, state.message);
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // ── Logo ──
                    SvgPicture.asset(
                      'assets/images/common/logo.svg',
                      width: 146,
                      height: 82,
                    ),
                    const SizedBox(height: 24),

                    // ── Title ──
                    Text(
                      'Create an Account',
                      textAlign: TextAlign.center,
                      style: AppFonts.parkinsans(
                        size: 20,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ── Subtitle ──
                    Text(
                      'Sign up to create and account for booking',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(
                        size: 14,
                        weight: FontWeight.w400,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Toggle (Log in / Sign up) ──
                    _buildToggle(),
                    const SizedBox(height: 28),

                    // ── 1. Enter Full Name ──
                    AuthPillField(
                      label: 'Enter Full Name',
                      flutterIcon: Icons.person,
                      hint: 'Eg: Robert Martin',
                      controller: _nameController,
                    ),
                    const SizedBox(height: 14),

                    // ── 2. Enter Email ID ──
                    AuthPillField(
                      label: 'Enter Email ID',
                      flutterIcon: Icons.mail,
                      hint: 'name@gmail.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    // ── 3. Enter Mobile Number ──
                    AuthPillField(
                      label: 'Enter Mobile Number',
                      flutterIcon: Icons.phone,
                      hint: '(817) 123-4567',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [
                        UsPhoneInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── 4. Enter Password ──
                    AuthPillField(
                      label: 'Enter Password',
                      flutterIcon: Icons.lock,
                      hint: '••••••••••••••••••••',
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      isPassword: true,
                    ),

                    // ── Live Password Requirements Helper (compact one-line, shown when entering) ──
                    PasswordRequirementsView(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                    ),
                    const SizedBox(height: 14),

                    // ── 5. Confirm Password ──
                    AuthPillField(
                      label: 'Confirm Password',
                      flutterIcon: Icons.lock,
                      hint: '••••••••••••••••••••',
                      controller: _confirmPasswordController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 22),

                    // ── Verify Button ──
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state.status == AuthStatus.loading;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            BlackPillButton(
                              label: isLoading ? '' : 'Sign Up',
                              onTap: isLoading
                                  ? () {}
                                  : () {
                                      final name = _nameController.text.trim();
                                      final email =
                                          _emailController.text.trim();
                                      final phone =
                                          _phoneController.text.trim();
                                      final password =
                                          _passwordController.text;
                                      final confirmPassword =
                                          _confirmPasswordController.text;

                                      if (name.isEmpty ||
                                          email.isEmpty ||
                                          phone.isEmpty ||
                                          password.isEmpty) {
                                        ToastUtil.showErrorToast(
                                          context,
                                          'Please fill all fields',
                                        );
                                        return;
                                      }
                                      if (!UsPhoneInputFormatter.isValid(phone)) {
                                        ToastUtil.showErrorToast(
                                          context,
                                          'Please enter a valid 10-digit US phone number.',
                                        );
                                        return;
                                      }
                                      final missingPwMsg =
                                          PasswordValidator.getFirstMissingMessage(password);
                                      if (missingPwMsg != null) {
                                        ToastUtil.showErrorToast(
                                          context,
                                          missingPwMsg,
                                        );
                                        return;
                                      }
                                      if (password != confirmPassword) {
                                        ToastUtil.showErrorToast(
                                          context,
                                          'Passwords do not match',
                                        );
                                        return;
                                      }

                                      context.read<AuthBloc>().add(
                                            RegisterSubmitted(
                                              name: name,
                                              email: email,
                                              phone: phone,
                                              password: password,
                                            ),
                                          );
                                    },
                            ),
                            if (isLoading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Terms & Privacy Agreement Text ──
                    RichText(
                      text: TextSpan(
                        style: AppFonts.poppins(
                          size: 11.5,
                          weight: FontWeight.w400,
                          color: const Color(0xFF374151),
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'By continuing, you agree to shearheaven pet spa’s ',
                          ),
                          TextSpan(
                            text: 'Terms',
                            recognizer: _termsRecognizer,
                            style: AppFonts.poppins(
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ).copyWith(decoration: TextDecoration.underline),
                          ),
                          const TextSpan(
                            text:
                                ' (including binding arbitration and class-action waiver) ',
                          ),
                          TextSpan(
                            text: 'Privacy Policy',
                            recognizer: _privacyRecognizer,
                            style: AppFonts.poppins(
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ).copyWith(decoration: TextDecoration.underline),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Acceptable Use Policy',
                            recognizer: _acceptableRecognizer,
                            style: AppFonts.poppins(
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ).copyWith(decoration: TextDecoration.underline),
                          ),
                          const TextSpan(
                            text:
                                ', and consent to receive service, marketing, and promo texts. Reply STOP to opt out',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Divider "or" ──
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0xFF9CA3AF),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'or',
                            style: AppFonts.dmSans(
                              size: 14,
                              weight: FontWeight.w400,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: Color(0xFF9CA3AF),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── Continue as Guest Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => context.goNamed(RouteNames.home),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          side: const BorderSide(
                            color: Color(0xFF111827),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(60),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.explore_outlined,
                              size: 20,
                              color: Color(0xFF111827),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Continue as Guest',
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.parkinsans(
                                  size: 16,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Bottom Text "Already have an account? Log in" ──
                    GestureDetector(
                      onTap: () => context.goNamed(RouteNames.login),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pill toggle with active white pill on the right (Sign up) ──
  Widget _buildToggle() {
    return Container(
      width: 249,
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: const Color(0xFF111827),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.goNamed(RouteNames.login),
              child: Container(
                height: 37,
                alignment: Alignment.center,
                child: Text(
                  'Log in',
                  style: AppFonts.parkinsans(
                    size: 16,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 37,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Text(
                'Sign up',
                style: AppFonts.parkinsans(
                  size: 16,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
