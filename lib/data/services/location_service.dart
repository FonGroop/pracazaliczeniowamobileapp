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
        timeLimit: Duration(seconds: 20),
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
  LocationService({LocationGateway? gateway})
    : _gateway = gateway ?? const GeolocatorGateway();

  final LocationGateway _gateway;

  Future<LatLng> currentPosition() async {
    if (!await _gateway.isServiceEnabled()) {
      throw const LocationServicesDisabled();
    }

    var permission = await _gateway.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _gateway.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDenied();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDenied();
    }

    try {
      return await _gateway.getCurrentPosition();
    } on Object catch (error) {
      final lastKnown = await _gateway.getLastKnownPosition();
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
