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
