import 'dart:async';
import 'dart:js_interop';

@JS('google.maps.Geocoder')
extension type _Geocoder._(JSObject _) implements JSObject {
  external factory _Geocoder();
  external void geocode(JSObject request, JSFunction callback);
}

extension type _Result._(JSObject _) implements JSObject {
  @JS('formatted_address')
  external String get formattedAddress;
  external _Geometry get geometry;
}

extension type _Geometry._(JSObject _) implements JSObject {
  external _Point get location;
}

extension type _Point._(JSObject _) implements JSObject {
  external double lat();
  external double lng();
}

final Map<String, String?> _reverseAddressCache = {};

Future<List<Map<String, dynamic>>> searchOfficeAddress(String address) async {
  final completer = Completer<List<Map<String, dynamic>>>();
  try {
    _Geocoder().geocode(
      {'address': address}.jsify() as JSObject,
      ((JSArray<_Result>? results, JSString status) {
        if (completer.isCompleted) return;
        final code = status.toDart;
        if (code == 'OK' || code == 'ZERO_RESULTS') {
          completer.complete([
            for (final result in results?.toDart ?? <_Result>[])
              {
                'address': result.formattedAddress,
                'latitude': result.geometry.location.lat(),
                'longitude': result.geometry.location.lng(),
              },
          ]);
        } else {
          completer.completeError(
            Exception(
              code == 'REQUEST_DENIED'
                  ? 'Address search is not enabled for this website. Enable Google Geocoding API for the map key, or select a pin manually.'
                  : 'Address search is temporarily unavailable. Try again or select a pin manually.',
            ),
          );
        }
      }).toJS,
    );
  } catch (_) {
    throw Exception(
      'Map search could not load. Refresh the page and try again.',
    );
  }
  return completer.future.timeout(const Duration(seconds: 15));
}

/// Resolves a GPS or map-pin coordinate into the address displayed by the
/// office-location editor.
Future<String?> reverseGeocodeOfficeLocation(
  double latitude,
  double longitude,
) async {
  final cacheKey =
      '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
  if (_reverseAddressCache.containsKey(cacheKey)) {
    return _reverseAddressCache[cacheKey];
  }
  final completer = Completer<String?>();
  try {
    _Geocoder().geocode(
      {
            'location': {'lat': latitude, 'lng': longitude}.jsify(),
          }.jsify()
          as JSObject,
      ((JSArray<_Result>? results, JSString status) {
        if (completer.isCompleted) return;
        if (status.toDart == 'OK' && (results?.toDart.isNotEmpty ?? false)) {
          completer.complete(results!.toDart.first.formattedAddress);
        } else {
          completer.complete(null);
        }
      }).toJS,
    );
  } catch (_) {
    return null;
  }
  final address = await completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => null,
  );
  // A temporary lookup failure must not poison later attempts for this pin.
  if (address != null && address.trim().isNotEmpty) {
    _reverseAddressCache[cacheKey] = address;
  }
  return address;
}
