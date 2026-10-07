import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/utils.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/mobile/widgets/pet_card.dart';

class MyPetsPageMobile extends StatelessWidget {
  const MyPetsPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Text(
          'My Pets',
          style: AppFonts.parkinsans(
            size: 20,
            weight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 22),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.home);
            }
          },
        ),
      ),
      body: BlocConsumer<PetBloc, PetState>(
        listener: (context, state) {
          if (state.status == PetStatus.success) {
            ToastUtil.showSuccessToast(context, state.message);
          } else if (state.status == PetStatus.failure) {
            ToastUtil.showErrorToast(context, state.message);
          }
        },
        builder: (context, state) {
          if (state.status == PetStatus.loading && state.pets.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 130),
              children: const [
                PetCardSkeleton(),
                SizedBox(height: 16),
                PetCardSkeleton(),
                SizedBox(height: 16),
                PetCardSkeleton(),
                SizedBox(height: 16),
                PetCardSkeleton(),
              ],
            );
          }

          if (state.pets.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(17, 16, 17, 130),
            itemCount: state.pets.length + 1,
            itemBuilder: (context, index) {
              if (index == state.pets.length) {
                return _buildAddPetBlock(context);
              }
              final pet = state.pets[index];
              final name =
                  pet[Constants.database.COLUMN_PET_NAME]?.toString() ?? '';
              final breed =
                  pet[Constants.database.COLUMN_BREED]?.toString() ?? '';
              final weight =
                  pet[Constants.database.COLUMN_WEIGHT]?.toString() ?? '0';
              String age = pet['age']?.toString() ?? '';
              if (age.isEmpty) {
                final ageStr =
                    pet[Constants.database.COLUMN_BIRTH_DATE]?.toString() ?? '';
                if (ageStr.isNotEmpty) {
                  final birthDate = DateTime.tryParse(ageStr);
                  if (birthDate != null) {
                    age = '${DateTime.now().year - birthDate.year} yrs';
                  }
                } else {
                  age = '0 yrs';
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PetCard(
                  name: name,
                  breed: breed,
                  weight: weight,
                  age: age,
                  photoUrl: pet[Constants.database.COLUMN_PHOTO_URL]?.toString(),
                  assetFallback: index.isEven
                      ? 'assets/images/common/pet_1.png'
                      : 'assets/images/common/pet_2.png',
                  showDelete: true,
                  onTap: () => context.pushNamed(
                    RouteNames.createPet,
                    extra: {'pet': pet},
                  ),
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext ctx) {
                        return AlertDialog(
                          title: const Text('Delete Pet'),
                          content: const Text(
                            'Are you sure you want to delete this pet?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                final id =
                                    pet[Constants.database.COLUMN_ID] as int;
                                context.read<PetBloc>().add(
                                  DeletePet(petId: id),
                                );
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddPetBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.pushNamed(RouteNames.createPet),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: const Color(0xFF111827), width: 1.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 18, color: Color(0xFF111827)),
                  const SizedBox(width: 6),
                  Text(
                    'Add Pet',
                    style: AppFonts.parkinsans(
                      size: 16.5,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add More pets if you have',
            style: AppFonts.poppins(
              size: 13.5,
              weight: FontWeight.w400,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/pets/empty_pet_icon.png',
          height: 88,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.pets, size: 88, color: Colors.black),
        ),
        const SizedBox(height: 29),
        Text(
          'No pets added to select',
          style: AppFonts.poppins(
            size: 20,
            weight: FontWeight.w600,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 43),
          child: Text(
            'add your dog and complete details to\nsave as a pet',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 16,
              weight: FontWeight.w400,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 29),
        GestureDetector(
          onTap: () => context.pushNamed(RouteNames.createPet),
          child: Container(
            width: 202,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: Text(
              '+ Add Pet',
              style: AppFonts.parkinsans(
                size: 16,
                weight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
