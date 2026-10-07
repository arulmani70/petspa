import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_header.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours — Project Theme (Black & Neutral White/Grey)
// ─────────────────────────────────────────────────────────────────────────────
const _kBlack      = Color(0xFF111827);
const _kPageBg     = Color(0xFFFAFAFA);
const _kCardBg     = Color(0xFFFFFFFF);
const _kBorder     = Color(0xFFE5E7EB);
const _kSubText    = Color(0xFF6B7280);
const _kLightGrey  = Color(0xFFF3F4F6);

// Base URL as a plain string constant — avoids const-expression issue
// with AppConstants (which holds non-const Color fields).
const _kBaseUrl = 'https://shear-heaven-api.genzcodershub.com';

// ─────────────────────────────────────────────────────────────────────────────
class BookingServicePageMobile extends StatefulWidget {
  const BookingServicePageMobile({super.key});

  @override
  State<BookingServicePageMobile> createState() =>
      _BookingServicePageMobileState();
}

class _BookingServicePageMobileState extends State<BookingServicePageMobile> {
  late final BookingDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = ServicesLocator.bookingDraft;

    // Pre-select a service if passed via GoRouter extra
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map && extra['service'] != null) {
        _draft.setService(extra['service'] as Map<String, dynamic>);
      }
    });
  }

  // ── summary for bottom bar ────────────────────────────────────────────────
  String _buildSummary() {
    final svcName    = _draft.service?['service_name']?.toString() ?? '';
    final addOnCount = _draft.addOns.length;
    if (svcName.isEmpty && addOnCount == 0) return 'No service selected';
    final parts = <String>[];
    if (svcName.isNotEmpty) parts.add(svcName);
    if (addOnCount > 0) {
      parts.add('+$addOnCount add-on${addOnCount > 1 ? 's' : ''}');
    }
    return parts.join('  ·  ');
  }

  void _onContinue() {
    if (_draft.service == null) {
      ToastUtil.showErrorToast(context, 'Please select a service.');
      return;
    }
    context.pushNamed(RouteNames.bookingDateTime);
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServiceBloc, ServiceState>(
      builder: (context, state) {
        return ListenableBuilder(
          listenable: _draft,
          builder: (ctx, _) {
            final bs      = state.bookingServices;
            final hasPet  = _draft.pet != null;
            final petName = _draft.pet?['pet_name']?.toString() ?? 'your pet';

            if (state.status == ServiceStatus.loading ||
                state.status == ServiceStatus.initial) {
              return _LoadingScaffold(petName: petName, hasPet: hasPet);
            }

            if (state.status == ServiceStatus.failure || bs == null) {
              return _ErrorScaffold(
                message: state.message,
                onRetry: () =>
                    context.read<ServiceBloc>().add(const InitializeServices()),
                petName: petName,
                hasPet : hasPet,
              );
            }

            // Build tab list — breeds only when no pet selected
            final tabs     = <_TabDef>[];
            final tabViews = <Widget>[];

            if (!hasPet && bs.breeds.isNotEmpty) {
              tabs.add(const _TabDef(label: 'Breed', icon: Icons.pets));
              tabViews.add(_BreedTab(breeds: bs.breeds, draft: _draft));
            }
            if (bs.packages.isNotEmpty) {
              tabs.add(const _TabDef(label: 'Packages', icon: Icons.auto_awesome));
              tabViews.add(_PackageTab(packages: bs.packages, draft: _draft));
            }
            if (bs.addOns.isNotEmpty) {
              tabs.add(const _TabDef(label: 'Add-Ons', icon: Icons.add_circle_outline));
              tabViews.add(_AddOnTab(addOns: bs.addOns, draft: _draft));
            }
            if (bs.walkIn.isNotEmpty) {
              tabs.add(const _TabDef(label: 'Walk-In', icon: Icons.directions_walk));
              tabViews.add(_WalkInTab(items: bs.walkIn, draft: _draft));
            }

            if (tabs.isEmpty) {
              return _EmptyScaffold(
                petName: petName,
                hasPet : hasPet,
                onRetry: () =>
                    context.read<ServiceBloc>().add(const InitializeServices()),
              );
            }

            final canContinue = _draft.service != null;
            return DefaultTabController(
              key: ValueKey('tabs_${tabs.length}_$hasPet'),
              length: tabs.length,
              child: Scaffold(
                backgroundColor: _kPageBg,
                body: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Header
                      BookingHeader(
                        title   : 'Select Service',
                        step    : 2,
                        subtitle: hasPet
                            ? 'Step 2 of 4 — Booking for $petName'
                            : 'Step 2 of 4 — Choose a Service',
                      ),

                      // Pet strip (shown only when pet pre-selected)
                      if (hasPet) _PetStrip(draft: _draft),

                      // Tab bar
                      _ServiceTabBar(tabs: tabs),

                      // Selected-service black banner
                      if (canContinue) _SelectedBanner(draft: _draft),

                      // Tab content
                      Expanded(
                        child: TabBarView(
                          physics: const ClampingScrollPhysics(),
                          children: tabViews,
                        ),
                      ),

                      // Bottom action bar
                      _BottomBar(
                        summary    : _buildSummary(),
                        canContinue: canContinue,
                        onContinue : _onContinue,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab definition
// ─────────────────────────────────────────────────────────────────────────────
class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef({required this.label, required this.icon});
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab bar
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceTabBar extends StatelessWidget {
  final List<_TabDef> tabs;
  const _ServiceTabBar({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        indicatorColor      : _kBlack,
        indicatorWeight     : 2.8,
        labelColor          : _kBlack,
        unselectedLabelColor: _kSubText,
        labelStyle  : AppFonts.poppins(size: 13, weight: FontWeight.w600),
        unselectedLabelStyle: AppFonts.poppins(size: 13),
        isScrollable: tabs.length > 3,
        tabAlignment: tabs.length > 3
            ? TabAlignment.start
            : TabAlignment.fill,
        tabs: tabs.map((t) => Tab(text: t.label, height: 42)).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pet strip
// ─────────────────────────────────────────────────────────────────────────────
class _PetStrip extends StatelessWidget {
  final BookingDraft draft;
  const _PetStrip({required this.draft});

  @override
  Widget build(BuildContext context) {
    final name   = draft.pet?['pet_name']?.toString() ?? '';
    final breed  = draft.pet?['breed']?.toString()    ?? '';
    final weight = draft.pet?['weight']?.toString()   ?? '';
    final photo  = draft.pet?['photo_url']?.toString();

    return Container(
      color  : Colors.white,
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 12),
      child  : Row(
        children: [
          Container(
            width: 40, height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: _NetworkOrIcon(url: photo, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(name,
                      style: AppFonts.poppins(size: 13, weight: FontWeight.w600)),
                if (breed.isNotEmpty)
                  Text(
                    '$breed${weight.isNotEmpty ? '  ·  $weight' : ''}',
                    style: AppFonts.poppins(
                        size: 11, color: _kSubText),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.pushNamed(RouteNames.petSelect),
            child: Text('Change',
                style: AppFonts.poppins(
                    size: 12, weight: FontWeight.w600, color: _kBlack)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected banner
// ─────────────────────────────────────────────────────────────────────────────
class _SelectedBanner extends StatelessWidget {
  final BookingDraft draft;
  const _SelectedBanner({required this.draft});

  @override
  Widget build(BuildContext context) {
    final svcName = draft.service?['service_name']?.toString() ?? '';
    final cnt     = draft.addOns.length;
    if (svcName.isEmpty) return const SizedBox.shrink();

    return Container(
      width  : double.infinity,
      color  : _kBlack,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
      child  : Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              svcName +
                  (cnt > 0 ? ' + $cnt add-on${cnt > 1 ? 's' : ''}' : ''),
              style   : AppFonts.poppins(
                  size: 12, weight: FontWeight.w500, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              draft.setService(null);
              draft.addOns.clear();
            },
            child: Text('Clear',
                style: AppFonts.poppins(
                    size: 11, color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BREED TAB
// ─────────────────────────────────────────────────────────────────────────────
class _BreedTab extends StatelessWidget {
  final List<ServiceItem> breeds;
  final BookingDraft draft;
  const _BreedTab({required this.breeds, required this.draft});

  @override
  Widget build(BuildContext context) {
    // Group by breed name (part before " — ")
    final grouped = <String, List<ServiceItem>>{};
    for (final b in breeds) {
      final key = b.name.split(' — ').first.trim();
      grouped.putIfAbsent(key, () => []).add(b);
    }

    return ListenableBuilder(
      listenable: draft,
      builder: (ctx, _) => ListView(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 120),
        children: [
          // Info hint
          const _InfoTip(
            icon   : Icons.info_outline,
            text   : "Select a grooming service for your pet's breed size.",
            bgColor: _kLightGrey,
            fgColor: _kBlack,
          ),
          const SizedBox(height: 4),
          ...grouped.entries.expand((entry) => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(entry.key,
                  style: AppFonts.parkinsans(
                      size: 15, weight: FontWeight.w700, color: _kBlack)),
            ),
            ...entry.value.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServiceCard(
                item      : item,
                isSelected: draft.service?['serviceId'] == item.id,
                isAddOn   : false,
                onTap     : () => draft.setService(item.toMap()),
              ),
            )),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PACKAGES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PackageTab extends StatelessWidget {
  final List<ServiceItem> packages;
  final BookingDraft draft;
  const _PackageTab({required this.packages, required this.draft});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (ctx, _) => ListView(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 120),
        children: packages.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ServiceCard(
            item      : item,
            isSelected: draft.service?['packageId'] == item.id,
            isAddOn   : false,
            onTap     : () => draft.setService(item.toMap()),
          ),
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD-ONS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AddOnTab extends StatelessWidget {
  final List<ServiceItem> addOns;
  final BookingDraft draft;
  const _AddOnTab({required this.addOns, required this.draft});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (ctx, _) => ListView(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 120),
        children: [
          const _InfoTip(
            icon   : Icons.add_circle_outline,
            text   : 'Add-ons can be combined with any grooming service.',
            bgColor: _kLightGrey,
            fgColor: _kBlack,
          ),
          const SizedBox(height: 4),
          ...addOns.map((item) {
            final isSelected = draft.addOns
                .any((a) => a['addOnId'] == item.id || a['id'] == item.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServiceCard(
                item      : item,
                isSelected: isSelected,
                isAddOn   : true,
                onTap     : () => draft.toggleAddOn(item.toMap()),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN TAB
// ─────────────────────────────────────────────────────────────────────────────
class _WalkInTab extends StatelessWidget {
  final List<ServiceItem> items;
  final BookingDraft draft;
  const _WalkInTab({required this.items, required this.draft});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (ctx, _) => ListView(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 120),
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ServiceCard(
            item      : item,
            isSelected: draft.service?['serviceId'] == item.id,
            isAddOn   : false,
            onTap     : () => draft.setService(item.toMap()),
          ),
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final ServiceItem item;
  final bool isSelected;
  final bool isAddOn;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.item,
    required this.isSelected,
    required this.isAddOn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color       : _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border      : Border.all(
            color: isSelected ? _kBlack : _kBorder,
            width: isSelected ? 2.0   : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color     : isSelected
                  ? Colors.black.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 10 : 6,
              offset    : const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width : 90,
                height: 90,
                child : _ServiceImage(item: item),
              ),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(item.name,
                            style: AppFonts.poppins(
                                size  : 14,
                                weight: FontWeight.w600,
                                color : _kBlack),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      // Select indicator
                      AnimatedContainer(
                        duration    : const Duration(milliseconds: 150),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color       : isSelected ? _kBlack : Colors.white,
                          borderRadius: isAddOn
                              ? BorderRadius.circular(6)
                              : BorderRadius.circular(11),
                          border: Border.all(
                            color: isSelected ? _kBlack : _kBorder,
                            width: 1.8,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),

                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.description,
                        style: AppFonts.poppins(
                            size  : 11,
                            weight: FontWeight.w300,
                            color : _kSubText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],

                  const SizedBox(height: 8),

                  Wrap(
                    spacing   : 6,
                    runSpacing: 4,
                    children  : [
                      if (item.priceDisplay.isNotEmpty)
                        _Badge(
                          icon : Icons.attach_money,
                          label: item.priceDisplay,
                          color: _kBlack,
                          bg   : _kLightGrey,
                        ),
                      if (item.durationMinutes > 0)
                        _Badge(
                          icon : Icons.schedule_outlined,
                          label: _fmtDur(item.durationMinutes),
                          color: _kSubText,
                          bg   : _kLightGrey,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDur(int m) {
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info tip banner
// ─────────────────────────────────────────────────────────────────────────────
class _InfoTip extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color    bgColor;
  final Color    fgColor;
  const _InfoTip({
    required this.icon,
    required this.text,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding    : const EdgeInsets.all(12),
      margin     : const EdgeInsets.only(bottom: 12),
      decoration : BoxDecoration(
        color       : bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppFonts.poppins(
                    size: 12, color: fgColor)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge pill
// ─────────────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final Color    bg;
  const _Badge({
    required this.icon, required this.label,
    required this.color, required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding    : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration : BoxDecoration(
        color       : bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: AppFonts.poppins(
                  size: 11, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service image widget
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceImage extends StatelessWidget {
  final ServiceItem item;
  const _ServiceImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;

    Widget placeholder() {
      final IconData icon;
      if (item.isPackage) {
        icon = Icons.auto_awesome;
      } else if (item.isAddOn) {
        icon = Icons.add_circle_outline;
      } else if (item.name.toLowerCase().contains('bath')) {
        icon = Icons.shower_outlined;
      } else {
        icon = Icons.content_cut;
      }
      return Container(
        width    : double.infinity,
        height   : double.infinity,
        color    : _kLightGrey,
        alignment: Alignment.center,
        child    : Icon(icon, size: 30, color: _kSubText),
      );
    }

    if (url == null || url.isEmpty) return placeholder();

    final fullUrl = url.startsWith('http') ? url : '$_kBaseUrl$url';

    return Image.network(
      fullUrl,
      width        : double.infinity,
      height       : double.infinity,
      fit          : BoxFit.cover,
      errorBuilder : (ctx, err, st) => placeholder(),
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Container(
          width    : double.infinity,
          height   : double.infinity,
          color    : const Color(0xFFF3F4F6),
          alignment: Alignment.center,
          child    : const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kBlack),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Network image or icon fallback
// ─────────────────────────────────────────────────────────────────────────────
class _NetworkOrIcon extends StatelessWidget {
  final String? url;
  final double  size;
  const _NetworkOrIcon({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      final full = url!.startsWith('http') ? url! : '$_kBaseUrl$url';
      return Image.network(
        full,
        fit         : BoxFit.cover,
        errorBuilder: (ctx, err, st) =>
            Icon(Icons.pets, size: size, color: _kSubText),
      );
    }
    return Icon(Icons.pets, size: size, color: _kSubText);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom action bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final String       summary;
  final bool         canContinue;
  final VoidCallback onContinue;
  const _BottomBar({
    required this.summary,
    required this.canContinue,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color  : Colors.white,
      padding: EdgeInsets.fromLTRB(
          17, 14, 17, 18 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary pill
          Container(
            height    : 40,
            padding   : const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color       : const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  canContinue
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size : 15,
                  color: canContinue ? _kBlack : _kSubText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(summary,
                      style: AppFonts.poppins(
                          size  : 13,
                          weight: canContinue
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color : canContinue ? _kBlack : _kSubText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Continue button
          GestureDetector(
            onTap: canContinue ? onContinue : null,
            child: AnimatedContainer(
              duration    : const Duration(milliseconds: 200),
              width       : double.infinity,
              height      : 54,
              alignment   : Alignment.center,
              decoration  : BoxDecoration(
                gradient    : canContinue
                    ? const LinearGradient(
                        colors: [Color(0xFF3A3A3A), Colors.black],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color       : canContinue
                    ? null
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(30),
                boxShadow   : canContinue
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text('Continue',
                  style: AppFonts.parkinsans(
                      size  : 18,
                      weight: FontWeight.w700,
                      color : Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State scaffolds
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingScaffold extends StatelessWidget {
  final String petName;
  final bool   hasPet;
  const _LoadingScaffold({required this.petName, required this.hasPet});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _kPageBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              BookingHeader(
                title   : 'Select Service',
                step    : 2,
                subtitle: hasPet
                    ? 'Step 2 of 4 — Booking for $petName'
                    : 'Step 2 of 4 — Choose a Service',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(17, 16, 17, 120),
                  children: const [
                    // Tab bar skeleton
                    ShimmerBox(width: double.infinity, height: 42, radius: 10),
                    SizedBox(height: 16),
                    // Service cards skeleton
                    ListCardSkeleton(), SizedBox(height: 14),
                    ListCardSkeleton(), SizedBox(height: 14),
                    ListCardSkeleton(), SizedBox(height: 14),
                    ListCardSkeleton(), SizedBox(height: 14),
                    ListCardSkeleton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ErrorScaffold extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  final String       petName;
  final bool         hasPet;
  const _ErrorScaffold({
    required this.message,
    required this.onRetry,
    required this.petName,
    required this.hasPet,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _kPageBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              BookingHeader(
                title   : 'Select Service',
                step    : 2,
                subtitle: hasPet
                    ? 'Step 2 of 4 — Booking for $petName'
                    : 'Step 2 of 4 — Choose a Service',
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.wifi_off_rounded,
                              size: 34, color: Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 18),
                        Text('Unable to load services',
                            style: AppFonts.parkinsans(
                                size  : 17,
                                weight: FontWeight.w600,
                                color : _kBlack),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          message.contains('missing_identifiers')
                              ? 'Store information is unavailable.\nPlease try again.'
                              : 'Could not load services.\nPlease check your connection.',
                          style: AppFonts.poppins(
                              size : 13, color: _kSubText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          onPressed: onRetry,
                          icon : const Icon(Icons.refresh, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlack,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            textStyle: AppFonts.poppins(
                                size: 14, weight: FontWeight.w600),
                          ),
                        ),
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

class _EmptyScaffold extends StatelessWidget {
  final String       petName;
  final bool         hasPet;
  final VoidCallback onRetry;
  const _EmptyScaffold({
    required this.petName,
    required this.hasPet,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _kPageBg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              BookingHeader(
                title   : 'Select Service',
                step    : 2,
                subtitle: hasPet
                    ? 'Step 2 of 4 — Booking for $petName'
                    : 'Step 2 of 4 — Choose a Service',
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 52, color: _kSubText),
                        const SizedBox(height: 14),
                        Text('No services available',
                            style: AppFonts.parkinsans(
                                size: 17, weight: FontWeight.w600,
                                color: _kBlack)),
                        const SizedBox(height: 8),
                        Text(
                          'No services are available for this location.',
                          style: AppFonts.poppins(
                              size: 13, color: _kSubText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon : const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: TextButton.styleFrom(
                            foregroundColor: _kBlack,
                            textStyle: AppFonts.poppins(
                                size: 14, weight: FontWeight.w600),
                          ),
                        ),
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
