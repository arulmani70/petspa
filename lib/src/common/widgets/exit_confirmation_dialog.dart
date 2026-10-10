import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

/// Reusable Exit Confirmation Dialog matching the Shear Heaven Pet Spa design system.
///
/// Prompts the user with:
/// - Title: "Exit App?"
/// - Message: "Are you sure you want to exit the application?"
/// - Actions: "Cancel" (dismiss dialog) and "Exit" (closes the app).
class ExitConfirmationDialog extends StatelessWidget {
  const ExitConfirmationDialog({super.key});

  static bool _isDialogOpen = false;

  /// Shows the exit confirmation dialog.
  ///
  /// Prevents opening duplicate dialogs if the Back button is pressed repeatedly.
  /// Returns `true` if the user confirmed exiting, or `false` otherwise.
  static Future<bool> show(BuildContext context) async {
    if (_isDialogOpen) return false;
    _isDialogOpen = true;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => const ExitConfirmationDialog(),
      );

      return result ?? false;
    } finally {
      _isDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exit App?',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to exit the application?',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w400,
                color: const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppFonts.parkinsans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Exit',
                        style: AppFonts.parkinsans(
                          size: 14,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
