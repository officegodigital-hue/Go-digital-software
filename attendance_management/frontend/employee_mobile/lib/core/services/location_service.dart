import 'dart:async';

import 'package:geolocator/geolocator.dart';

class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;

  String get latitudeText {
    return latitude.toStringAsFixed(6);
  }

  String get longitudeText {
    return longitude.toStringAsFixed(6);
  }

  String get accuracyText {
    return '${accuracy.toStringAsFixed(1)} metres';
  }
}

class LocationService {
  Future<AppLocation> getCurrentLocation() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Location service is disabled. Please turn on GPS and try again.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is permanently denied. Enable it from device settings.',
      );
    }

    try {
      const locationSettings =
          LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 20),
      );

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      return AppLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        capturedAt: position.timestamp,
      );
    } on TimeoutException {
      throw const LocationServiceException(
        'Unable to get your location. Please check GPS and try again.',
      );
    } on LocationServiceDisabledException {
      throw const LocationServiceException(
        'Location service is disabled. Please turn on GPS.',
      );
    } on PermissionDeniedException {
      throw const LocationServiceException(
        'Location permission is required for attendance.',
      );
    } catch (error) {
      if (error is LocationServiceException) {
        rethrow;
      }

      throw LocationServiceException(
        'Unable to get location: $error',
      );
    }
  }
}

class LocationServiceException
    implements Exception {
  const LocationServiceException(
    this.message,
  );

  final String message;

  @override
  String toString() {
    return message;
  }
}