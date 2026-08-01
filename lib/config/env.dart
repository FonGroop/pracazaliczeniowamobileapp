import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'PLACES_API_URL')
  static final String placesApiUrl = _Env.placesApiUrl;
}
