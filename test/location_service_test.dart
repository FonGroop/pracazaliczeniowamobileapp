import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pracazaliczeniowamobileapp/data/services/location_service.dart';

void main() {
  test('disabled services produce an explicit failure instead of Warsaw', () {
    final service = LocationService(
      gateway: _FakeLocationGateway(serviceEnabled: false),
    );

    expect(service.currentPosition(), throwsA(isA<LocationServicesDisabled>()));
  });

  test('permanently denied permission produces an actionable failure', () {
    final service = LocationService(
      gateway: _FakeLocationGateway(
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.deniedForever,
      ),
    );

    expect(
      service.currentPosition(),
      throwsA(isA<LocationPermissionPermanentlyDenied>()),
    );
  });

  test('last known device position is used if a fresh fix times out', () async {
    const lastKnown = LatLng(50.0614, 19.9366);
    final service = LocationService(
      gateway: _FakeLocationGateway(
        currentPositionError: Exception('timeout'),
        lastKnownPosition: lastKnown,
      ),
    );

    expect(await service.currentPosition(), lastKnown);
  });

  test('a successful device fix is returned without a city fallback', () async {
    const devicePosition = LatLng(48.2082, 16.3738);
    final service = LocationService(
      gateway: _FakeLocationGateway(currentPosition: devicePosition),
    );

    expect(await service.currentPosition(), devicePosition);
  });
}

class _FakeLocationGateway implements LocationGateway {
  _FakeLocationGateway({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.currentPosition = const LatLng(50.0614, 19.9366),
    this.currentPositionError,
    this.lastKnownPosition,
  });

  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission requestedPermission;
  final LatLng currentPosition;
  final Object? currentPositionError;
  final LatLng? lastKnownPosition;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LatLng> getCurrentPosition() async {
    if (currentPositionError case final error?) throw error;
    return currentPosition;
  }

  @override
  Future<LatLng?> getLastKnownPosition() async => lastKnownPosition;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission;
}
