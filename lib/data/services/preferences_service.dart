import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/travel_plan.dart';

class PreferencesService {
  PreferencesService(this._prefs, this._box);

  final SharedPreferences _prefs;
  final GetStorage _box;

  static Future<PreferencesService> create() async {
    return PreferencesService(
      await SharedPreferences.getInstance(),
      GetStorage(),
    );
  }

  bool get isDarkMode => _prefs.getBool('darkMode') ?? false;
  String get languageCode => _prefs.getString('languageCode') ?? 'en';
  bool get useGps => _box.read<bool>('useGps') ?? false;
  Map<String, dynamic>? get lastPlan =>
      _box.read<Map<String, dynamic>>('lastPlan');

  Future<void> setDarkMode(bool value) => _prefs.setBool('darkMode', value);
  Future<void> setLanguageCode(String value) =>
      _prefs.setString('languageCode', value);
  Future<void> setUseGps(bool value) => _box.write('useGps', value);
  Future<void> savePlan(TravelPlan plan) =>
      _box.write('lastPlan', plan.toJson());

  Future<void> clearLegacyPlan() => _box.remove('lastPlan');
}
