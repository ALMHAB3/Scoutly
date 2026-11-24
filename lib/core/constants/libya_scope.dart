import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Scoutly is a domestic travel app: flights, hotels and places cover Libya
/// only. The backend enforces this; the app uses these values to keep maps
/// and defaults inside the country.
abstract final class LibyaScope {
  static const String countryCode = 'LY';

  /// Tripoli city centre, used when the user's location is outside Libya.
  static const LatLng defaultCenter = LatLng(32.8872, 13.1913);

  static final LatLngBounds bounds = LatLngBounds(
    const LatLng(19.4, 9.2),
    const LatLng(33.6, 25.4),
  );

  static bool contains(LatLng point) => bounds.contains(point);
}
