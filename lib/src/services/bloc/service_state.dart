part of 'service_bloc.dart';

enum ServiceStatus { initial, loading, loaded, success, failure }

class ServiceState extends Equatable {
  final ServiceStatus status;
  final String message;

  // ── Typed structured result (used by BookingServicePageMobile) ────────────
  final BookingServicesResult? bookingServices;

  // ── Legacy flat lists (used by home_page, services_page, packages_page) ───
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> packages;

  // ── Detail states (for ServiceDetailPage & PackageDetailPage) ────────────
  final Map<String, dynamic>? selectedService;
  final Map<String, dynamic>? selectedPackage;
  final ServiceStatus detailStatus;
  final String detailMessage;

  const ServiceState({
    required this.status,
    required this.message,
    required this.services,
    required this.packages,
    this.bookingServices,
    this.selectedService,
    this.selectedPackage,
    this.detailStatus = ServiceStatus.initial,
    this.detailMessage = '',
  });

  static const ServiceState initial = ServiceState(
    status  : ServiceStatus.initial,
    message : '',
    services: [],
    packages: [],
    detailStatus: ServiceStatus.initial,
    detailMessage: '',
  );

  ServiceState copyWith({
    ServiceStatus Function()?                   status,
    String Function()?                          message,
    List<Map<String, dynamic>> Function()?      services,
    List<Map<String, dynamic>> Function()?      packages,
    BookingServicesResult? Function()?          bookingServices,
    Map<String, dynamic>? Function()?           selectedService,
    Map<String, dynamic>? Function()?           selectedPackage,
    ServiceStatus Function()?                   detailStatus,
    String Function()?                          detailMessage,
  }) {
    return ServiceState(
      status          : status          != null ? status()          : this.status,
      message         : message         != null ? message()         : this.message,
      services        : services        != null ? services()        : this.services,
      packages        : packages        != null ? packages()        : this.packages,
      bookingServices : bookingServices != null ? bookingServices() : this.bookingServices,
      selectedService : selectedService != null ? selectedService() : this.selectedService,
      selectedPackage : selectedPackage != null ? selectedPackage() : this.selectedPackage,
      detailStatus    : detailStatus    != null ? detailStatus()    : this.detailStatus,
      detailMessage   : detailMessage   != null ? detailMessage()   : this.detailMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        message,
        services,
        packages,
        bookingServices,
        selectedService,
        selectedPackage,
        detailStatus,
        detailMessage,
      ];
}
