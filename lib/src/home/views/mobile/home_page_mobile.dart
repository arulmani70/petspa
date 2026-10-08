import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/account/repos/notification_repository.dart';
import 'package:shear_heaven_pet_spa/src/auth/bloc/auth_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/offer_details_dialog.dart';
import 'package:shear_heaven_pet_spa/src/home/views/mobile/gallery_view.dart';

class HomePageMobile extends StatefulWidget {
  const HomePageMobile({super.key});

  @override
  State<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends State<HomePageMobile> {
  String _name = 'Guest';
  Timer? _popupTimer;
  StreamSubscription<AppNotification>? _realtimeNotificationSub;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initRealtimeNotifications();
    try {
      if (GetIt.I.isRegistered<NotificationRepository>()) {
        ServicesLocator.notificationRepository.refreshUnreadCount();
      }
    } catch (_) {}
    try {
      context.read<PetBloc>().add(const InitializePets());
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _popupTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          _showOffersPopup(context);
        }
      });
    });
  }

  void _initRealtimeNotifications() {
    try {
      if (GetIt.I.isRegistered<NotificationRepository>() &&
          GetIt.I.isRegistered<CustomerSocketService>()) {
        ServicesLocator.notificationRepository.connectRealtimeNotifications();
        _realtimeNotificationSub?.cancel();
        _realtimeNotificationSub = ServicesLocator
            .notificationRepository
            .realtimeNotificationStream
            .listen((notif) {
              if (!mounted) return;
              ToastUtil.showInfoToast(
                context,
                notif.title.isNotEmpty
                    ? notif.title
                    : 'New notification received',
              );
            });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    _realtimeNotificationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final isLoggedIn = ServicesLocator.sessionService.isLoggedIn;
    final user = await ServicesLocator.authRepository.getCurrentUser();
    if (!mounted) return;
    setState(() {
      final name = isLoggedIn
          ? (user?[Constants.database.COLUMN_NAME]?.toString() ?? 'Alexander')
          : 'Guest';
      _name = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              ServiceBloc(repository: ServicesLocator.serviceRepository)
                ..add(const InitializeServices()),
        ),
        BlocProvider(
          create: (context) =>
              PetBloc(repository: ServicesLocator.petRepository)
                ..add(const InitializePets()),
        ),
      ],
      child: BlocBuilder<ServiceBloc, ServiceState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: const Color(0xFFFAFAFA),
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: RefreshIndicator(
                    color: const Color(0xFF000000),
                    onRefresh: () async {
                      final serviceBloc = context.read<ServiceBloc>();
                      await _loadUser();
                      try {
                        if (GetIt.I.isRegistered<NotificationRepository>()) {
                          await ServicesLocator.notificationRepository
                              .refreshUnreadCount();
                        }
                      } catch (_) {}
                      serviceBloc.add(const RefreshServices());
                    },
                    child: ListView(
                      padding: const EdgeInsets.only(top: 14, bottom: 120),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildHeader(),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildPromoBanner(),
                        ),
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildCategories(context),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 17),
                          child: _buildSpecialOffers(context),
                        ),
                        const SizedBox(height: 30),
                        Padding(
                          padding: const EdgeInsets.only(left: 17),
                          child: _buildMyPets(context),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildSectionHeader(
                            'Popular Services',
                            () => context.goNamed(RouteNames.services),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildServicesGrid(state),
                        ),
                        const SizedBox(height: 22),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildViewButton(
                            'View All Services',
                            () => context.goNamed(RouteNames.services),
                          ),
                        ),
                        const SizedBox(height: 38),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildSectionHeader(
                            'Popular Packages',
                            () => context.pushNamed(RouteNames.packages),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildPackagesList(state),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildViewButton(
                            'View More Packages',
                            () => context.pushNamed(RouteNames.packages),
                          ),
                        ),
                        const SizedBox(height: 38),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildSectionHeader('Why Choose Us', () {}),
                        ),
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildWhyChooseUs(),
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: _buildBottomCta(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Group 76018 @ (17,61) 356x80 - profile header card
  Widget _buildHeader() {
    return Container(
      height: 80,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 20)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await context.pushNamed(RouteNames.profile);
                  if (mounted) {
                    _loadUser();
                  }
                },
                child: Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: FigmaImage(
                          asset: 'assets/images/common/avatar.png',
                          fit: BoxFit.cover,
                          fallback: Container(
                            color: const Color(0xFFEEEEEE),
                            alignment: Alignment.center,
                            child: Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : 'A',
                              style: AppFonts.poppins(
                                size: 22,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Hi, $_name',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.poppins(
                                    size: 18,
                                    weight: FontWeight.w500,
                                    height: 17.579 / 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SvgPicture.asset(
                                'assets/images/home/fi_17895307_1_917.svg',
                                width: 17,
                                height: 17,
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/images/common/icon_pin.svg',
                                width: 8,
                                height: 10,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.location_on,
                                      size: 10,
                                      color: Colors.black,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'California',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.poppins(
                                    size: 14,
                                    weight: FontWeight.w400,
                                    height: 17.579 / 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Notifications',
                  child: Material(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () async {
                        await context.pushNamed(RouteNames.notifications);
                        try {
                          if (GetIt.I.isRegistered<NotificationRepository>()) {
                            ServicesLocator.notificationRepository
                                .refreshUnreadCount();
                          }
                        } catch (_) {}
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: ValueListenableBuilder<int>(
                          valueListenable:
                              GetIt.I.isRegistered<NotificationRepository>()
                              ? ServicesLocator
                                    .notificationRepository
                                    .unreadCountNotifier
                              : ValueNotifier<int>(0),
                          builder: (context, unreadCount, child) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/home/fi_2645890_1_923.svg',
                                  width: 24,
                                  height: 24,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.notifications_none,
                                        color: Colors.black,
                                        size: 24,
                                      ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Center(
                                        child: Text(
                                          unreadCount > 99
                                              ? '99+'
                                              : '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Logout',
                  child: Material(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => _showLogoutDialog(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.logout_outlined,
                          color: Colors.black,
                          size: 22,
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout',
            style: AppFonts.poppins(
              size: 20,
              weight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: AppFonts.poppins(
              size: 14,
              weight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.black12),
                ),
              ),
              child: Text(
                'Cancel',
                style: AppFonts.productSans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(const LogoutSubmitted());
                context.goNamed(RouteNames.login);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Logout',
                style: AppFonts.productSans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Group 76019 @ (17,155) 356x183 - hero banner
  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      height: 183,
      decoration: const BoxDecoration(
        color: Color(0xFF8DC8E8),
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/common/welcome_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),

            // Linear gradient overlay: soft white fade on the left for text legibility,
            // fading smoothly to transparent on the right so the sky and dog are vibrant.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.45, 0.70, 1.0],
                    colors: const [
                      Colors.white,
                      Color(0xDDFFFFFF),
                      Color(0x33FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              right: -10,
              bottom: 0,
              child: SizedBox(
                width: 155,
                height: 165,
                child: FigmaImage(
                  asset: 'assets/images/home/promo_dog.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                  fallback: Icon(
                    Icons.pets,
                    size: 160,
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 115, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Where Every\nPet Gets The Royal\nTreatment',
                    style: AppFonts.parkinsans(
                      size: 18,
                      weight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/home/icon_star_gold.svg',
                        width: 12,
                        height: 12,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Color(0xFFF5B417),
                            ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Trusted by 35k+ pet parents',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.poppins(
                            size: 11.5,
                            weight: FontWeight.w600,
                            height: 20 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => context.goNamed(RouteNames.petSelect),
                    child: Container(
                      width: 170,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(
                        'Book Appointment',
                        textAlign: TextAlign.center,
                        style: AppFonts.parkinsans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: Colors.white,
                          height: 20 / 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Group 76017 @ (17,363) - 4 white 80x80 rounded tiles (radius 20) with their
  // Figma icon SVGs centered, and Poppins Medium 12 labels below (10px gap).
  Widget _buildCategories(BuildContext context) {
    const items =
        <({String icon, double iconWidth, double iconHeight, String label})>[
          (
            icon: 'assets/images/home/cat_icon_0.png',
            iconWidth: 97,
            iconHeight: 122,
            label: 'Book Now',
          ),
          (
            icon: 'assets/images/home/cat_icon_1.png',
            iconWidth: 97,
            iconHeight: 122,
            label: 'Pets',
          ),
          (
            icon: 'assets/images/home/cat_icon_2.png',
            iconWidth: 97,
            iconHeight: 122,
            label: 'Bookings',
          ),
          (
            icon: 'assets/images/home/cat_icon_3.png',
            iconWidth: 97,
            iconHeight: 122,
            label: 'Gallery',
          ),
        ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickActionTile(
          items[0].icon,
          items[0].iconWidth,
          items[0].iconHeight,
          items[0].label,
          () => context.goNamed(RouteNames.petSelect),
        ),
        _buildQuickActionTile(
          items[1].icon,
          items[1].iconWidth,
          items[1].iconHeight,
          items[1].label,
          () => context.pushNamed(RouteNames.myPets),
        ),
        _buildQuickActionTile(
          items[2].icon,
          items[2].iconWidth,
          items[2].iconHeight,
          items[2].label,
          () => context.goNamed(RouteNames.myBookings),
        ),
        _buildQuickActionTile(
          items[3].icon,
          items[3].iconWidth,
          items[3].iconHeight,
          items[3].label,
          () => GalleryView.show(context),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile(
    String icon,
    double iconWidth,
    double iconHeight,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Image.asset(
        icon,
        width: 80,
        height: 104,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_not_supported,
                size: 30,
                color: Colors.black.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(height: 10),
            Text(label, style: AppFonts.poppins(size: 14)),
          ],
        ),
      ),
    );
  }

  // Section header with title + "View All" arrow
  Widget _buildSectionHeader(String title, VoidCallback onAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.parkinsans(
              size: 20,
              weight: FontWeight.w600,
              height: 26.949 / 20,
            ),
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Row(
            children: [
              // Text(
              //   "View All",
              //   style: AppFonts.poppins(
              //     size: 14,
              //     weight: FontWeight.w500,
              //     height: 26.949 / 14,
              //   ),
              // ),
              // const SizedBox(width: 6),
              // Icon(Icons.chevron_right, size: 14, color: Colors.black),
            ],
          ),
        ),
      ],
    );
  }

  // Popular Services — first 4 services from API (walkIn first, then breeds).
  // Each tile shows the API image, name, description and links to ServiceDetailPage.
  Widget _buildServicesGrid(ServiceState state) {
    if (state.status == ServiceStatus.loading) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: const [
                ServiceCardSkeleton(),
                SizedBox(height: 22),
                ServiceCardSkeleton(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: const [
                ServiceCardSkeleton(),
                SizedBox(height: 22),
                ServiceCardSkeleton(),
              ],
            ),
          ),
        ],
      );
    }

    final bs = state.bookingServices;
    // Prefer walkIn services (most approachable) then breeds for the home grid.
    final allForHome = <Map<String, dynamic>>[
      ...(bs?.walkIn ?? []).map((s) => s.toMap()),
      ...(bs?.breeds ?? []).map((s) => s.toMap()),
    ];

    if (allForHome.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Services loading…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    // Take up to 4 services for the 2×2 grid.
    final display = allForHome.take(4).toList();
    // Pad to exactly 4 if fewer than 4 came back.
    while (display.length < 4) {
      display.add(display.first);
    }

    final tiles = display.map((svc) {
      final id = (svc['id'] ?? svc[Constants.database.COLUMN_ID] ?? 0)
          .toString();
      final name =
          svc['service_name']?.toString() ??
          svc[Constants.database.COLUMN_SERVICE_NAME]?.toString() ??
          '';
      String desc =
          svc['description']?.toString() ??
          svc[Constants.database.COLUMN_DESCRIPTION]?.toString() ??
          '';
      if (desc.trim().isEmpty) {
        desc = _defaultShortDescriptionForService(name);
      }
      final imageUrl = svc['imageUrl']?.toString();

      return _ServiceTile(
        name: name,
        description: desc,
        imageUrl: imageUrl,
        onTap: () => context.pushNamed(
          RouteNames.serviceDetail,
          pathParameters: {'serviceId': id},
        ),
      );
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [tiles[0], const SizedBox(height: 22), tiles[1]],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [tiles[2], const SizedBox(height: 22), tiles[3]],
          ),
        ),
      ],
    );
  }

  String _defaultShortDescriptionForService(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('nail')) {
      return 'Safe and gentle paw nail trimming';
    } else if (lower.contains('ear')) {
      return 'Hygienic ear check & gentle cleansing';
    } else if (lower.contains('teeth') || lower.contains('tooth')) {
      return 'Oral hygiene & breath freshening';
    } else if (lower.contains('flea') || lower.contains('tick')) {
      return 'Soothing flea and tick protection';
    } else if (lower.contains('grooming') && lower.contains('bathing')) {
      return 'Complete wash, coat care & grooming';
    } else if (lower.contains('full grooming')) {
      return 'Full head-to-paw grooming & styling';
    } else if (lower.contains('bath') || lower.contains('bathing') || lower.contains('blow dry')) {
      return 'Gentle bath, blow dry & coat brush';
    } else if (lower.contains('hair') || lower.contains('trim') || lower.contains('haircut')) {
      return 'Precision coat trimming & styling';
    } else if (lower.contains('breed')) {
      return 'Custom styling tailored to pet breed';
    } else if (lower.contains('puppy')) {
      return 'Gentle introductory grooming for pups';
    } else if (lower.contains('shed')) {
      return 'Deep de-shedding & fur reduction';
    } else if (lower.contains('skin') || lower.contains('spa')) {
      return 'Nourishing skin care & spa treatment';
    }
    return 'Professional pet care & grooming';
  }

  // Popular Packages — first 3 packages from API. Real price, real name, real image.
  Widget _buildPackagesList(ServiceState state) {
    if (state.status == ServiceStatus.loading) {
      return const Column(
        children: [
          PackageCardSkeleton(),
          SizedBox(height: 10),
          PackageCardSkeleton(),
          SizedBox(height: 10),
          PackageCardSkeleton(),
        ],
      );
    }

    final bs = state.bookingServices;
    if (bs == null || bs.packages.isEmpty) return const SizedBox.shrink();

    final packages = bs.packages.take(3).toList();
    final cards = <Widget>[];

    for (var i = 0; i < packages.length; i++) {
      final p = packages[i];
      final dark = i % 2 != 0;
      cards.add(
        _PriceCard(
          title: p.name,
          subtitle: p.description,
          price: p.priceDisplay.isNotEmpty ? p.priceDisplay : '',
          imageUrl: p.imageUrl,
          dark: dark,
          onBook: () => context.goNamed(RouteNames.petSelect),
          onDetail: () => context.pushNamed(
            RouteNames.serviceDetail,
            pathParameters: {'serviceId': p.id.toString()},
          ),
        ),
      );
      if (i < packages.length - 1) cards.add(const SizedBox(height: 10));
    }

    return Column(children: cards);
  }

  Widget _buildViewButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFF3A3A3A), Colors.black],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(29),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 18,
              weight: FontWeight.w600,
              height: 14 / 18,
            ),
          ),
        ),
      ),
    );
  }

  // Group 76031 - Why Choose Us
  Widget _buildWhyChooseUs() {
    final items = [
      (
        icon: 'assets/images/home/fi_2447825_1_1033.svg',
        label: 'Stress Free\nSpace',
        tint: true,
      ),
      (
        icon: 'assets/images/home/fi_1962520_1_1043.svg',
        label: 'Safe Products',
        tint: true,
      ),
      (
        icon: 'assets/images/home/icon_medal.svg',
        label: '20+ Years Of\nExperience',
        tint: false,
      ),
    ];
    Widget card(String icon, String label, bool tint) {
      return Container(
        width: double.infinity,
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              icon,
              width: 31,
              height: 31,
              colorFilter: tint
                  ? const ColorFilter.mode(Colors.black, BlendMode.srcIn)
                  : null,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.verified, size: 31, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppFonts.poppins(
                  size: 14,
                  weight: FontWeight.w500,
                  height: 16 / 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        card(items[0].icon, items[0].label, items[0].tint),
        const SizedBox(height: 8),
        card(items[1].icon, items[1].label, items[1].tint),
        const SizedBox(height: 8),
        card(items[2].icon, items[2].label, items[2].tint),
      ],
    );
  }

  // Group 76030 @ (17,2129) 356x156 - bottom CTA
  // Group 76030 @ (17,2129) 356x156 - bottom CTA card (Rectangle 152 = the
  // home_bottom_card.png image + white 80% overlay, radius 24, drop shadow).
  // Heading @ (72,31) 213x44 Parkinsans Bold 700 20 (lh 22, TITLE case, center);
  // button Rectangle 137 @ (84,86) 188x38 radius 40 with the #3A3A3A->black
  // horizontal gradient and 'Book Appointment' Parkinsans SemiBold 600 14 white.
  Widget _buildBottomCta() {
    return Container(
      width: double.infinity,
      height: 156,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 20)],
        image: figmaDecorationImage('assets/images/home/home_bottom_card.png'),
      ),
      foregroundDecoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ready for a happier, healthier pet?',
            textAlign: TextAlign.center,
            style: AppFonts.parkinsans(
              size: 20,
              weight: FontWeight.w700,
              height: 22 / 20,
            ),
          ),
          const SizedBox(height: 11),
          GestureDetector(
            onTap: () => context.goNamed(RouteNames.petSelect),
            child: Container(
              width: 188,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3A3A3A), Colors.black],
                ),
              ),
              child: Text(
                'Book Appointment',
                textAlign: TextAlign.center,
                style: AppFonts.parkinsans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Colors.white,
                  height: 22 / 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildSpecialOffers(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 17.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Special Offers',
                style: AppFonts.parkinsans(
                  size: 20,
                  weight: FontWeight.w600,
                  height: 1.35,
                  color: Colors.black,
                ),
              ),
            ),
            InkWell(
              onTap: () => context.pushNamed(RouteNames.offers),
              child: Row(
                children: [
                  Text(
                    'View Offers',
                    style: AppFonts.poppins(
                      size: 14,
                      weight: FontWeight.w500,
                      height: 1.92,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.black),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 256,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            _buildSpecialOfferCard(
              context: context,
              badgeText: '50% OFF',
              title: '50% Off Full Grooming for New Pets!',
              expiry: 'Ends in 2 days',
              code: 'PAWSOME50',
              imagePath: 'assets/images/common/offer_1.png',
            ),
            const SizedBox(width: 14),
            _buildSpecialOfferCard(
              context: context,
              badgeText: 'FREE ADD-ON',
              title: 'Summer Splash: Free Nail Trimming',
              expiry: 'Ends Aug 20',
              code: 'PAWSOME50',
              imagePath: 'assets/images/common/offer_2.png',
            ),
            const SizedBox(width: 14),
            _buildSpecialOfferCard(
              context: context,
              badgeText: 'REFER & EARN',
              title: 'Refer a Friend, Get 20% Off',
              expiry: 'No expiry',
              code: 'PAWSOME50',
              imagePath: 'assets/images/common/offer_3.png',
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildSpecialOfferCard({
  required BuildContext context,
  required String badgeText,
  required String title,
  required String expiry,
  required String code,
  required String imagePath,
}) {
  return GestureDetector(
    onTap: () => _showOffersPopup(context),
    child: Container(
      width: 259,
      height: 256,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Image placeholder
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 143,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => Container(color: Colors.grey),
              ),
            ),
          ),
          // Badge
          Positioned(
            top: 11,
            left: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                badgeText,
                style: AppFonts.poppins(
                  size: 12,
                  weight: FontWeight.w700,
                  height: 1.83,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // Content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 113,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 11.0,
                vertical: 5.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.parkinsans(
                        size: 14,
                        weight: FontWeight.w600,
                        height: 1.25,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: Color(0xFFA30000),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          expiry,
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w500,
                            color: const Color(0xFFA30000),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F2),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              code,
                              style: AppFonts.parkinsans(
                                size: 12,
                                weight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        InkWell(
                          onTap: () => _showOffersPopup(context),
                          child: Container(
                            width: 82,
                            height: 29,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Text(
                                'Claim',
                                style: AppFonts.parkinsans(
                                  size: 14,
                                  weight: FontWeight.w700,
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
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildMyPets(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 17.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'My Pets',
                style: TextStyle(
                  fontFamily: 'Parkinsans',
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  height: 1.35,
                  color: Colors.black,
                ),
              ),
            ),
            InkWell(
              onTap: () => context.goNamed(RouteNames.myPets),
              child: Row(
                children: const [
                  Text(
                    'View Offers',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.92,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios, size: 10, color: Colors.black),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      BlocBuilder<PetBloc, PetState>(
        builder: (context, state) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                ...state.pets.asMap().entries.map((entry) {
                  final pet = entry.value;
                  final petId = pet[Constants.database.COLUMN_ID] as int;
                  final name =
                      pet[Constants.database.COLUMN_PET_NAME]?.toString() ?? '';
                  final photoUrl = pet[Constants.database.COLUMN_PHOTO_URL]
                      ?.toString();
                  final fallbackAsset = entry.key.isEven
                      ? 'assets/images/common/pet_1.png'
                      : 'assets/images/common/pet_2.png';
                  return Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: _buildPetAvatar(
                      context,
                      petId,
                      photoUrl,
                      fallbackAsset,
                      name,
                    ),
                  );
                }),
                InkWell(
                  onTap: () => context.goNamed(RouteNames.createPet),
                  child: Column(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Add Pet',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

Widget _buildPetAvatar(
  BuildContext context,
  int petId,
  String? photoUrl,
  String fallbackAsset,
  String name,
) {
  return InkWell(
    onTap: () {
      context.read<PetBloc>().add(SelectPet(petId));
      context.goNamed(RouteNames.petSelect);
    },
    child: Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            image: DecorationImage(
              image: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage('${Constants.app.BASE_URL}$photoUrl')
                        as ImageProvider
                  : AssetImage(fallbackAsset),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    ),
  );
}

void _showOffersPopup(BuildContext context) {
  OfferDetailsDialog.show(context);
}

class _ServiceTile extends StatelessWidget {
  final String name;
  final String description;
  final String? imageUrl;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.name,
    required this.description,
    required this.onTap,
    this.imageUrl,
  });

  // Fallback local asset when API imageUrl is absent
  static const _kBaseUrl = 'https://shear-heaven-api.genzcodershub.com';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 172 / 152,
              child: _ServiceImageWidget(
                imageUrl: imageUrl,
                name: name,
                baseUrl: _kBaseUrl,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              size: 12,
              weight: FontWeight.w400,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders an API imageUrl (full or relative) with graceful local-asset fallback.
class _ServiceImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String baseUrl;
  const _ServiceImageWidget({
    required this.imageUrl,
    required this.name,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    Widget placeholder() {
      final localAsset = serviceAssetFor(name);
      if (localAsset != null) {
        return FigmaImage(
          asset: localAsset,
          fit: BoxFit.cover,
          fallback: _iconPlaceholder(),
        );
      }
      return _iconPlaceholder();
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final url = imageUrl!.startsWith('http')
          ? imageUrl!
          : '$baseUrl$imageUrl';
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) => placeholder(),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF3F4F6),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF0F766E),
            ),
          );
        },
      );
    }
    return placeholder();
  }

  Widget _iconPlaceholder() => Container(
    color: const Color(0xFFECECEC),
    alignment: Alignment.center,
    child: Icon(
      Icons.content_cut,
      size: 44,
      color: Colors.black.withValues(alpha: 0.15),
    ),
  );
}

class _PriceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price; // e.g. "$24.00"
  final String? imageUrl;
  final bool dark;
  final VoidCallback onBook;
  final VoidCallback onDetail;

  const _PriceCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.dark,
    required this.onBook,
    required this.onDetail,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    const Color subtitleFg = Color(0xF2FFFFFF); // High-contrast readable white

    return GestureDetector(
      onTap: onDetail,
      child: Container(
        height: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image: always package_banner.png for all package cards
            Image.asset(
              'assets/images/packages/package_banner.png',
              fit: BoxFit.cover,
            ),
            // Scrim
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + price badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppFonts.poppins(
                            size: 19,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (price.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            price,
                            style: AppFonts.poppins(
                              size: 14,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: AppFonts.poppins(
                        size: 13.5,
                        weight: FontWeight.w400,
                        color: subtitleFg,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  // Book Now button
                  GestureDetector(
                    onTap: onBook,
                    child: Container(
                      width: double.infinity,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'Book Now',
                        style: AppFonts.poppins(
                          size: 15,
                          weight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

