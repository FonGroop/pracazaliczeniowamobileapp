import 'dart:async';

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
        permission: LocationPermission.deniedForever,
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

  test(
    'startup uses a last known real position without waiting for GPS',
    () async {
      const lastKnown = LatLng(51.1079, 17.0385);
      final gateway = _FakeLocationGateway(lastKnownPosition: lastKnown);
      final service = LocationService(gateway: gateway);

      expect(await service.initialPosition(), lastKnown);
      expect(gateway.currentPositionCalls, 0);
      expect(gateway.serviceEnabledCalls, 0);
      expect(gateway.permissionCheckCalls, 0);
    },
  );

  test('explicit centering still requests a fresh position', () async {
    const lastKnown = LatLng(51.1079, 17.0385);
    const fresh = LatLng(51.1082, 17.0391);
    final gateway = _FakeLocationGateway(
      currentPosition: fresh,
      lastKnownPosition: lastKnown,
    );
    final service = LocationService(gateway: gateway);

    expect(await service.currentPosition(), fresh);
    expect(gateway.currentPositionCalls, 1);
  });

  test('startup never opens a permission dialog by itself', () async {
    final gateway = _FakeLocationGateway(permission: LocationPermission.denied);
    final service = LocationService(gateway: gateway);

    await expectLater(
      service.initialPosition(),
      throwsA(isA<LocationPermissionDenied>()),
    );
    expect(gateway.permissionRequestCalls, 0);
  });

  test('explicit centering can request location permission', () async {
    final gateway = _FakeLocationGateway(
      permission: LocationPermission.denied,
      requestedPermission: LocationPermission.whileInUse,
    );
    final service = LocationService(gateway: gateway);

    await service.currentPosition();
    expect(gateway.permissionRequestCalls, 1);
  });

  test(
    'a hanging native last-known call cannot block startup forever',
    () async {
      const fresh = LatLng(54.3520, 18.6466);
      final gateway = _FakeLocationGateway(
        currentPosition: fresh,
        lastKnownPositionNeverCompletes: true,
      );
      final service = LocationService(
        gateway: gateway,
        platformTimeout: const Duration(milliseconds: 10),
      );

      expect(await service.initialPosition(), fresh);
      expect(gateway.currentPositionCalls, 1);
    },
  );
}

class _FakeLocationGateway implements LocationGateway {
  _FakeLocationGateway({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.currentPosition = const LatLng(50.0614, 19.9366),
    this.currentPositionError,
    this.lastKnownPosition,
    this.lastKnownPositionNeverCompletes = false,
  });

  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission requestedPermission;
  final LatLng currentPosition;
  final Object? currentPositionError;
  final LatLng? lastKnownPosition;
  final bool lastKnownPositionNeverCompletes;
  var currentPositionCalls = 0;
  var permissionRequestCalls = 0;
  var serviceEnabledCalls = 0;
  var permissionCheckCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    permissionCheckCalls++;
    return permission;
  }

  @override
  Future<LatLng> getCurrentPosition() async {
    currentPositionCalls++;
    if (currentPositionError case final error?) throw error;
    return currentPosition;
  }

  @override
  Future<LatLng?> getLastKnownPosition() {
    if (lastKnownPositionNeverCompletes) return Completer<LatLng?>().future;
    return Future.value(lastKnownPosition);
  }

  @override
  Future<bool> isServiceEnabled() async {
    serviceEnabledCalls++;
    return serviceEnabled;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequestCalls++;
    return requestedPermission;
  }
}
