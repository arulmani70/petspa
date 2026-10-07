import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

/// Helper class for validating password rules
class PasswordValidator {
  PasswordValidator._();

  static bool hasMinLength(String password) => password.length >= 8;

  static bool hasUppercase(String password) =>
      RegExp(r'[A-Z]').hasMatch(password);

  static bool hasLowercase(String password) =>
      RegExp(r'[a-z]').hasMatch(password);

  static bool hasNumber(String password) =>
      RegExp(r'[0-9]').hasMatch(password);

  static bool hasSpecialChar(String password) =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+~=`[\]\\;/]').hasMatch(password) ||
      RegExp(r'[^A-Za-z0-9]').hasMatch(password);

  static bool isValid(String password) =>
      hasMinLength(password) &&
      hasUppercase(password) &&
      hasLowercase(password) &&
      hasNumber(password) &&
      hasSpecialChar(password);

  static String? getFirstMissingMessage(String password) {
    if (!hasMinLength(password)) {
      return 'Password must be at least 8 characters.';
    }
    if (!hasUppercase(password)) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!hasLowercase(password)) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!hasNumber(password)) {
      return 'Password must contain at least one number.';
    }
    if (!hasSpecialChar(password)) {
      return 'Password must contain at least one special character.';
    }
    return null;
  }
}

/// Dynamic password requirements indicator matching the brand theme colors:
/// - **Primary / Satisfied**: Brand Black (`#111827`) with white text and check icon
/// - **Ash / Missing**: Brand Ash Hash (`#F2F2F2`) with subtle border & muted text
/// - **Hidden by default**: Expands smoothly only when the user focuses or types in the password field
/// - **One-line compact layout**: Renders as a single horizontal row / wrap of chips
class PasswordRequirementsView extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool showOnlyWhenInteracting;
  final EdgeInsetsGeometry? margin;

  const PasswordRequirementsView({
    super.key,
    required this.controller,
    this.focusNode,
    this.showOnlyWhenInteracting = true,
    this.margin,
  });

  @override
  State<PasswordRequirementsView> createState() =>
      _PasswordRequirementsViewState();
}

class _PasswordRequirementsViewState extends State<PasswordRequirementsView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
    widget.focusNode?.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(covariant PasswordRequirementsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChanged);
      widget.controller.addListener(_onStateChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onStateChanged);
      widget.focusNode?.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    widget.focusNode?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final isFocused = widget.focusNode?.hasFocus ?? false;
    final shouldShow = !widget.showOnlyWhenInteracting ||
        text.isNotEmpty ||
        isFocused;

    final hasMinLength = PasswordValidator.hasMinLength(text);
    final hasUppercase = PasswordValidator.hasUppercase(text);
    final hasLowercase = PasswordValidator.hasLowercase(text);
    final hasNumber = PasswordValidator.hasNumber(text);
    final hasSpecialChar = PasswordValidator.hasSpecialChar(text);
    final allValid = hasMinLength &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecialChar;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: shouldShow
          ? Container(
              margin: widget.margin ?? const EdgeInsets.only(top: 6, bottom: 2),
              child: allValid
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Password meets all requirements',
                            style: AppFonts.poppins(
                              size: 11,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _RequirementChip(
                          label: '8+ chars',
                          isSatisfied: hasMinLength,
                        ),
                        _RequirementChip(
                          label: 'Uppercase',
                          isSatisfied: hasUppercase,
                        ),
                        _RequirementChip(
                          label: 'Lowercase',
                          isSatisfied: hasLowercase,
                        ),
                        _RequirementChip(
                          label: 'Number',
                          isSatisfied: hasNumber,
                        ),
                        _RequirementChip(
                          label: 'Special (!@#)',
                          isSatisfied: hasSpecialChar,
                        ),
                      ],
                    ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  final String label;
  final bool isSatisfied;

  const _RequirementChip({
    required this.label,
    required this.isSatisfied,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isSatisfied
            ? const Color(0xFF111827) // Brand primary black
            : const Color(0xFFF2F2F2), // Brand ash/hash background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSatisfied
              ? const Color(0xFF111827)
              : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSatisfied ? Icons.check_rounded : Icons.circle,
            size: isSatisfied ? 11 : 4,
            color: isSatisfied
                ? Colors.white
                : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: AppFonts.poppins(
              size: 10.5,
              weight: isSatisfied ? FontWeight.w600 : FontWeight.w400,
              color: isSatisfied
                  ? Colors.white
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
