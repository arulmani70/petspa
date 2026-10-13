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
    on<GetServiceDetail>(_onGetServiceDetail);
    on<GetPackageDetail>(_onGetPackageDetail);
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

  // ── GetServiceDetail ───────────────────────────────────────────────────────
  Future<void> _onGetServiceDetail(
      GetServiceDetail event, Emitter<ServiceState> emit) async {
    _log.d('ServiceBloc::_onGetServiceDetail::id=${event.serviceId}');
    try {
      if (event.initialService != null && event.initialService!.isNotEmpty) {
        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.loaded,
          selectedService: () => event.initialService,
          detailMessage  : () => 'Service loaded',
        ));
      } else {
        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.loading,
          selectedService: () => null,
          detailMessage  : () => '',
        ));
      }

      final isAddOn = event.initialService?['isAddOn'] == true ||
          event.initialService?['addOnId'] != null ||
          event.serviceId?.toString().toLowerCase().contains('addon') == true ||
          event.serviceId?.toString().toUpperCase().startsWith('A0') == true;

      final isPackage = event.initialService?['isPackage'] == true ||
          event.initialService?['packageId'] != null ||
          event.serviceId?.toString().toLowerCase().contains('pkg') == true ||
          event.serviceId?.toString().toUpperCase().startsWith('P0') == true;

      final code = event.initialService?['code']?.toString() ??
          (event.serviceId is String ? event.serviceId as String : null);

      final name = event.initialService?['service_name']?.toString() ??
          event.initialService?['name']?.toString();

      final intId = event.serviceId is int
          ? event.serviceId as int
          : int.tryParse(event.serviceId?.toString() ?? '');

      Map<String, dynamic>? service;

      // If add-on hint or non-numeric code is present, use getServiceDetail first to prevent collision
      if (isAddOn || isPackage || (code != null && RegExp(r'^[A-Za-z]\d+$').hasMatch(code))) {
        service = await _repository.getServiceDetail(
          id: event.serviceId,
          code: code,
          name: name,
          isAddOn: isAddOn,
          isPackage: isPackage,
          initialService: event.initialService,
        );
      }

      // If plain integer or not found via code, call getServiceById (honors mock repositories)
      if (service == null && intId != null) {
        service = await _repository.getServiceById(intId);
      }

      // Fallback to getServiceDetail if still null
      if (service == null) {
        service = await _repository.getServiceDetail(
          id: event.serviceId,
          code: code,
          name: name,
          isAddOn: isAddOn,
          isPackage: isPackage,
          initialService: event.initialService,
        );
      }

      if (service == null) {
        if (event.initialService != null && event.initialService!.isNotEmpty) {
          emit(state.copyWith(
            detailStatus   : () => ServiceStatus.loaded,
            selectedService: () => event.initialService,
            detailMessage  : () => 'Service loaded',
          ));
        } else {
          emit(state.copyWith(
            detailStatus   : () => ServiceStatus.failure,
            selectedService: () => null,
            detailMessage  : () => 'Service not found',
          ));
        }
      } else {
        if (event.initialService != null && event.initialService!.isNotEmpty) {
          final initName = event.initialService!['service_name']?.toString() ??
              event.initialService!['name']?.toString();
          final svcName = service['service_name']?.toString() ??
              service['name']?.toString();
          if (initName != null && svcName != null && initName != svcName) {
            _log.w('ServiceBloc::_onGetServiceDetail: Service name mismatch ($svcName vs $initName), keeping initialService');
            service = event.initialService;
          }
        }

        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.loaded,
          selectedService: () => service,
          detailMessage  : () => 'Service loaded',
        ));
      }
    } catch (e) {
      _log.e('ServiceBloc::_onGetServiceDetail::Error: $e');
      if (event.initialService != null && event.initialService!.isNotEmpty) {
        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.loaded,
          selectedService: () => event.initialService,
          detailMessage  : () => 'Service loaded',
        ));
      } else {
        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.failure,
          selectedService: () => null,
          detailMessage  : () => e.toString(),
        ));
      }
    }
  }

  // ── GetPackageDetail ───────────────────────────────────────────────────────
  Future<void> _onGetPackageDetail(
      GetPackageDetail event, Emitter<ServiceState> emit) async {
    _log.d('ServiceBloc::_onGetPackageDetail::id=${event.packageId}');
    try {
      if (event.initialPackage != null && event.initialPackage!.isNotEmpty) {
        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.loaded,
          selectedPackage: () => event.initialPackage,
          detailMessage  : () => 'Package loaded',
        ));
      } else {
        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.loading,
          selectedPackage: () => null,
          detailMessage  : () => '',
        ));
      }

      final code = event.initialPackage?['code']?.toString() ??
          (event.packageId is String ? event.packageId as String : null);
      final name = event.initialPackage?['package_name']?.toString() ??
          event.initialPackage?['name']?.toString();

      final intId = event.packageId is int
          ? event.packageId as int
          : int.tryParse(event.packageId?.toString() ?? '');

      Map<String, dynamic>? package;

      // Plain integer ID without code uses getPackageById first (honors mock repositories)
      if (intId != null && (code == null || !RegExp(r'^[A-Za-z]\d+$').hasMatch(code))) {
        package = await _repository.getPackageById(intId);
      }

      if (package == null) {
        package = await _repository.getPackageDetail(
          id: event.packageId,
          code: code,
          name: name,
          initialPackage: event.initialPackage,
        );
      }

      if (package == null && intId != null) {
        package = await _repository.getPackageById(intId);
      }

      if (package == null) {
        if (event.initialPackage != null && event.initialPackage!.isNotEmpty) {
          emit(state.copyWith(
            detailStatus   : () => ServiceStatus.loaded,
            selectedPackage: () => event.initialPackage,
            detailMessage  : () => 'Package loaded',
          ));
        } else {
          emit(state.copyWith(
            detailStatus   : () => ServiceStatus.failure,
            selectedPackage: () => null,
            detailMessage  : () => 'Package not found',
          ));
        }
      } else {
        if (event.initialPackage != null && event.initialPackage!.isNotEmpty) {
          final initName = event.initialPackage!['package_name']?.toString() ??
              event.initialPackage!['name']?.toString();
          final pkgName = package['package_name']?.toString() ??
              package['name']?.toString();
          if (initName != null && pkgName != null && initName != pkgName) {
            package = event.initialPackage;
          }
        }

        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.loaded,
          selectedPackage: () => package,
          detailMessage  : () => 'Package loaded',
        ));
      }
    } catch (e) {
      _log.e('ServiceBloc::_onGetPackageDetail::Error: $e');
      if (event.initialPackage != null && event.initialPackage!.isNotEmpty) {
        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.loaded,
          selectedPackage: () => event.initialPackage,
          detailMessage  : () => 'Package loaded',
        ));
      } else {
        emit(state.copyWith(
          detailStatus   : () => ServiceStatus.failure,
          selectedPackage: () => null,
          detailMessage  : () => e.toString(),
        ));
      }
    }
  }
}
