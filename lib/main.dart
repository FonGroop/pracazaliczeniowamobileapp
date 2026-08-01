import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/city_companion_app.dart';
import 'data/services/local_database_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await GetStorage.init();
  await LocalDatabaseService.bootstrap();
  await _initializeFirebase();

  runApp(const ProviderScope(child: CityCompanionApp()));
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    // Firebase is optional for the guide. Do not block the app if native
    // configuration is absent on a platform the user is not using.
    debugPrint('Firebase initialization skipped: ${error.code}');
  }
}
