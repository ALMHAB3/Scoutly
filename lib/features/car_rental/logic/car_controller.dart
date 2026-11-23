import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/car_geo.dart';
import '../../../models/car_model.dart';

class CarSearchParams {
  /// Pickup location; empty = every location (the Browse list).
  final String city;

  /// Drop-off location; empty = same as pickup.
  final String dropoffCity;
  final DateTime pickupDate;
  final DateTime returnDate;

  const CarSearchParams({
    required this.city,
    required this.pickupDate,
    required this.returnDate,
    this.dropoffCity = '',
  });

  /// Rental days, counted like the server (calendar days between the UTC
  /// dates of pickup and drop-off, at least one), so totals always match.
  int get days {
    final a = pickupDate.toUtc();
    final b = returnDate.toUtc();
    final d = DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
    return d.clamp(1, 999);
  }

  String get dropoffOrPickup => dropoffCity.trim().isEmpty ? city : dropoffCity;

  CarSearchParams copyWith({
    String? city,
    String? dropoffCity,
    DateTime? pickupDate,
    DateTime? returnDate,
  }) =>
      CarSearchParams(
        city: city ?? this.city,
        dropoffCity: dropoffCity ?? this.dropoffCity,
        pickupDate: pickupDate ?? this.pickupDate,
        returnDate: returnDate ?? this.returnDate,
      );

  /// Default pickup/drop-off time of day.
  static const defaultHour = 10;

  /// Tomorrow at 10:00 for three days.
  static CarSearchParams initial({String city = ''}) {
    final now = DateTime.now();
    final pickup = DateTime(now.year, now.month, now.day + 1, defaultHour);
    return CarSearchParams(
      city: city,
      pickupDate: pickup,
      returnDate:
          DateTime(pickup.year, pickup.month, pickup.day + 3, defaultHour),
    );
  }
}

/// Feature filters offered on the Search & Filters screen.
enum CarFeature { automatic, ac, gps, bluetooth }

bool carHasFeature(CarModel car, CarFeature feature) => switch (feature) {
      CarFeature.automatic => car.transmission == 'automatic',
      CarFeature.ac => car.hasAC,
      CarFeature.gps =>
        car.hasGPS || car.features.any((f) => f.toLowerCase().contains('gps')),
      CarFeature.bluetooth => car.hasBluetooth ||
          car.features.any((f) {
            final text = f.toLowerCase();
            return text.contains('bluetooth') || text.contains('بلوتوث');
          }),
    };

/// Client-side filters applied to the cars of the chosen location.
@immutable
class CarFilters {
  final String carType;

  /// Daily price bounds in USD (the provider's currency); null = no bound.
  final double? minPricePerDay;
  final double? maxPricePerDay;
  final Set<CarFeature> features;

  const CarFilters({
    this.carType = 'all',
    this.minPricePerDay,
    this.maxPricePerDay,
    this.features = const {},
  });

  CarFilters copyWith({
    String? carType,
    double? minPricePerDay,
    double? maxPricePerDay,
    bool clearPrice = false,
    Set<CarFeature>? features,
  }) =>
      CarFilters(
        carType: carType ?? this.carType,
        minPricePerDay:
            clearPrice ? null : (minPricePerDay ?? this.minPricePerDay),
        maxPricePerDay:
            clearPrice ? null : (maxPricePerDay ?? this.maxPricePerDay),
        features: features ?? this.features,
      );

  bool matches(CarModel car) {
    if (car.availableVehicles < 1) return false;
    if (carType != 'all' && car.type != carType) return false;
    if (minPricePerDay != null && car.pricePerDay < minPricePerDay! - 0.001) {
      return false;
    }
    if (maxPricePerDay != null && car.pricePerDay > maxPricePerDay! + 0.001) {
      return false;
    }
    return features.every((feature) => carHasFeature(car, feature));
  }
}

/// Where the customer is: their city (from the supported locations) and
/// position. Customers only see cars of this city, nearest first.
@immutable
class CustomerLocation {
  final String city;
  final double latitude;
  final double longitude;

  const CustomerLocation({
    required this.city,
    required this.latitude,
    required this.longitude,
  });
}

class CarController extends ChangeNotifier {
  CarSearchParams searchParams;
  CarFilters filters = const CarFilters();
  CustomerLocation? customer;
  List<CarModel> results = [];
  bool isLoading = false;
  bool loadFailed = false;
  CarModel? selectedCar;

  CarController({CarSearchParams? params})
      : searchParams = params ?? CarSearchParams.initial();

  /// Results after the filters: the Browse list (nearest first).
  List<CarModel> get filteredResults =>
      results.where(filters.matches).toList(growable: false);

  /// Loads the cars of the customer's city.
  Future<void> loadFor(CustomerLocation location) async {
    customer = location;
    searchParams = searchParams.copyWith(city: location.city);
    isLoading = true;
    loadFailed = false;
    notifyListeners();
    try {
      final cars = await ApiService.instance.searchCars(city: location.city);
      results = carsInCustomerCity(cars, location);
    } catch (_) {
      results = [];
      loadFailed = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Only cars listed in the customer's city (never other cities), with
  /// their distance from the customer; nearest first, then best rated.
  static List<CarModel> carsInCustomerCity(
    Iterable<CarModel> cars,
    CustomerLocation location,
  ) {
    final city = location.city.trim().toLowerCase();
    final inCity = <CarModel>[];
    for (final car in cars) {
      final carCity =
          (car.city.isNotEmpty ? car.city : car.pickupLocation).trim();
      if (carCity.toLowerCase() != city) continue;
      final distance = carDistanceMeters(
        fromLatitude: location.latitude,
        fromLongitude: location.longitude,
        toLatitude: car.latitude,
        toLongitude: car.longitude,
      );
      inCity.add(distance == null ? car : car.withDistanceMeters(distance));
    }
    inCity.sort((a, b) {
      final da = a.distanceMeters, db = b.distanceMeters;
      if (da != null && db != null && da != db) return da.compareTo(db);
      if (da != null && db == null) return -1;
      if (da == null && db != null) return 1;
      final byRating = b.rating.compareTo(a.rating);
      return byRating != 0 ? byRating : a.pricePerDay.compareTo(b.pricePerDay);
    });
    return inCity;
  }

  /// Adopts the dates and filters chosen on the Search & Filters screen.
  void apply({required CarSearchParams params, required CarFilters filters}) {
    searchParams = params;
    this.filters = filters;
    notifyListeners();
  }

  void setCarType(String type) {
    filters = filters.copyWith(carType: type);
    notifyListeners();
  }

  void selectCar(CarModel car) {
    selectedCar = car;
    notifyListeners();
  }
}
