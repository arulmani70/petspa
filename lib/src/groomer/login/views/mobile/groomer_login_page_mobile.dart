import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

class GroomerLoginPageMobile extends StatefulWidget {
  const GroomerLoginPageMobile({super.key});

  @override
  State<GroomerLoginPageMobile> createState() => _GroomerLoginPageMobileState();
}

class _GroomerLoginPageMobileState extends State<GroomerLoginPageMobile> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ServicesLocator.sessionService.isGroomerLoggedIn) {
        final groomer = ServicesLocator.groomerLoginRepository.getCurrentGroomer();
        if (groomer != null && mounted) {
          if (groomer.mustChangePassword) {
            context.goNamed(RouteNames.groomerRegister);
          } else {
            context.goNamed(RouteNames.groomerHome);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both User ID/Email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loginResponse = await ServicesLocator.groomerLoginRepository.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (loginResponse == null) {
        setState(() {
          _errorMessage = 'Invalid response from server. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // Check mustChangePassword flow
      if (loginResponse.mustChangePassword) {
        context.goNamed(
          RouteNames.groomerRegister,
          extra: {
            'tempLoginId': email,
            'tempPassword': password,
          },
        );
      } else {
        context.goNamed(RouteNames.groomerHome);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final err = e.toString().replaceAll('Exception:', '').trim();
        _errorMessage = err.isNotEmpty ? err : 'Invalid credentials. Please try again.';
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
          // Background sky image overlay
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
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.goNamed(RouteNames.login);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Logo
                  Center(
                    child: SvgPicture.asset(
                      'assets/images/common/logo.svg',
                      width: 146,
                      height: 82,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Header Title
                  Text(
                    'Groomer Portal',
                    textAlign: TextAlign.center,
                    style: AppFonts.parkinsans(
                      size: 22,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),

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

                  const SizedBox(height: 36),

                  // Field 1: User ID / Username
                  _buildInputLabel(
                    icon: Icons.person,
                    label: 'User ID / Username',
                  ),
                  const SizedBox(height: 4),
                  _buildPillTextField(
                    controller: _emailController,
                    hintText: 'Enter your User ID',
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 16),

                  // Field 2: Temporary password
                  _buildInputLabel(
                    icon: Icons.lock,
                    label: 'Temporary password',
                  ),
                  const SizedBox(height: 4),
                  _buildPillTextField(
                    controller: _passwordController,
                    hintText: 'Enter Temporary password',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF6B7280),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Info Notice Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF86EFAC),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Your admin has shared your User ID and a temporary password. You'll be asked to set a new password on first login.",
                            style: AppFonts.poppins(
                              size: 12.5,
                              weight: FontWeight.w400,
                              color: const Color(0xFF166534),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
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

                  // Login Button
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
                      onPressed: _isLoading ? null : _handleLogin,
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
                              'Login',
                              style: AppFonts.poppins(
                                size: 16,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Footer: Don't have credentials? Contact your admin
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have credentials? ",
                        style: AppFonts.poppins(
                          size: 13.5,
                          weight: FontWeight.w400,
                          color: const Color(0xFF374151),
                        ),
                        children: [
                          TextSpan(
                            text: 'Contact your admin',
                            style: AppFonts.poppins(
                              size: 13.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF111827)),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppFonts.poppins(
            size: 13,
            weight: FontWeight.w500,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildPillTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
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
        textAlignVertical: TextAlignVertical.center,
        style: AppFonts.poppins(
          size: 14,
          weight: FontWeight.w400,
          color: const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.only(left: 20, right: 12, top: 15, bottom: 15),
          hintText: hintText,
          hintStyle: AppFonts.poppins(
            size: 14,
            weight: FontWeight.w400,
            color: const Color(0xFF9CA3AF),
          ),
          border: InputBorder.none,
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: suffixIcon,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
      ),
    );
  }
}
