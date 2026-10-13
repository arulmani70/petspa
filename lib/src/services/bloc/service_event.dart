part of 'service_bloc.dart';

sealed class ServiceEvent extends Equatable {
  const ServiceEvent();

  @override
  List<Object> get props => [];
}

class InitializeServices extends ServiceEvent {
  const InitializeServices();
}

class GetAllServices extends ServiceEvent {
  const GetAllServices();
}

class GetAllPackages extends ServiceEvent {
  const GetAllPackages();
}

class RefreshServices extends ServiceEvent {
  const RefreshServices();
}

class GetServiceDetail extends ServiceEvent {
  final dynamic serviceId;
  final Map<String, dynamic>? initialService;
  const GetServiceDetail(this.serviceId, {this.initialService});

  @override
  List<Object> get props => [serviceId, initialService ?? {}];
}

class GetPackageDetail extends ServiceEvent {
  final dynamic packageId;
  final Map<String, dynamic>? initialPackage;
  const GetPackageDetail(this.packageId, {this.initialPackage});

  @override
  List<Object> get props => [packageId, initialPackage ?? {}];
}
