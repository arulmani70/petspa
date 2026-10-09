import 'package:shear_heaven_pet_spa/src/common/widgets/shared_calendar.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';

class CreatePetPageMobile extends StatefulWidget {
  const CreatePetPageMobile({super.key});

  @override
  State<CreatePetPageMobile> createState() => _CreatePetPageMobileState();
}

class _CreatePetPageMobileState extends State<CreatePetPageMobile> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _weight;
  List<String> _weightOptions = [];
  String? _selectedAge;
  final List<String> _ageOptions = [
    '3 Months', '6 Months', '9 Months',
    ...List.generate(20, (index) {
      final y = index + 1;
      return '$y Year${y == 1 ? '' : 's'}';
    })
  ];
  final _notesController = TextEditingController();
  final _behaviorNotesController = TextEditingController();

  Map<String, dynamic>? _editingPet;
  bool _isEdit = false;
  String? _breed;
  DateTime? _birthDate;
  DateTime? _lastVaccinatedDate;
  String? _photoPath;
  String _gender = 'Male';
  String _vaccinated = 'Yes';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadWeights();
  }

  Future<void> _loadWeights() async {
    final weights = await ServicesLocator.storeRepository.getPetWeights();
    if (mounted) {
      setState(() {
        _weightOptions = weights.map((w) => w['label']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final extra = GoRouterState.of(context).extra;
    if (extra is Map) {
      if (extra['pet'] != null && extra['pet'] is Map) {
        _editingPet = Map<String, dynamic>.from(extra['pet'] as Map);
        _isEdit = true;
        _populateForm(_editingPet!);
      } else if (extra.containsKey(Constants.database.COLUMN_PET_NAME) ||
          extra.containsKey('petName') ||
          extra.containsKey(Constants.database.COLUMN_ID) ||
          extra.containsKey('id')) {
        _editingPet = Map<String, dynamic>.from(extra);
        _isEdit = true;
        _populateForm(_editingPet!);
      }
    }
  }

  void _populateForm(Map<String, dynamic> pet) {
    _nameController.text =
        pet[Constants.database.COLUMN_PET_NAME]?.toString() ??
        pet['petName']?.toString() ??
        pet['name']?.toString() ??
        '';
    _weight = pet[Constants.database.COLUMN_WEIGHT]?.toString() ??
        pet['weight']?.toString();
    if (_weight != null && _weight!.isEmpty) _weight = null;
    _notesController.text =
        pet[Constants.database.COLUMN_NOTES]?.toString() ??
        pet['notesAllergies']?.toString() ??
        pet['notes']?.toString() ??
        '';
    _breed = pet[Constants.database.COLUMN_BREED]?.toString() ??
        pet['breed']?.toString();
    
    final birth = DateTime.tryParse(
      pet[Constants.database.COLUMN_BIRTH_DATE]?.toString() ??
      pet['dateOfBirth']?.toString() ??
      '',
    );
    if (birth != null) {
      _birthDate = birth;
    }

    final rawPhoto = pet[Constants.database.COLUMN_PHOTO_URL]?.toString() ??
        pet['profilePictureUrl']?.toString() ??
        pet['profilePicture']?.toString() ??
        pet['photo_url']?.toString() ??
        pet['photoUrl']?.toString() ??
        pet['image']?.toString();
    _photoPath = (rawPhoto != null && rawPhoto.trim().isNotEmpty && rawPhoto.trim() != 'null')
        ? rawPhoto.trim()
        : null;

    final ageStr = pet['age']?.toString() ?? '';
    if (ageStr.isNotEmpty) {
      if (_ageOptions.contains(ageStr)) {
        _selectedAge = ageStr;
      } else {
        final match = RegExp(r'(\d+)\s*(Month|Year)', caseSensitive: false).firstMatch(ageStr);
        if (match != null) {
          int num = int.tryParse(match.group(1)!) ?? 0;
          String unit = match.group(2)!.toLowerCase();
          if (unit == 'month') {
            if (num >= 9) { _selectedAge = '9 Months'; }
            else if (num >= 6) { _selectedAge = '6 Months'; }
            else { _selectedAge = '3 Months'; }
          } else {
            if (num > 20) num = 20;
            _selectedAge = '$num Year${num == 1 ? '' : 's'}';
          }
        } else {
          final numMatch = RegExp(r'(\d+)').firstMatch(ageStr);
          if (numMatch != null) {
            int num = int.tryParse(numMatch.group(1)!) ?? 0;
            if (num > 20) num = 20;
            _selectedAge = '$num Year${num == 1 ? '' : 's'}';
          }
        }
      }
    }
    
    final gen = pet['gender']?.toString();
    if (gen != null && gen.isNotEmpty) {
      _gender = gen[0].toUpperCase() + gen.substring(1).toLowerCase();
    }
    
    final vacc = pet['allVaccinatedCurrent'];
    if (vacc != null) {
      _vaccinated = (vacc == true || vacc.toString() == 'true') ? 'Yes' : 'No';
    }
    
    final lastVacc = DateTime.tryParse(
      pet['lastVaccinatedDate']?.toString() ??
      pet['lastVaccinated']?.toString() ??
      '',
    );
    if (lastVacc != null) {
      _lastVaccinatedDate = lastVacc;
    }
    
    _behaviorNotesController.text = pet['behaviorNotes']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _behaviorNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (file != null && mounted) {
        setState(() => _photoPath = file.path);
      }
    } catch (error) {
      // ignore
    }
  }

  void _showCalendarModal(bool isBirthDate) {
    if (isBirthDate && _selectedAge == null) return;
    
    final now = DateTime.now();
    DateTime? minDate;
    DateTime? maxDate;
    
    if (isBirthDate) {
      // Calculate valid DOB range based on selected age
      int minMonthsAgo = 0;
      int maxMonthsAgo = 0;
      if (_selectedAge!.contains('Month')) {
        int m = int.tryParse(_selectedAge!.split(' ')[0]) ?? 3;
        minMonthsAgo = m;
        maxMonthsAgo = m + 3;
      } else {
        int y = int.tryParse(_selectedAge!.split(' ')[0]) ?? 1;
        minMonthsAgo = y * 12;
        maxMonthsAgo = (y + 1) * 12;
      }
      
      // Max date represents the youngest they can be in this age bucket
      maxDate = DateTime(now.year, now.month - minMonthsAgo, now.day);
      // Min date represents the oldest they can be in this age bucket
      minDate = DateTime(now.year, now.month - maxMonthsAgo, now.day).add(const Duration(days: 1));
      
      if (maxDate.isAfter(now)) {
        maxDate = now;
      }
      if (minDate.isAfter(now)) {
        minDate = now;
      }
    } else {
      maxDate = now;
      if (_birthDate != null) {
        minDate = _birthDate;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  isBirthDate ? "Select Date of Birth" : "Select Vaccination Date",
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SharedCalendar(
                initialDate: isBirthDate
                    ? (_birthDate ?? maxDate)
                    : (_lastVaccinatedDate ?? maxDate),
                minDate: minDate,
                maxDate: maxDate,
                onDateSelected: (date) {
                  setState(() {
                    if (isBirthDate) {
                      _birthDate = date;
                      // validate vaccinated date
                      if (_lastVaccinatedDate != null && _lastVaccinatedDate!.isBefore(date)) {
                        _lastVaccinatedDate = null;
                      }
                    } else {
                      _lastVaccinatedDate = date;
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _savePet(PetBloc bloc) {
    if (!_formKey.currentState!.validate()) return;

    if (_photoPath == null || _photoPath!.isEmpty) {
      ToastUtil.showErrorToast(
        context,
        'Please upload a pet profile picture',
      );
      return;
    }

    final userMap = ServicesLocator.sessionService.getSessionUser();
    final parsedId = userMap?[Constants.database.COLUMN_ID];

    int userId = 1;
    if (parsedId is int) {
      userId = parsedId;
    } else {
      userId =
          int.tryParse(
            parsedId?.toString() ??
                ServicesLocator.sessionService.currentUserId ??
                '',
          ) ??
          1;
    }

    final petData = <String, dynamic>{
      Constants.database.COLUMN_PET_NAME: _nameController.text.trim(),
      Constants.database.COLUMN_BREED: _breed,
      Constants.database.COLUMN_WEIGHT: _weight,
      Constants.database.COLUMN_NOTES: _notesController.text
          .trim(), // Maps to notesAllergies
      Constants.database.COLUMN_BIRTH_DATE: _birthDate
          ?.toIso8601String()
          .split('T')
          .first,
      Constants.database.COLUMN_PHOTO_URL: _photoPath, // Maps to profilePicture
      'profilePicture': _photoPath,
      'profilePictureUrl': _photoPath,
      'photo_url': _photoPath,
      Constants.database.COLUMN_USER_ID: userId,
      'age': _selectedAge ?? '',
      'gender': _gender.toLowerCase(),
      'allVaccinatedCurrent': _vaccinated == 'Yes' ? 'true' : 'false',
      'lastVaccinatedDate': _lastVaccinatedDate
          ?.toIso8601String()
          .split('T')
          .first,
      'behaviorNotes': _behaviorNotesController.text.trim(),
    };

    if (_isEdit && _editingPet != null) {
      final petIdRaw = _editingPet![Constants.database.COLUMN_ID] ??
          _editingPet!['id'] ??
          _editingPet!['_id'];
      final petId = petIdRaw is int
          ? petIdRaw
          : (int.tryParse(petIdRaw?.toString() ?? '') ?? 1);
      bloc.add(UpdatePet(petId: petId, pet: petData));
    } else {
      bloc.add(CreatePet(pet: petData));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PetBloc, PetState>(
        listener: (context, state) {
          if (state.status == PetStatus.success) {
            context.goNamed(RouteNames.petSelect);
          }
        },
        builder: (context, state) {
          final bloc = context.read<PetBloc>();
          return PopScope(
            canPop: context.canPop(),
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              context.goNamed(RouteNames.myPets);
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFFAFAFA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 21,
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed(RouteNames.myPets);
                  }
                },
              ),
              title: Text(
                _isEdit ? "Edit Pet" : "Add a Pet",
                style: const TextStyle(
                  fontFamily: 'Parkinsans',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildPhotoPicker(),
                            const SizedBox(height: 24),
                            _buildSectionTitle("Pet Name"),
                            _buildTextField(
                              controller: _nameController,
                              hint: "Eg: Bruno",
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            _buildSectionTitle("Breed"),
                            _buildDropdown<String>(
                              hint: "Select Breed",
                              value: _breed,
                              items: Constants.petBreeds,
                              onChanged: (value) =>
                                  setState(() => _breed = value),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle("Weight"),
                                      _buildDropdown<String>(
                                        hint: "Select Weight",
                                        value: _weight,
                                        items: _weightOptions.isNotEmpty ? _weightOptions : ['Small', 'Medium', 'Large'],
                                        onChanged: (value) => setState(() => _weight = value),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle("Age"),
                                      _buildDropdown<String>(
                                        hint: "Select Age",
                                        value: _selectedAge,
                                        items: _ageOptions,
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedAge = val;
                                            _birthDate = null;
                                            _lastVaccinatedDate = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5F0FF),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/pets/fi_1828919_1_1908.svg',
                                    height: 20,
                                    width: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Flexible(
                                    child: Text(
                                      "Size auto-detected: Medium",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedAge != null) ...[
                              _buildSectionTitle("Date of Birth"),
                              _buildDateField(isBirthDate: true),
                            ],
                            _buildSectionTitle("Gender"),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _gender = 'Male'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _gender == 'Male'
                                            ? Colors.black
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                          color: const Color(0xFFE5E5E5),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Male",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: _gender == 'Male'
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _gender = 'Female'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _gender == 'Female'
                                            ? Colors.black
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                          color: const Color(0xFFE5E5E5),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Female",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: _gender == 'Female'
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _buildSectionTitle("Notes & Allergies"),
                            _buildTextField(
                              controller: _notesController,
                              hint: "eg: Sensitive skin, afraid of dryers...",
                              maxLines: 2,
                            ),
                            _buildSectionTitle("All Vaccinated Current"),
                            _buildVaccinatedRow(),
                            _buildSectionTitle("Last Vaccinated Date"),
                            _buildDateField(isBirthDate: false),
                            _buildSectionTitle("Behavior Notes"),
                            _buildTextField(
                              controller: _behaviorNotesController,
                              hint:
                                  "eg: He is a little bit soft and angry whe....",
                              maxLines: 2,
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: () => _savePet(bloc),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                alignment: Alignment.center,
                                child: state.status == PetStatus.loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        "Save & Continue",
                                        style: TextStyle(
                                          fontFamily: 'Parkinsans',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Please review the details before saving or updating.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }

  // Group 76117 @ (17,961) - "Vaccinated" label + Yes/No checkboxes
  Widget _buildVaccinatedRow() {
    return Row(
      children: [
        _buildVaccineCheckbox(
          isChecked: _vaccinated == 'Yes',
          onTap: () => setState(() => _vaccinated = 'Yes'),
        ),
        const SizedBox(width: 12),
        const Text(
          "Yes",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 34),
        _buildVaccineCheckbox(
          isChecked: _vaccinated == 'No',
          onTap: () => setState(() => _vaccinated = 'No'),
          radius: 7,
        ),
        const SizedBox(width: 12),
        const Text(
          "No",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildVaccineCheckbox({
    required bool isChecked,
    required VoidCallback onTap,
    double radius = 5,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: isChecked
            ? Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(3),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: Stack(
            children: [
              Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  shape: BoxShape.circle,
                ),
                child: _buildPhotoWidget(),
              ),
              Positioned(
                right: 3,
                bottom: 6,
                child: SvgPicture.asset(
                  'assets/images/pets/fi_1828919_1_1908.svg',
                  width: 33,
                  height: 33,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "Pet Profile Picture",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoWidget() {
    if (_photoPath == null || _photoPath!.trim().isEmpty) {
      return Center(
        child: SvgPicture.asset(
          'assets/images/pets/fi_2956744_1_1903.svg',
          width: 44,
          height: 44,
        ),
      );
    }
    final path = _photoPath!.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) =>
              const Icon(Icons.pets, color: Colors.grey, size: 40),
        ),
      );
    }
    if (path.startsWith('assets/')) {
      return ClipOval(
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) =>
              const Icon(Icons.pets, color: Colors.grey, size: 40),
        ),
      );
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                const Icon(Icons.pets, color: Colors.grey, size: 40),
          ),
        );
      }
    } catch (_) {}
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return ClipOval(
      child: Image.network(
        '${Constants.app.BASE_URL}/$clean',
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) =>
            const Icon(Icons.pets, color: Colors.grey, size: 40),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        color: Colors.black,
        height: 26.95 / 16,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          color: Color(0xFF9F9F9F),
          height: 26.95 / 16,
          letterSpacing: 0,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(maxLines > 1 ? 24 : 50),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(maxLines > 1 ? 24 : 50),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(maxLines > 1 ? 24 : 50),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(maxLines > 1 ? 24 : 50),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    DropdownMenuItem<T> Function(T)? itemBuilder,
  }) {
    final safeValue = items.contains(value) ? value : null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: safeValue,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(20),
          dropdownColor: Colors.white,
          menuMaxHeight: 300,
          alignment: AlignmentDirectional.centerStart,
          hint: Text(
            hint,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Color(0xFF9F9F9F),
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          items: items
              .map(
                (item) => itemBuilder != null
                    ? itemBuilder(item)
                    : DropdownMenuItem(value: item, child: Text(item.toString())),
              )
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.black,
            height: 1.0,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({required bool isBirthDate}) {
    final date = isBirthDate ? _birthDate : _lastVaccinatedDate;
    final hint = isBirthDate ? "eg: 03-08-2022" : "eg: 03-08-2025";
    return GestureDetector(
      onTap: () => _showCalendarModal(isBirthDate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            Text(
              date == null
                  ? hint
                  : "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: date == null ? const Color(0xFF9F9F9F) : Colors.black,
                height: 26.95 / 16,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
