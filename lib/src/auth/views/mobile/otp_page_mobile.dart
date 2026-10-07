import 'dart:async';
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

class OtpPageMobile extends StatefulWidget {
  const OtpPageMobile({super.key});

  @override
  State<OtpPageMobile> createState() => _OtpPageMobileState();
}

class _OtpPageMobileState extends State<OtpPageMobile> {
  static const int _otpLength = 6;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final List<String> _digits = List.filled(_otpLength, '');
  int _currentIndex = 0;
  bool _resending = false;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _otpFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _onOtpChanged() {
    final raw = _otpController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.length > _otpLength) {
      _otpController.value = TextEditingValue(
        text: raw.substring(0, _otpLength),
        selection: const TextSelection.collapsed(offset: _otpLength),
      );
      return;
    }
    setState(() {
      for (int i = 0; i < _otpLength; i++) {
        _digits[i] = i < raw.length ? raw[i] : '';
      }
      _currentIndex = raw.length.clamp(0, _otpLength);
    });

    if (raw.length == _otpLength) {
      _submitOtp();
    }
  }

  void _submitOtp() {
    final code = _digits.join();
    if (code.length < _otpLength) {
      ToastUtil.showErrorToast(
        context,
        'Please enter the complete 6-digit OTP code',
      );
      return;
    }
    context.read<AuthBloc>().add(VerifyOtpSubmitted(code: code));
  }

  void _resendOtp(String email) {
    if (_resending) return;
    setState(() => _resending = true);
    context.read<AuthBloc>().add(SendOtpSubmitted(email: email));
    _resendTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _resending = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FD),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.otpVerified) {
            context.goNamed(RouteNames.accountCreated);
          } else if (state.status == AuthStatus.otpSent &&
              state.message.isNotEmpty) {
            ToastUtil.showSuccessToast(context, state.message);
          } else if (state.message.isNotEmpty &&
              state.status != AuthStatus.loading) {
            ToastUtil.showErrorToast(context, state.message);
          }
        },
        child: Stack(
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
            // ── Subtle gradient overlay to match reference design ──
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),

                    // Logo
                    SvgPicture.asset(
                      'assets/images/common/logo.svg',
                      width: 146,
                      height: 82,
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Enter OTP',
                      textAlign: TextAlign.center,
                      style: AppFonts.parkinsans(
                        size: 22,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle with user email
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final email = state.otpSentTo ?? 'username@gmail.com';
                        return RichText(
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
                                text:
                                    'Enter the 6 digit code we have send via the\nemail to ',
                              ),
                              TextSpan(
                                text: email,
                                style: AppFonts.poppins(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // 🔒 Enter OTP label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock,
                          size: 14,
                          color: Color(0xFF111827),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Enter OTP',
                          style: AppFonts.poppins(
                            size: 13,
                            weight: FontWeight.w500,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── 6 Circular OTP Bubbles + Transparent Overlay TextField ──
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _otpFocusNode.requestFocus(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(_otpLength, (index) {
                              final digit = _digits[index];
                              final isFocused = _otpFocusNode.hasFocus &&
                                  (index == _currentIndex ||
                                      (index == _otpLength - 1 &&
                                          _currentIndex == _otpLength));
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
                                  boxShadow: isFocused
                                      ? [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.12),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  digit,
                                  style: AppFonts.poppins(
                                    size: 20,
                                    weight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                              );
                            }),
                          ),

                          // Transparent TextField capturing device keyboard input & OTP autofill
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.0,
                              child: TextField(
                                controller: _otpController,
                                focusNode: _otpFocusNode,
                                keyboardType: TextInputType.number,
                                autofocus: true,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(_otpLength),
                                ],
                                showCursor: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Verify Button
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state.status == AuthStatus.loading;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            BlackPillButton(
                              label: isLoading ? '' : 'Verify',
                              onTap: isLoading ? () {} : _submitOtp,
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
                    const SizedBox(height: 20),

                    // Resend OTP Link
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final email = state.otpSentTo ?? '';
                        return GestureDetector(
                          onTap: email.isNotEmpty && !_resending
                              ? () => _resendOtp(email)
                              : null,
                          child: Text(
                            'Resend OTP',
                            style: AppFonts.poppins(
                              size: 14,
                              weight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ).copyWith(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
