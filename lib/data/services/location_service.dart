import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

sealed class LocationFailure implements Exception {
  const LocationFailure();
}

class LocationServicesDisabled extends LocationFailure {
  const LocationServicesDisabled();
}

class LocationPermissionDenied extends LocationFailure {
  const LocationPermissionDenied();
}

class LocationPermissionPermanentlyDenied extends LocationFailure {
  const LocationPermissionPermanentlyDenied();
}

class LocationFixUnavailable extends LocationFailure {
  const LocationFixUnavailable([this.cause]);

  final Object? cause;
}

abstract interface class LocationGateway {
  Future<bool> isServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<LatLng> getCurrentPosition();

  Future<LatLng?> getLastKnownPosition();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<LatLng> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Future<LatLng?> getLastKnownPosition() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

class LocationService {
  LocationService({
    LocationGateway? gateway,
    this.platformTimeout = const Duration(seconds: 2),
    this.freshFixTimeout = const Duration(seconds: 5),
  }) : _gateway = gateway ?? const GeolocatorGateway();

  final LocationGateway _gateway;
  final Duration platformTimeout;
  final Duration freshFixTimeout;

  /// Fast startup path: use the device's last real fix before requesting a new
  /// high-accuracy position. No hard-coded city is returned when GPS is on.
  Future<LatLng> initialPosition() async {
    try {
      final lastKnown = await _gateway.getLastKnownPosition().timeout(
        platformTimeout,
      );
      if (lastKnown != null) return lastKnown;
    } on Object {
      // A fresh fix below can still succeed if the platform has no cache.
    }
    await _ensureLocationAccess(requestPermissionIfNeeded: false);
    return _freshPosition();
  }

  /// Explicit refresh path used by the map centering button.
  Future<LatLng> currentPosition() async {
    await _ensureLocationAccess(requestPermissionIfNeeded: true);
    return _freshPosition();
  }

  Future<void> _ensureLocationAccess({
    required bool requestPermissionIfNeeded,
  }) async {
    bool serviceEnabled;
    try {
      serviceEnabled = await _gateway.isServiceEnabled().timeout(
        platformTimeout,
      );
    } on TimeoutException catch (error) {
      throw LocationFixUnavailable(error);
    }
    if (!serviceEnabled) {
      throw const LocationServicesDisabled();
    }

    LocationPermission permission;
    try {
      permission = await _gateway.checkPermission().timeout(platformTimeout);
    } on TimeoutException catch (error) {
      throw LocationFixUnavailable(error);
    }
    if (permission == LocationPermission.denied && requestPermissionIfNeeded) {
      permission = await _gateway.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDenied();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDenied();
    }
  }

  Future<LatLng> _freshPosition() async {
    try {
      return await _gateway.getCurrentPosition().timeout(freshFixTimeout);
    } on Object catch (error) {
      LatLng? lastKnown;
      try {
        lastKnown = await _gateway.getLastKnownPosition().timeout(
          platformTimeout,
        );
      } on Object {
        // The original fresh-fix error is more useful to the caller.
      }
      if (lastKnown != null) return lastKnown;
      throw LocationFixUnavailable(error);
    }
  }

  Future<bool> openSettingsFor(LocationFailure failure) async {
    try {
      return switch (failure) {
        LocationServicesDisabled() => _gateway.openLocationSettings(),
        _ => _gateway.openAppSettings(),
      };
    } on Object {
      return false;
    }
  }
}
