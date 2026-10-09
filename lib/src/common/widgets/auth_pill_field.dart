import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

/// Auth field matching the reference design:
/// a label row (filled black icon + Poppins 500 13 - Medium) above a white
/// radius-60 pill with crisp border containing the hint (Poppins 400 14) and optional password visibility toggle.
class AuthPillField extends StatefulWidget {
  final String label;
  final String? iconPath;
  final IconData? flutterIcon;
  final String hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const AuthPillField({
    super.key,
    required this.label,
    this.iconPath,
    this.flutterIcon,
    required this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.inputFormatters,
    this.focusNode,
    this.onChanged,
  });

  @override
  State<AuthPillField> createState() => _AuthPillFieldState();
}

class _AuthPillFieldState extends State<AuthPillField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  void didUpdateWidget(covariant AuthPillField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPassword != widget.isPassword) {
      _obscureText = widget.isPassword;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.flutterIcon != null)
              Icon(widget.flutterIcon, size: 14, color: const Color(0xFF111827))
            else if (widget.iconPath != null)
              SvgPicture.asset(
                widget.iconPath!,
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF111827),
                  BlendMode.srcIn,
                ),
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.mail,
                  size: 14,
                  color: Color(0xFF111827),
                ),
              )
            else
              const Icon(
                Icons.mail,
                size: 14,
                color: Color(0xFF111827),
              ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w500, // Medium font weight
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 51,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(60),
            border: Border.all(
              color: const Color(0xFF111827),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            onChanged: widget.onChanged,
            obscureText: widget.isPassword ? _obscureText : false,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            textAlignVertical: TextAlignVertical.center,
            style: AppFonts.poppins(
              size: 14.5,
              weight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              hintStyle: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(
                left: 20,
                right: widget.isPassword ? 6 : 20,
                top: 14,
                bottom: 14,
              ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF6B7280),
                        size: 20,
                      ),
                      splashRadius: 20,
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Black pill CTA (Parkinsans 700 18 white text) matching reference.
class BlackPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double? height;
  final bool isLoading;

  const BlackPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 49,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(60),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: AppFonts.parkinsans(
                  size: 18,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// Social login button - 115x38 rounded pill with 18x18 icon + Poppins 500 14.
class SocialPillButton extends StatelessWidget {
  final String iconPath;
  final String label;
  final VoidCallback onTap;

  const SocialPillButton({
    super.key,
    required this.iconPath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 115,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(60),
          border: Border.all(
            color: const Color(0xFF111827),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: 18,
              height: 18,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.g_mobiledata,
                size: 18,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w500,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
