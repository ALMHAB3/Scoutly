import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
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

  int get days => returnDate.difference(pickupDate).inDays.clamp(1, 999);

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

  /// Tomorrow for three days, every location.
  static CarSearchParams initial({String city = ''}) {
    final now = DateTime.now();
    final pickup =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return CarSearchParams(
      city: city,
      pickupDate: pickup,
      returnDate: pickup.add(const Duration(days: 3)),
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
      CarFeature.bluetooth => car.features.any((f) {
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

class CarController extends ChangeNotifier {
  CarSearchParams searchParams;
  CarFilters filters = const CarFilters();
  List<CarModel> results = [];
  bool isLoading = false;
  bool loadFailed = false;
  CarModel? selectedCar;

  CarController({CarSearchParams? params})
      : searchParams = params ?? CarSearchParams.initial();

  /// Results after the filters (best rated first): the Browse list.
  List<CarModel> get filteredResults =>
      results.where(filters.matches).toList(growable: false);

  Future<void> search(CarSearchParams params) async {
    searchParams = params;
    isLoading = true;
    loadFailed = false;
    notifyListeners();
    try {
      results = await loadCars(params.city);
    } catch (_) {
      results = [];
      loadFailed = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Cars available at [city] (every location when empty), best first.
  static Future<List<CarModel>> loadCars(String city) async {
    final cars = await ApiService.instance.searchCars(city: city.trim());
    return sortCars(cars);
  }

  /// Adopts what the Search & Filters screen already loaded.
  void apply({
    required CarSearchParams params,
    required CarFilters filters,
    required List<CarModel> cars,
  }) {
    searchParams = params;
    this.filters = filters;
    results = sortCars(cars);
    loadFailed = false;
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

  static List<CarModel> sortCars(Iterable<CarModel> cars) => [...cars]
    ..sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      return byRating != 0 ? byRating : a.pricePerDay.compareTo(b.pricePerDay);
    });
}
