part of 'groomer_home_bloc.dart';

enum GroomerHomeStatus { initial, loading, loaded, success, failure }

class GroomerHomeState extends Equatable {
  final GroomerHomeStatus status;
  final GroomerUser? groomer;
  final DateTime selectedDate;
  final int currentTabIndex;
  final List<GroomerBooking> upcomingBookings;
  final List<GroomerBooking> pendingBookings;
  final List<GroomerBooking> pastBookings;
  final List<GroomerBooking> cancelledBookings;
  final List<GroomerBooking> cancellationRequests;
  final List<StoreServiceHour> serviceHours;
  final List<GroomerWorkingHour> groomerHours;
  final List<StoreHoliday> holidays;
  final List<Map<String, dynamic>> notifications;
  final bool isSocketConnected;
  final String? errorMessage;
  final String? actionMessage;

  // Main-Line Dynamic Customer & Pet State (No hardcoding/dummy data)
  final List<CustomerSummary> searchedCustomers;
  final bool isSearchingCustomers;
  final List<CustomerPetSummary> customerPets;
  final bool isLoadingCustomerPets;
  final String? customerError;
  final String? petError;

  // Main-Line Dynamic Salon Groomers (Strictly from GET /api/groomers)
  final List<SalonGroomer> salonGroomers;
  final bool isLoadingSalonGroomers;
  final String? salonGroomersError;

  // Main-Line Dynamic Services & Packages (Strictly from GET /api/service-packages)
  final List<ServiceItem> bookingServices;
  final List<ServiceItem> bookingPackages;
  final List<ServiceItem> bookingAddOns;
  final bool isLoadingBookingServices;
  final String? bookingServicesError;

  // Main-Line Dynamic Availability (Strictly from POST /api/availability)
  final List<Map<String, dynamic>> availableTimeSlots;
  final List<Map<String, dynamic>> bookedTimeSlots;
  final int? slotDurationMinutes;
  final double? slotTotalPrice;
  final bool isCheckingAvailability;
  final String? availabilityMessage;
  final bool isSlotAvailable;

  // Main-Line Booking Creation State (Strictly via POST /api/groomer-auth/bookings/create-for-user)
  final bool isCreatingBookingForUser;
  final bool bookingForUserSuccess;
  final String? bookingForUserError;
  final int? lastCreatedBookingId;

  const GroomerHomeState({
    required this.status,
    this.groomer,
    required this.selectedDate,
    this.currentTabIndex = 0,
    this.upcomingBookings = const [],
    this.pendingBookings = const [],
    this.pastBookings = const [],
    this.cancelledBookings = const [],
    this.cancellationRequests = const [],
    this.serviceHours = const [],
    this.groomerHours = const [],
    this.holidays = const [],
    this.notifications = const [],
    this.isSocketConnected = false,
    this.errorMessage,
    this.actionMessage,
    this.searchedCustomers = const [],
    this.isSearchingCustomers = false,
    this.customerPets = const [],
    this.isLoadingCustomerPets = false,
    this.customerError,
    this.petError,
    this.salonGroomers = const [],
    this.isLoadingSalonGroomers = false,
    this.salonGroomersError,
    this.bookingServices = const [],
    this.bookingPackages = const [],
    this.bookingAddOns = const [],
    this.isLoadingBookingServices = false,
    this.bookingServicesError,
    this.availableTimeSlots = const [],
    this.bookedTimeSlots = const [],
    this.slotDurationMinutes,
    this.slotTotalPrice,
    this.isCheckingAvailability = false,
    this.availabilityMessage,
    this.isSlotAvailable = false,
    this.isCreatingBookingForUser = false,
    this.bookingForUserSuccess = false,
    this.bookingForUserError,
    this.lastCreatedBookingId,
  });

  static final initial = GroomerHomeState(
    status: GroomerHomeStatus.initial,
    selectedDate: DateTime.now(),
    currentTabIndex: 0,
    isSocketConnected: false,
    searchedCustomers: const [],
    isSearchingCustomers: false,
    customerPets: const [],
    isLoadingCustomerPets: false,
    salonGroomers: const [],
    isLoadingSalonGroomers: false,
    bookingServices: const [],
    bookingPackages: const [],
    bookingAddOns: const [],
    isLoadingBookingServices: false,
    availableTimeSlots: const [],
    bookedTimeSlots: const [],
    isCheckingAvailability: false,
    isSlotAvailable: false,
    isCreatingBookingForUser: false,
    bookingForUserSuccess: false,
  );

  /// Number of unread notifications and pending action requests
  int get unreadNotificationCount {
    final unreadList = notifications
        .where((n) => n['isRead'] != true && n['is_read'] != true)
        .length;
    return unreadList + pendingBookings.length + cancellationRequests.length;
  }

  GroomerHomeState copyWith({
    GroomerHomeStatus Function()? status,
    GroomerUser? Function()? groomer,
    DateTime Function()? selectedDate,
    int Function()? currentTabIndex,
    List<GroomerBooking> Function()? upcomingBookings,
    List<GroomerBooking> Function()? pendingBookings,
    List<GroomerBooking> Function()? pastBookings,
    List<GroomerBooking> Function()? cancelledBookings,
    List<GroomerBooking> Function()? cancellationRequests,
    List<StoreServiceHour> Function()? serviceHours,
    List<GroomerWorkingHour> Function()? groomerHours,
    List<StoreHoliday> Function()? holidays,
    List<Map<String, dynamic>> Function()? notifications,
    bool Function()? isSocketConnected,
    String? Function()? errorMessage,
    String? Function()? actionMessage,
    List<CustomerSummary> Function()? searchedCustomers,
    bool Function()? isSearchingCustomers,
    List<CustomerPetSummary> Function()? customerPets,
    bool Function()? isLoadingCustomerPets,
    String? Function()? customerError,
    String? Function()? petError,
    List<SalonGroomer> Function()? salonGroomers,
    bool Function()? isLoadingSalonGroomers,
    String? Function()? salonGroomersError,
    List<ServiceItem> Function()? bookingServices,
    List<ServiceItem> Function()? bookingPackages,
    List<ServiceItem> Function()? bookingAddOns,
    bool Function()? isLoadingBookingServices,
    String? Function()? bookingServicesError,
    List<Map<String, dynamic>> Function()? availableTimeSlots,
    List<Map<String, dynamic>> Function()? bookedTimeSlots,
    int? Function()? slotDurationMinutes,
    double? Function()? slotTotalPrice,
    bool Function()? isCheckingAvailability,
    String? Function()? availabilityMessage,
    bool Function()? isSlotAvailable,
    bool Function()? isCreatingBookingForUser,
    bool Function()? bookingForUserSuccess,
    String? Function()? bookingForUserError,
    int? Function()? lastCreatedBookingId,
  }) {
    return GroomerHomeState(
      status: status != null ? status() : this.status,
      groomer: groomer != null ? groomer() : this.groomer,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      currentTabIndex: currentTabIndex != null ? currentTabIndex() : this.currentTabIndex,
      upcomingBookings: upcomingBookings != null ? upcomingBookings() : this.upcomingBookings,
      pendingBookings: pendingBookings != null ? pendingBookings() : this.pendingBookings,
      pastBookings: pastBookings != null ? pastBookings() : this.pastBookings,
      cancelledBookings: cancelledBookings != null ? cancelledBookings() : this.cancelledBookings,
      cancellationRequests: cancellationRequests != null ? cancellationRequests() : this.cancellationRequests,
      serviceHours: serviceHours != null ? serviceHours() : this.serviceHours,
      groomerHours: groomerHours != null ? groomerHours() : this.groomerHours,
      holidays: holidays != null ? holidays() : this.holidays,
      notifications: notifications != null ? notifications() : this.notifications,
      isSocketConnected: isSocketConnected != null ? isSocketConnected() : this.isSocketConnected,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      actionMessage: actionMessage != null ? actionMessage() : this.actionMessage,
      searchedCustomers: searchedCustomers != null ? searchedCustomers() : this.searchedCustomers,
      isSearchingCustomers: isSearchingCustomers != null ? isSearchingCustomers() : this.isSearchingCustomers,
      customerPets: customerPets != null ? customerPets() : this.customerPets,
      isLoadingCustomerPets: isLoadingCustomerPets != null ? isLoadingCustomerPets() : this.isLoadingCustomerPets,
      customerError: customerError != null ? customerError() : this.customerError,
      petError: petError != null ? petError() : this.petError,
      salonGroomers: salonGroomers != null ? salonGroomers() : this.salonGroomers,
      isLoadingSalonGroomers: isLoadingSalonGroomers != null ? isLoadingSalonGroomers() : this.isLoadingSalonGroomers,
      salonGroomersError: salonGroomersError != null ? salonGroomersError() : this.salonGroomersError,
      bookingServices: bookingServices != null ? bookingServices() : this.bookingServices,
      bookingPackages: bookingPackages != null ? bookingPackages() : this.bookingPackages,
      bookingAddOns: bookingAddOns != null ? bookingAddOns() : this.bookingAddOns,
      isLoadingBookingServices: isLoadingBookingServices != null ? isLoadingBookingServices() : this.isLoadingBookingServices,
      bookingServicesError: bookingServicesError != null ? bookingServicesError() : this.bookingServicesError,
      availableTimeSlots: availableTimeSlots != null ? availableTimeSlots() : this.availableTimeSlots,
      bookedTimeSlots: bookedTimeSlots != null ? bookedTimeSlots() : this.bookedTimeSlots,
      slotDurationMinutes: slotDurationMinutes != null ? slotDurationMinutes() : this.slotDurationMinutes,
      slotTotalPrice: slotTotalPrice != null ? slotTotalPrice() : this.slotTotalPrice,
      isCheckingAvailability: isCheckingAvailability != null ? isCheckingAvailability() : this.isCheckingAvailability,
      availabilityMessage: availabilityMessage != null ? availabilityMessage() : this.availabilityMessage,
      isSlotAvailable: isSlotAvailable != null ? isSlotAvailable() : this.isSlotAvailable,
      isCreatingBookingForUser: isCreatingBookingForUser != null ? isCreatingBookingForUser() : this.isCreatingBookingForUser,
      bookingForUserSuccess: bookingForUserSuccess != null ? bookingForUserSuccess() : this.bookingForUserSuccess,
      bookingForUserError: bookingForUserError != null ? bookingForUserError() : this.bookingForUserError,
      lastCreatedBookingId: lastCreatedBookingId != null ? lastCreatedBookingId() : this.lastCreatedBookingId,
    );
  }

  @override
  List<Object?> get props => [
        status,
        groomer,
        selectedDate,
        currentTabIndex,
        upcomingBookings,
        pendingBookings,
        pastBookings,
        cancelledBookings,
        cancellationRequests,
        serviceHours,
        groomerHours,
        holidays,
        notifications,
        isSocketConnected,
        errorMessage,
        actionMessage,
        searchedCustomers,
        isSearchingCustomers,
        customerPets,
        isLoadingCustomerPets,
        customerError,
        petError,
        salonGroomers,
        isLoadingSalonGroomers,
        salonGroomersError,
        bookingServices,
        bookingPackages,
        bookingAddOns,
        isLoadingBookingServices,
        bookingServicesError,
        availableTimeSlots,
        bookedTimeSlots,
        slotDurationMinutes,
        slotTotalPrice,
        isCheckingAvailability,
        availabilityMessage,
        isSlotAvailable,
        isCreatingBookingForUser,
        bookingForUserSuccess,
        bookingForUserError,
        lastCreatedBookingId,
      ];
}
