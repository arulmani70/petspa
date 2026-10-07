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

  const ServiceState({
    required this.status,
    required this.message,
    required this.services,
    required this.packages,
    this.bookingServices,
  });

  static const ServiceState initial = ServiceState(
    status  : ServiceStatus.initial,
    message : '',
    services: [],
    packages: [],
  );

  ServiceState copyWith({
    ServiceStatus Function()?                   status,
    String Function()?                          message,
    List<Map<String, dynamic>> Function()?      services,
    List<Map<String, dynamic>> Function()?      packages,
    BookingServicesResult? Function()?          bookingServices,
  }) {
    return ServiceState(
      status          : status          != null ? status()          : this.status,
      message         : message         != null ? message()         : this.message,
      services        : services        != null ? services()        : this.services,
      packages        : packages        != null ? packages()        : this.packages,
      bookingServices : bookingServices != null ? bookingServices() : this.bookingServices,
    );
  }

  @override
  List<Object?> get props => [status, message, services, packages, bookingServices];
}
