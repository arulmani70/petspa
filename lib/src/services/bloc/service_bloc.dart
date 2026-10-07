import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

part 'service_event.dart';
part 'service_state.dart';

class ServiceBloc extends Bloc<ServiceEvent, ServiceState> {
  ServiceBloc({required ServiceRepository repository})
      : _repository = repository,
        super(ServiceState.initial) {
    on<InitializeServices>(_onInitializeServices);
    on<GetAllServices>(_onGetAllServices);
    on<GetAllPackages>(_onGetAllPackages);
    on<RefreshServices>(_onRefreshServices);
  }

  final ServiceRepository _repository;
  final _log = Logger();

  // ── InitializeServices ───────────────────────────────────────────────────
  Future<void> _onInitializeServices(
      InitializeServices event, Emitter<ServiceState> emit) async {
    _log.d('ServiceBloc::_onInitializeServices::Loading');
    try {
      emit(state.copyWith(status: () => ServiceStatus.loading));

      final result = await _repository.getBookingServices();

      _log.d('ServiceBloc::_onInitializeServices::Response'
          ' breeds=${result.breeds.length}'
          ' packages=${result.packages.length}'
          ' addOns=${result.addOns.length}'
          ' walkIn=${result.walkIn.length}');

      emit(state.copyWith(
        status          : () => ServiceStatus.loaded,
        message         : () => 'Services loaded',
        bookingServices : () => result,
        services        : () => result.allServicesAsMap,
        packages        : () => result.allPackagesAsMap,
      ));
    } catch (e) {
      _log.e('ServiceBloc::_onInitializeServices::Error: $e');
      emit(state.copyWith(
        status : () => ServiceStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  // ── GetAllServices (legacy — used by ServicesPage) ────────────────────────
  Future<void> _onGetAllServices(
      GetAllServices event, Emitter<ServiceState> emit) async {
    _log.d('ServiceBloc::_onGetAllServices::Loading');
    try {
      emit(state.copyWith(status: () => ServiceStatus.loading));
      final result = await _repository.getBookingServices();
      emit(state.copyWith(
        status          : () => ServiceStatus.loaded,
        message         : () => 'Services fetched',
        bookingServices : () => result,
        services        : () => result.allServicesAsMap,
        packages        : () => result.allPackagesAsMap,
      ));
    } catch (e) {
      _log.e('ServiceBloc::_onGetAllServices::Error: $e');
      emit(state.copyWith(
        status : () => ServiceStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  // ── GetAllPackages (legacy — used by PackagesPage) ────────────────────────
  Future<void> _onGetAllPackages(
      GetAllPackages event, Emitter<ServiceState> emit) async {
    _log.d('ServiceBloc::_onGetAllPackages::Loading');
    try {
      emit(state.copyWith(status: () => ServiceStatus.loading));
      final result = await _repository.getBookingServices();
      emit(state.copyWith(
        status          : () => ServiceStatus.loaded,
        message         : () => 'Packages fetched',
        bookingServices : () => result,
        services        : () => result.allServicesAsMap,
        packages        : () => result.allPackagesAsMap,
      ));
    } catch (e) {
      _log.e('ServiceBloc::_onGetAllPackages::Error: $e');
      emit(state.copyWith(
        status : () => ServiceStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  // ── RefreshServices ───────────────────────────────────────────────────────
  Future<void> _onRefreshServices(
      RefreshServices event, Emitter<ServiceState> emit) async {
    _log.d('ServiceBloc::_onRefreshServices::Refreshing');
    try {
      emit(state.copyWith(status: () => ServiceStatus.loading));
      final result = await _repository.getBookingServices();
      emit(state.copyWith(
        status          : () => ServiceStatus.success,
        message         : () => 'Refreshed',
        bookingServices : () => result,
        services        : () => result.allServicesAsMap,
        packages        : () => result.allPackagesAsMap,
      ));
    } catch (e) {
      _log.e('ServiceBloc::_onRefreshServices::Error: $e');
      emit(state.copyWith(
        status : () => ServiceStatus.failure,
        message: () => e.toString(),
      ));
    }
  }
}
