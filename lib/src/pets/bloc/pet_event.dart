part of 'pet_bloc.dart';

sealed class PetEvent extends Equatable {
  const PetEvent();

  @override
  List<Object> get props => [];
}

class InitializePets extends PetEvent {
  const InitializePets();
}

class GetAllPets extends PetEvent {
  const GetAllPets();
}

class CreatePet extends PetEvent {
  final Map<String, dynamic> pet;

  const CreatePet({required this.pet});

  @override
  List<Object> get props => [pet];
}

class UpdatePet extends PetEvent {
  final int petId;
  final Map<String, dynamic> pet;

  const UpdatePet({required this.petId, required this.pet});

  @override
  List<Object> get props => [petId, pet];
}

class DeletePet extends PetEvent {
  final int petId;

  const DeletePet({required this.petId});

  @override
  List<Object> get props => [petId];
}

class SelectPet extends PetEvent {
  final int petId;

  const SelectPet(this.petId);

  @override
  List<Object> get props => [petId];
}
