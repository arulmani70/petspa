import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/mobile/create_pet_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/store/repo/store_repository.dart';

class _FakeStoreRepository extends StoreRepository {
  @override
  Future<List<Map<String, dynamic>>> getPetWeights() async {
    return [
      {'label': 'Small'},
      {'label': 'Medium'},
      {'label': 'Large'},
      {'label': 'Extra Large'},
    ];
  }
}

class _FakePetRepository extends PetRepository {
  Map<String, dynamic>? lastCreatedPet;
  Map<String, dynamic>? lastUpdatedPet;

  @override
  Future<int> createPet(Map<String, dynamic> petData) async {
    lastCreatedPet = petData;
    return 100;
  }

  @override
  Future<int> updatePet(int petId, Map<String, dynamic> petData) async {
    lastUpdatedPet = petData;
    return petId;
  }
}

class _FakeSessionService extends SessionService {
  @override
  Map<String, dynamic>? getSessionUser() {
    return {'id': 1, 'name': 'Test User'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePetRepository fakePetRepo;

  setUp(() {
    GetIt.I.reset();
    fakePetRepo = _FakePetRepository();
    GetIt.I.registerSingleton<StoreRepository>(_FakeStoreRepository());
    GetIt.I.registerSingleton<PetRepository>(fakePetRepo);
    GetIt.I.registerSingleton<SessionService>(_FakeSessionService());
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('Add Pet screen defaults to Medium and shows Size auto-detected banner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PetBloc>(
          create: (_) => PetBloc(repository: ServicesLocator.petRepository),
          child: const CreatePetPageMobile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Weight dropdown displays Medium
    expect(find.text('Medium'), findsWidgets);

    // Find the Container decoration of the auto-detected banner
    final richTextFinder = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains('Size auto-detected: Medium'),
    );
    expect(richTextFinder, findsOneWidget);

    final richText = tester.widget<RichText>(richTextFinder);
    final textSpan = richText.text as TextSpan;
    expect(textSpan.children, isNotNull);
    expect(textSpan.children!.length, equals(2));
    
    // First part: "Size auto-detected: " in black
    expect((textSpan.children![0] as TextSpan).text, equals('Size auto-detected: '));
    expect((textSpan.children![0] as TextSpan).style?.color, equals(Colors.black));

    // Second part: "Medium" in bold blue
    expect((textSpan.children![1] as TextSpan).text, equals('Medium'));
    expect((textSpan.children![1] as TextSpan).style?.color, equals(const Color(0xFF0077CC)));
    expect((textSpan.children![1] as TextSpan).style?.fontWeight, equals(FontWeight.w700));
  });

  testWidgets('Selecting another weight updates the Size auto-detected banner accordingly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PetBloc>(
          create: (_) => PetBloc(repository: ServicesLocator.petRepository),
          child: const CreatePetPageMobile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Weight dropdown
    final weightTitleFinder = find.text('Weight');
    await tester.ensureVisible(weightTitleFinder);
    await tester.pumpAndSettle();

    // Tap on the Medium dropdown to open menu
    final mediumFinder = find.text('Medium').first;
    await tester.ensureVisible(mediumFinder);
    await tester.pumpAndSettle();
    await tester.tap(mediumFinder);
    await tester.pumpAndSettle();

    // Tap on 'Large' in the menu
    expect(find.text('Large'), findsWidgets);
    final largeItemFinder = find.text('Large').last;
    await tester.tap(largeItemFinder);
    await tester.pumpAndSettle();

    // Verify Size auto-detected banner updated to Large
    final richTextFinder = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains('Size auto-detected: Large'),
    );
    expect(richTextFinder, findsOneWidget);

    final richText = tester.widget<RichText>(richTextFinder);
    final textSpan = richText.text as TextSpan;
    expect((textSpan.children![1] as TextSpan).text, equals('Large'));
  });
}
