import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';

/// Lightweight, plugin-free location value the form consumes.
class GeoLocation {
  const GeoLocation({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

typedef GeolocateFn = Future<GeoLocation?> Function();
typedef ReverseGeocodeFn = Future<String?> Function(GeoLocation location);

/// Production geolocate closure. Returns null on web, on permission denial,
/// and on any platform exception. Never throws.
GeolocateFn createDefaultGeolocate() {
  if (kIsWeb) return () async => null;
  return () async {
    try {
      final perm = await Geolocator.checkPermission();
      final granted =
          perm == LocationPermission.always || perm == LocationPermission.whileInUse
              ? perm
              : await Geolocator.requestPermission();
      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition();
      return GeoLocation(latitude: pos.latitude, longitude: pos.longitude);
    } catch (_) {
      return null;
    }
  };
}

/// Production reverse-geocode closure. Returns null on web, on platform
/// errors, and on empty placemark results. Never throws.
ReverseGeocodeFn createDefaultReverseGeocode() {
  if (kIsWeb) return (_) async => null;
  return (loc) async {
    try {
      final placemarks =
          await gc.placemarkFromCoordinates(loc.latitude, loc.longitude);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = <String>[];
      void addIfPresent(String? s) {
        if (s != null && s.isNotEmpty) parts.add(s);
      }

      addIfPresent(p.street);
      addIfPresent(p.subLocality);
      addIfPresent(p.locality);
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  };
}
