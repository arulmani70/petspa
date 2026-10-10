import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_progress.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/utils.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shimmer_loading.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/mobile/widgets/pet_card.dart';

class PetSelectPageMobile extends StatefulWidget {
  final Map<String, dynamic>? initialBookingData;
  const PetSelectPageMobile({super.key, this.initialBookingData});

  @override
  State<PetSelectPageMobile> createState() => _PetSelectPageMobileState();
}

class _PetSelectPageMobileState extends State<PetSelectPageMobile> {
  int? _selectedPetId;

  @override
  void initState() {
    super.initState();
    // Prioritize the PetBloc selectedPetId as requested
    final selectedPetId = context.read<PetBloc>().state.selectedPetId;
    if (selectedPetId != null) {
      _selectedPetId = selectedPetId;
    } else if (ServicesLocator.bookingDraft.pet != null) {
      _selectedPetId = ServicesLocator.bookingDraft.pet?[Constants.database.COLUMN_ID] as int?;
    }
  }

  void _onSelectAndContinue(Map<String, dynamic> pet) {
    if (_selectedPetId == null) return;
    
    // 1. Update the global selected pet in PetBloc
    context.read<PetBloc>().add(SelectPet(_selectedPetId!));
    
    // 2. Set the pet in the BookingDraft
    ServicesLocator.bookingDraft.setPet(pet);
    
    // 3. Navigate
    context.pushNamed(RouteNames.bookingService);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.initialBookingData ?? {};

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed(RouteNames.home);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          title: Text(
            'Select Your Pet',
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
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<PetBloc, PetState>(
            builder: (context, state) {
              if (state.status == PetStatus.loading && state.pets.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  children: const [
                    SizedBox(height: 16),
                    PetCardSkeleton(), SizedBox(height: 16),
                    PetCardSkeleton(), SizedBox(height: 16),
                    PetCardSkeleton(),
                  ],
                );
              }

              if (state.pets.isEmpty) {
                return _buildEmptyState(context);
              }

              return _buildPetList(context, state, draft);
            },
          ),
        ),
      ),
    );
  }

  // SCREEN #10 - no pets added yet
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

  // SCREEN #11 - pet list with step progress and Select & Continue bar
  Widget _buildPetList(BuildContext context, PetState state, dynamic draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 14, 17, 25),
          child: BookingProgress(
            step: 1,
            label: 'Step 1 of 4 – Select or add Pet',
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
            itemCount: state.pets.length + 1,
            itemBuilder: (context, index) {
              if (index == state.pets.length) {
                return _buildAddPetBlock(context);
              }
              final pet = state.pets[index];
              final id = pet[Constants.database.COLUMN_ID] as int;
              final name =
                  pet[Constants.database.COLUMN_PET_NAME]?.toString() ?? '';
              final breed =
                  pet[Constants.database.COLUMN_BREED]?.toString() ?? '';
              final weight =
                  pet[Constants.database.COLUMN_WEIGHT]?.toString() ?? '0';
              final age = PetAgeFormatter.formatPetCardAge(pet);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PetCard(
                      name: name,
                      breed: breed,
                      weight: weight,
                      age: age,
                      photoUrl: pet[Constants.database.COLUMN_PHOTO_URL]?.toString(),
                      assetFallback: index.isEven
                          ? 'assets/images/common/pet_1.png'
                          : 'assets/images/common/pet_2.png',
                      selected: _selectedPetId == id,
                      onTap: () {
                        context.read<PetBloc>().add(SelectPet(id));
                        setState(() {
                          _selectedPetId = id;
                        });
                      },
                    ),
                    if (_selectedPetId == id)
                      Positioned(
                        right: 18,
                        top: -9,
                        child: Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Selected',
                            style: AppFonts.poppins(
                              size: 11,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildBottomBar(state),
      ],
    );
  }

  Widget _buildBottomBar(PetState state) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        17,
        14,
        17,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 10
            : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select and confirm your pet for booking',
            style: AppFonts.poppins(
              size: 14,
              weight: FontWeight.w400,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              if (_selectedPetId != null) {
                final pet = state.pets.firstWhere(
                  (p) => p[Constants.database.COLUMN_ID] == _selectedPetId,
                  orElse: () => state.pets.first,
                );
                _onSelectAndContinue(pet);
              }
            },
            child: Container(
              height: 54,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _selectedPetId == null
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
                borderRadius: BorderRadius.circular(60),
                boxShadow: _selectedPetId != null
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                'Select & Continue',
                style: AppFonts.parkinsans(
                  size: 17,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPetBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: GestureDetector(
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
    );
  }
}
