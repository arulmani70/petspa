part of 'pet_bloc.dart';

enum PetStatus { initial, loading, loaded, success, failure }

class PetState extends Equatable {
  final PetStatus status;
  final String message;
  final List<Map<String, dynamic>> pets;
  final int? selectedPetId;

  const PetState({
    required this.status,
    required this.message,
    required this.pets,
    this.selectedPetId,
  });

  static const PetState initial = PetState(status: PetStatus.initial, message: '', pets: []);

  PetState copyWith({
    PetStatus Function()? status,
    String Function()? message,
    List<Map<String, dynamic>> Function()? pets,
    int? Function()? selectedPetId,
  }) {
    return PetState(
      status: status != null ? status() : this.status,
      message: message != null ? message() : this.message,
      pets: pets != null ? pets() : this.pets,
      selectedPetId: selectedPetId != null ? selectedPetId() : this.selectedPetId,
    );
  }

  @override
  List<Object?> get props => [status, message, pets, selectedPetId];
}
