import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/city_companion_app.dart';
import 'app/providers.dart';
import 'data/repositories/plan_repository.dart';
import 'data/services/local_database_service.dart';
import 'data/services/preferences_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await Future.wait([GetStorage.init(), LocalDatabaseService.bootstrap()]);
  unawaited(_initializeFirebase());
  final preferences = await PreferencesService.create();

  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(AsyncData(preferences)),
        themeModeProvider.overrideWith(
          (ref) => preferences.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        ),
        localeProvider.overrideWith((ref) => Locale(preferences.languageCode)),
        useGpsProvider.overrideWith((ref) => preferences.useGps),
      ],
      child: const CityCompanionApp(),
    ),
  );

  unawaited(
    PlanRepository(
      databaseService: LocalDatabaseService.instance,
    ).migrateLegacyPlan(preferences).catchError((Object error) {
      debugPrint('Legacy plan migration skipped: $error');
    }),
  );
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
  } on Object catch (error) {
    debugPrint('Firebase initialization skipped: $error');
  }
}
