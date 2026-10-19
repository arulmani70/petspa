import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/store_milestone_config.dart';

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
    final kLower = key.toLowerCase();
    IconData icon = Icons.pets_rounded;
    if (kLower.contains('nail')) {
      icon = Icons.content_cut_outlined;
    } else if (kLower.contains('teeth') || kLower.contains('dental')) {
      icon = Icons.health_and_safety_outlined;
    } else if (kLower.contains('medicated')) {
      icon = Icons.medical_services_outlined;
    } else if (kLower.contains('ear')) {
      icon = Icons.hearing_outlined;
    }
    return MilestoneConfig(
      key: key,
      title: formatted,
      shortLabel: formatted.split(' ').first,
      subtitle: 'Record $formatted milestone',
      actionLabel: 'Confirm $formatted',
      icon: icon,
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
  // Walk-in: 12 (Hair Trimming), 13 (Breed Styling)
  // Note: 14 (Nail Trimming), 15 (Ear Cleaning), 16 (Teeth Brushing) are standalone hygiene services,
  // NOT full haircut grooming. They are handled specifically below.
  static const Set<int> groomingOnlyServiceIds = {1, 4, 7, 12, 13};

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
    List<String> bookedServices = const [],
  }) {
    bool needBath = false;
    bool needGrooming = false;
    bool needNail = false;
    bool needTeeth = false;
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
      if (serviceId == 14) {
        needNail = true;
        recognizedAny = true;
      } else if (serviceId == 16) {
        needTeeth = true;
        recognizedAny = true;
      } else if (serviceId == 15) {
        recognizedAny = true;
      } else if (bathOnlyServiceIds.contains(serviceId)) {
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

    // 3. Check Service Name (Primary Service) when serviceId was missing, zero, or didn't resolve bath/grooming
    if (serviceName != null &&
        serviceName.trim().isNotEmpty &&
        serviceName.trim().toLowerCase() != 'service') {
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
      } else {
        if (sLower.contains('bath') || sLower.contains('wash')) {
          needBath = true;
          recognizedAny = true;
        }
        if (sLower.contains('nail') || sLower.contains('paw')) {
          needNail = true;
          recognizedAny = true;
        }
        if (sLower.contains('teeth') || sLower.contains('dental')) {
          needTeeth = true;
          recognizedAny = true;
        }
        if (sLower.contains('groom') ||
            (sLower.contains('trim') && !sLower.contains('nail')) ||
            sLower.contains('styl') ||
            sLower.contains('hair') ||
            (sLower.contains('cut') && !sLower.contains('nail'))) {
          needGrooming = true;
          recognizedAny = true;
        }
      }
    }

    // 4. Check Add-On IDs
    for (final addOnId in addOnIds) {
      if (bathAddOnIds.contains(addOnId)) {
        needBath = true;
        recognizedAny = true;
      }
      if (groomingAddOnIds.contains(addOnId)) {
        needGrooming = true;
        recognizedAny = true;
      }
      if (addOnId == 1) {
        needNail = true;
        recognizedAny = true;
      }
      if (addOnId == 2 || addOnId == 6) {
        needTeeth = true;
        recognizedAny = true;
      }
    }

    // 5. Check Add-On Names (if IDs not provided or secondary detection)
    if (addOns.isNotEmpty) {
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
        if (lower.contains('nail') || lower.contains('paw') || lower.contains('grind')) {
          needNail = true;
          recognizedAny = true;
        }
        if (lower.contains('teeth') || lower.contains('dental')) {
          needTeeth = true;
          recognizedAny = true;
        }
        if (lower.contains('nail') ||
            lower.contains('grind') ||
            lower.contains('teeth') ||
            lower.contains('dental') ||
            lower.contains('furminator') ||
            lower.contains('brush') ||
            lower.contains('dematt') ||
            lower.contains('scissoring') ||
            (lower.contains('trim') && !lower.contains('nail')) ||
            lower.contains('style') ||
            lower.contains('handle')) {
          needGrooming = true;
          recognizedAny = true;
        }
      }
    }

    // 6. Check bookedServices list (when multiple distinct services are booked)
    for (final svc in bookedServices) {
      final lower = svc.trim().toLowerCase();
      if (lower.contains('bath') || lower.contains('wash') || lower.contains('spa')) {
        needBath = true;
        recognizedAny = true;
      }
      if (lower.contains('nail') || lower.contains('paw')) {
        needNail = true;
        recognizedAny = true;
      }
      if (lower.contains('teeth') || lower.contains('dental')) {
        needTeeth = true;
        recognizedAny = true;
      }
      if (lower.contains('groom') ||
          (lower.contains('trim') && !lower.contains('nail')) ||
          lower.contains('styl') ||
          lower.contains('hair') ||
          (lower.contains('cut') && !lower.contains('nail'))) {
        needGrooming = true;
        recognizedAny = true;
      }
    }

    // 7. Graceful fallback for missing or completely invalid service data
    if (!recognizedAny && !needBath && !needGrooming && !needNail && !needTeeth) {
      return const [bathMilestone, groomingMilestone];
    }

    // 8. Combine without duplicates and preserve proper milestone sequence
    final milestones = <String>[];
    if (needBath) {
      milestones.add(bathMilestone);
    }
    if (needGrooming) {
      milestones.add(groomingMilestone);
    }
    if (needNail && !milestones.contains('nail_cut_completed') && !needGrooming) {
      milestones.add('nail_cut_completed');
    }
    if (needTeeth && !milestones.contains('teeth_cleaning_completed') && !needGrooming) {
      milestones.add('teeth_cleaning_completed');
    }

    if (milestones.isEmpty) {
      return const [bathMilestone, groomingMilestone];
    }

    return List.unmodifiable(milestones);
  }

  /// Evaluates whether a [StoreMilestoneConfig] is applicable for a specific [GroomerBooking].
  ///
  /// Combines:
  /// A. Store Configuration (allowed actions, statuses, orders, keys for that storeId).
  /// B. Booking Services (only services selected by the customer for this appointment).
  ///
  /// Guarantees:
  /// - Common in-store milestones (Check-in, Ready for Checkout) are always included.
  /// - Service-specific milestones are included ONLY if the customer booked that service.
  /// - Multiple booked services sharing an action/milestone are deduplicated.
  /// - Unrelated service actions are strictly excluded.
  static bool isConfigApplicableForBooking({
    required StoreMilestoneConfig config,
    required GroomerBooking booking,
  }) {
    // 1. Non-in-store actions are filtered out by isInStoreAction
    if (!config.isInStoreAction) return false;

    // 2. Common milestones are always applicable to all appointments
    if (config.isCheckIn || config.isReadyForCheckout) return true;

    // 3. Explicit Service IDs check if defined on the milestone configuration
    if (config.serviceIds.isNotEmpty) {
      final matchesServiceId = booking.serviceId != null && config.serviceIds.contains(booking.serviceId);
      final matchesPackageId = booking.packageId != null && config.serviceIds.contains(booking.packageId);
      final matchesAddOn = booking.addOnIds.any((id) => config.serviceIds.contains(id));
      if (matchesServiceId || matchesPackageId || matchesAddOn) return true;
      return false;
    }

    // 4. Explicit Service Names check if defined on the milestone configuration
    if (config.services.isNotEmpty) {
      final allNames = booking.allBookedServiceNames.map((s) => s.toLowerCase()).toList();
      final matches = config.services.any((svc) {
        final sLower = svc.trim().toLowerCase();
        return allNames.any((booked) => booked.contains(sLower) || sLower.contains(booked));
      });
      if (matches) return true;
      return false;
    }

    // 5. Semantic Service Stage / Action / Key Classification:
    final keyLower = config.key.toLowerCase();
    final actionLower = config.action.toLowerCase();
    final statusLower = config.status.toLowerCase();
    final titleLower = (config.title ?? '').toLowerCase();

    // Grooming milestones (e.g. grooming_in_progress, grooming_completed, GroomingCompleted)
    if (keyLower.contains('groom') ||
        statusLower.contains('groom') ||
        actionLower.contains('groom')) {
      return booking.requiresGrooming;
    }

    // Bath milestones (e.g. bath_completed, BathCompleted, Bath)
    if (keyLower.contains('bath') ||
        statusLower.contains('bath') ||
        actionLower.contains('bath')) {
      return booking.requiresBath;
    }

    // Nail service milestones (e.g. nail_cut_in_progress, nail_cut_completed, NailCut)
    if (keyLower.contains('nail') ||
        statusLower.contains('nail') ||
        actionLower.contains('nail') ||
        titleLower.contains('nail')) {
      return booking.hasNailService;
    }

    // Teeth / Dental service milestones (e.g. teeth_cleaning_in_progress, teeth_cleaning_completed, TeethCleaning)
    if (keyLower.contains('teeth') ||
        keyLower.contains('dental') ||
        statusLower.contains('teeth') ||
        actionLower.contains('teeth') ||
        actionLower.contains('dental') ||
        titleLower.contains('teeth')) {
      return booking.hasTeethService;
    }

    // Medicated Shampoo / Treatment milestones
    if (keyLower.contains('medicated') ||
        statusLower.contains('medicated') ||
        actionLower.contains('medicated') ||
        titleLower.contains('medicated')) {
      return booking.hasMedicatedService;
    }

    // Ear Cleaning milestones
    if (keyLower.contains('ear') ||
        statusLower.contains('ear') ||
        actionLower.contains('ear') ||
        titleLower.contains('ear')) {
      return booking.hasEarService;
    }

    // De-Shedding milestones
    if (keyLower.contains('de-shed') ||
        keyLower.contains('deshed') ||
        statusLower.contains('deshed') ||
        actionLower.contains('deshed') ||
        titleLower.contains('deshed')) {
      return booking.hasDeSheddingService;
    }

    // 6. Generic custom in-store steps configured for the store (e.g. custom_step_9)
    return true;
  }

  /// Filters and deduplicates store milestone configurations for a specific booking.
  ///
  /// Combines the store's allowed milestone configurations with the customer's booked services,
  /// preserving store-defined order and eliminating duplicate milestones.
  static List<StoreMilestoneConfig> filterMilestonesForBooking({
    required List<StoreMilestoneConfig> storeCatalog,
    required GroomerBooking booking,
  }) {
    if (storeCatalog.isEmpty) {
      return const [];
    }

    final filtered = <StoreMilestoneConfig>[];
    final seenKeys = <String>{};

    for (final config in storeCatalog) {
      if (!config.isInStoreAction) continue;
      if (seenKeys.contains(config.key)) continue;

      if (isConfigApplicableForBooking(config: config, booking: booking)) {
        filtered.add(config);
        seenKeys.add(config.key);
      }
    }

    filtered.sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(filtered);
  }
}
