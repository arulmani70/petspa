import 'package:flutter/material.dart';

/// Configuration metadata for service milestones.
class MilestoneConfig {
  final String key;
  final String title;
  final String shortLabel;
  final String subtitle;
  final String actionLabel;
  final IconData icon;

  const MilestoneConfig({
    required this.key,
    required this.title,
    required this.shortLabel,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
  });

  static const bath = MilestoneConfig(
    key: 'bath_completed',
    title: 'Bath Completed',
    shortLabel: 'Bath',
    subtitle: 'Record bath milestone & advance to styling',
    actionLabel: 'Confirm Bath Completed',
    icon: Icons.bathtub_outlined,
  );

  static const grooming = MilestoneConfig(
    key: 'grooming_completed',
    title: 'Grooming Completed',
    shortLabel: 'Grooming',
    subtitle: 'Record grooming milestone & finish service',
    actionLabel: 'Confirm Grooming Completed',
    icon: Icons.content_cut_rounded,
  );

  static const readyForCheckout = MilestoneConfig(
    key: 'ready_for_checkout',
    title: 'Ready for Checkout',
    shortLabel: 'Ready',
    subtitle: 'Mark service completed & notify customer for tip/checkout',
    actionLabel: 'Confirm Ready for Checkout',
    icon: Icons.shopping_bag_outlined,
  );

  static const checkIn = MilestoneConfig(
    key: 'check_in_completed',
    title: 'Check-in Completed',
    shortLabel: 'Check-in',
    subtitle: 'Record pet check-in and start service workflow',
    actionLabel: 'Confirm Check-in',
    icon: Icons.how_to_reg_rounded,
  );

  static MilestoneConfig forMilestone(String key) {
    if (key == GroomerMilestoneResolver.bathMilestone) {
      return bath;
    }
    if (key == GroomerMilestoneResolver.groomingMilestone) {
      return grooming;
    }
    if (key == 'ready_for_checkout' || key == 'readyforcheckout') {
      return readyForCheckout;
    }
    if (key == 'check_in_completed') {
      return checkIn;
    }
    final formatted = key
        .replaceAll('_', ' ')
        .split(' ')
        .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '')
        .join(' ');
    return MilestoneConfig(
      key: key,
      title: formatted,
      shortLabel: formatted.split(' ').first,
      subtitle: 'Record $formatted milestone',
      actionLabel: 'Confirm $formatted',
      icon: Icons.pets_rounded,
    );
  }
}

/// Dynamic Milestone Resolution Engine based on selected services, packages, and add-ons.
class GroomerMilestoneResolver {
  static const String bathMilestone = 'bath_completed';
  static const String groomingMilestone = 'grooming_completed';

  // ── Authoritative Service Catalog Mapping ─────────────────────────────────
  // Service IDs from ServiceRepository / API:
  //
  // Bath-Only Service IDs:
  // Breed Bathing: 2 (Small Dog Bathing), 5 (Medium Dog Bathing), 8 (Large Dog Bathing)
  // Walk-in: 11 (Bath & Blow Dry), 17 (Flea & Tick Treatment), 20 (Skin Care Treatment)
  static const Set<int> bathOnlyServiceIds = {2, 5, 8, 11, 17, 20};

  // Grooming-Only Service IDs:
  // Breed Grooming: 1 (Small Dog Grooming), 4 (Medium Dog Grooming), 7 (Large Dog Grooming)
  // Walk-in: 12 (Hair Trimming), 13 (Breed Styling), 14 (Nail Trimming), 15 (Ear Cleaning), 16 (Teeth Brushing)
  static const Set<int> groomingOnlyServiceIds = {1, 4, 7, 12, 13, 14, 15, 16};

  // Both Bath & Grooming Service IDs:
  // Breed Grooming & Bathing: 3 (Small), 6 (Medium), 9 (Large)
  // Walk-in: 10 (Full Grooming), 18 (Puppy Grooming), 19 (De-Shedding Treatment)
  static const Set<int> bothServiceIds = {3, 6, 9, 10, 18, 19};

  // Packages (all packages include full bath and grooming/styling):
  // 1 (Spa Package), 2 (Bath & Tidy Package), 3 (Deluxe Puppy Spa)
  static const Set<int> packageIds = {1, 2, 3};

  // Add-on IDs requiring Bath:
  // 3 (Blueberry Facial), 4 (Flea Bath), 7 (Medicated Bath), 8 (De-Odorize)
  static const Set<int> bathAddOnIds = {3, 4, 7, 8};

  // Add-on IDs requiring Grooming / Styling / Hygiene:
  // 1 (Nail Grinding), 2 (Teeth Brushing), 5 (Furminator), 6 (Dental Package),
  // 9 (Brush/Dematt), 10 (Hard To Handle), 11 (Express Service), 12 (Scissoring)
  static const Set<int> groomingAddOnIds = {1, 2, 5, 6, 9, 10, 11, 12};

  /// Resolves the ordered, unique list of applicable milestones for a booking.
  ///
  /// Guarantees:
  /// - Only applicable milestone steps are returned.
  /// - Multiple services are combined without duplicate steps.
  /// - Proper sequence is preserved: [bathMilestone] before [groomingMilestone].
  /// - Graceful fallback to standard workflow if service data is missing or invalid.
  static List<String> resolveRequiredMilestones({
    int? serviceId,
    String? serviceName,
    int? packageId,
    String? packageName,
    List<int> addOnIds = const [],
    List<String> addOns = const [],
  }) {
    bool needBath = false;
    bool needGrooming = false;
    bool recognizedAny = false;

    // 1. Check Package
    if (packageId != null && packageId > 0) {
      needBath = true;
      needGrooming = true;
      recognizedAny = true;
    } else if (packageName != null && packageName.trim().isNotEmpty) {
      needBath = true;
      needGrooming = true;
      recognizedAny = true;
    }

    // 2. Check Service ID (Primary Service)
    if (serviceId != null && serviceId > 0) {
      if (bathOnlyServiceIds.contains(serviceId)) {
        needBath = true;
        recognizedAny = true;
      } else if (groomingOnlyServiceIds.contains(serviceId)) {
        needGrooming = true;
        recognizedAny = true;
      } else if (bothServiceIds.contains(serviceId)) {
        needBath = true;
        needGrooming = true;
        recognizedAny = true;
      }
    }

    // 3. Check Add-On IDs
    for (final addOnId in addOnIds) {
      if (bathAddOnIds.contains(addOnId)) {
        needBath = true;
        recognizedAny = true;
      }
      if (groomingAddOnIds.contains(addOnId)) {
        needGrooming = true;
        recognizedAny = true;
      }
    }

    // 4. Secondary fallback: Check Add-On Names if IDs not provided
    if (addOnIds.isEmpty && addOns.isNotEmpty) {
      for (final addOn in addOns) {
        final lower = addOn.trim().toLowerCase();
        if (lower.contains('bath') ||
            lower.contains('facial') ||
            lower.contains('flea') ||
            lower.contains('medicated') ||
            lower.contains('de-odorize') ||
            lower.contains('deodorize')) {
          needBath = true;
          recognizedAny = true;
        }
        if (lower.contains('nail') ||
            lower.contains('grind') ||
            lower.contains('teeth') ||
            lower.contains('furminator') ||
            lower.contains('brush') ||
            lower.contains('dematt') ||
            lower.contains('scissoring') ||
            lower.contains('trim') ||
            lower.contains('style') ||
            lower.contains('dental') ||
            lower.contains('handle')) {
          needGrooming = true;
          recognizedAny = true;
        }
      }
    }

    // 5. Secondary fallback: Check Service Name only if serviceId was missing/unrecognized
    if (!recognizedAny && serviceName != null && serviceName.trim().isNotEmpty) {
      final sLower = serviceName.trim().toLowerCase();
      if (sLower.contains('grooming & bathing') ||
          sLower.contains('grooming and bathing') ||
          sLower.contains('bath & brush') ||
          sLower.contains('bath and brush') ||
          sLower.contains('bath & tidy') ||
          sLower.contains('bath and tidy') ||
          sLower.contains('bath & styling') ||
          sLower.contains('bath and styling') ||
          sLower.contains('full groom') ||
          sLower.contains('puppy groom') ||
          sLower.contains('spa')) {
        needBath = true;
        needGrooming = true;
        recognizedAny = true;
      } else if (sLower.contains('bath')) {
        needBath = true;
        recognizedAny = true;
      } else if (sLower.contains('groom') ||
          sLower.contains('trim') ||
          sLower.contains('styl') ||
          sLower.contains('nail') ||
          sLower.contains('ear') ||
          sLower.contains('teeth')) {
        needGrooming = true;
        recognizedAny = true;
      }
    }

    // 6. Graceful fallback for missing or completely invalid service data
    if (!recognizedAny && !needBath && !needGrooming) {
      return const [bathMilestone, groomingMilestone];
    }

    // 7. Combine without duplicates and preserve proper milestone sequence
    final milestones = <String>[];
    if (needBath) {
      milestones.add(bathMilestone);
    }
    if (needGrooming) {
      milestones.add(groomingMilestone);
    }

    if (milestones.isEmpty) {
      return const [bathMilestone, groomingMilestone];
    }

    return List.unmodifiable(milestones);
  }
}
