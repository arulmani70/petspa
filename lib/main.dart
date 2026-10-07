import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/app/app.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ServicesLocator.initialize();

  runApp(const App());
}
