import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';

part 'pet_event.dart';
part 'pet_state.dart';

class PetBloc extends Bloc<PetEvent, PetState> {
  PetBloc({required PetRepository repository})
      : _repository = repository,
        super(PetState.initial) {
    on<InitializePets>(_onInitializePets);
    on<GetAllPets>(_onGetAllPets);
    on<CreatePet>(_onCreatePet);
    on<UpdatePet>(_onUpdatePet);
    on<DeletePet>(_onDeletePet);
    on<SelectPet>(_onSelectPet);
  }

  final PetRepository _repository;
  final _log = Logger();

  Future<void> _onInitializePets(InitializePets event, Emitter<PetState> emit) async {
    _log.d("PetBloc::_onInitializePets::Initializing pets");
    try {
      emit(state.copyWith(status: () => PetStatus.loading));
      final pets = await _repository.getAllPets();
      emit(state.copyWith(
        status: () => PetStatus.loaded,
        message: () => 'Pets loaded successfully',
        pets: () => pets,
      ));
    } catch (e) {
      _log.e("PetBloc::_onInitializePets::Error: $e");
      emit(state.copyWith(status: () => PetStatus.failure, message: () => e.toString()));
    }
  }

  Future<void> _onGetAllPets(GetAllPets event, Emitter<PetState> emit) async {
    _log.d("PetBloc::_onGetAllPets::Getting all pets");
    try {
      emit(state.copyWith(status: () => PetStatus.loading));
      final pets = await _repository.getAllPets();
      emit(state.copyWith(
        status: () => PetStatus.loaded,
        message: () => 'Pets fetched successfully',
        pets: () => pets,
      ));
    } catch (e) {
      _log.e("PetBloc::_onGetAllPets::Error: $e");
      emit(state.copyWith(status: () => PetStatus.failure, message: () => e.toString()));
    }
  }

  Future<void> _onCreatePet(CreatePet event, Emitter<PetState> emit) async {
    _log.d("PetBloc::_onCreatePet::Creating pet");
    try {
      emit(state.copyWith(status: () => PetStatus.loading));
      await _repository.createPet(event.pet);
      final pets = await _repository.getAllPets();
      emit(state.copyWith(
        status: () => PetStatus.success,
        message: () => 'Pet added successfully',
        pets: () => pets,
      ));
    } catch (e) {
      _log.e("PetBloc::_onCreatePet::Error: $e");
      emit(state.copyWith(status: () => PetStatus.failure, message: () => e.toString()));
    }
  }

  Future<void> _onUpdatePet(UpdatePet event, Emitter<PetState> emit) async {
    _log.d("PetBloc::_onUpdatePet::Updating pet: ${event.petId}");
    try {
      emit(state.copyWith(status: () => PetStatus.loading));
      await _repository.updatePet(event.petId, event.pet);
      final pets = await _repository.getAllPets();
      emit(state.copyWith(
        status: () => PetStatus.success,
        message: () => 'Pet updated successfully',
        pets: () => pets,
      ));
    } catch (e) {
      _log.e("PetBloc::_onUpdatePet::Error: $e");
      emit(state.copyWith(status: () => PetStatus.failure, message: () => e.toString()));
    }
  }

  Future<void> _onDeletePet(DeletePet event, Emitter<PetState> emit) async {
    _log.d("PetBloc::_onDeletePet::Deleting pet: ${event.petId}");
    try {
      emit(state.copyWith(status: () => PetStatus.loading));
      await _repository.deletePet(event.petId);
      final pets = await _repository.getAllPets();
      emit(state.copyWith(
        status: () => PetStatus.success,
        message: () => 'Pet removed',
        pets: () => pets,
      ));
    } catch (e) {
      _log.e("PetBloc::_onDeletePet::Error: $e");
      emit(state.copyWith(status: () => PetStatus.failure, message: () => e.toString()));
    }
  }

  void _onSelectPet(SelectPet event, Emitter<PetState> emit) {
    _log.d("PetBloc::_onSelectPet::Selecting pet: ${event.petId}");
    emit(state.copyWith(selectedPetId: () => event.petId));
  }
}
