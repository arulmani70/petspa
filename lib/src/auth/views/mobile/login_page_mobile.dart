import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/auth_pill_field.dart';

class LoginPageMobile extends StatefulWidget {
  const LoginPageMobile({super.key});

  @override
  State<LoginPageMobile> createState() => _LoginPageMobileState();
}

class _LoginPageMobileState extends State<LoginPageMobile> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed(RouteNames.welcome);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F8FD),
        body: Stack(
          children: [
            // ── Background image: sky & clouds ──
            Positioned.fill(
              child: Image.asset(
                'assets/images/common/welcome_bg.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Color(0xFFF0F8FD)),
              ),
            ),
            // ── Subtle gradient overlay to match reference image ──
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
                  if (state.status == AuthStatus.authenticated) {
                    final userType = state.userType ??
                        state.user?['userType']?.toString().toLowerCase();
                    if (userType == 'groomer') {
                      final mustChange = state.mustChangePassword ||
                          state.user?['mustChangePassword'] == true;
                      if (mustChange) {
                        context.goNamed(RouteNames.groomerRegister);
                      } else {
                        context.goNamed(RouteNames.groomerHome);
                      }
                    } else {
                      context.goNamed(RouteNames.home);
                    }
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 24),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.goNamed(RouteNames.welcome);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Logo ──
                      SvgPicture.asset(
                        'assets/images/common/logo.svg',
                        width: 146,
                        height: 82,
                      ),
                      const SizedBox(height: 28),

                    // ── Customer Login Title ──
                    Text(
                      'Customer Login',
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
                      "Log in to book your pet's appointment",
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(
                        size: 14,
                        weight: FontWeight.w400,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Toggle (Log in / Sign up) ──
                    _buildToggle(),
                    const SizedBox(height: 36),

                    // ── Enter Email ID Field ──
                    AuthPillField(
                      label: 'Enter Email ID',
                      flutterIcon: Icons.mail,
                      hint: 'name@gmail.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      isPassword: false,
                    ),
                    const SizedBox(height: 16),

                    // ── Enter Password Field ──
                    AuthPillField(
                      label: 'Enter Password',
                      flutterIcon: Icons.lock,
                      hint: 'Enter your password',
                      controller: _passwordController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 6),

                    // ── Forgot Password? ──
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () =>
                            context.pushNamed(RouteNames.forgotPassword),
                        child: Text(
                          'Forgot Password?',
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Login Button ──
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state.status == AuthStatus.loading;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            BlackPillButton(
                              label: isLoading ? '' : 'Login',
                              onTap: isLoading
                                  ? () {}
                                  : () {
                                      final email =
                                          _emailController.text.trim();
                                      final password =
                                          _passwordController.text;
                                      if (email.isEmpty || password.isEmpty) {
                                        ToastUtil.showErrorToast(
                                          context,
                                          'Please enter email and password',
                                        );
                                        return;
                                      }
                                      context.read<AuthBloc>().add(
                                            LoginSubmitted(
                                              email: email,
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.explore_outlined,
                              size: 20,
                              color: Color(0xFF111827),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Continue as Guest',
                              style: AppFonts.parkinsans(
                                size: 16,
                                weight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Bottom Text "Don't have an account? Create Account" ──
                    GestureDetector(
                      onTap: () => context.goNamed(RouteNames.signup),
                      child: Text.rich(
                        TextSpan(
                          text: "Don’t have an account? ",
                          style: AppFonts.dmSans(
                            size: 14,
                            weight: FontWeight.w400,
                            color: const Color(0xFF111827),
                          ),
                          children: [
                            TextSpan(
                              text: 'Create Account',
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
    ),
  );
}

  // ── Pill toggle with active white pill on the left ──
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
            child: Container(
              height: 37,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Text(
                'Log in',
                style: AppFonts.parkinsans(
                  size: 16,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => context.goNamed(RouteNames.signup),
              child: Container(
                height: 37,
                alignment: Alignment.center,
                child: Text(
                  'Sign up',
                  style: AppFonts.parkinsans(
                    size: 16,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
