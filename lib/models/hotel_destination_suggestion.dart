class HotelDestinationSuggestion {
  final String name;
  final String? localizedName;
  final String? countryName;
  final String? countryNameLocalized;
  final String? countryCode;
  final String? placeId;
  final String? destinationCode;
  final String type;
  final double? latitude;
  final double? longitude;

  const HotelDestinationSuggestion({
    required this.name,
    this.localizedName,
    this.countryName,
    this.countryNameLocalized,
    this.countryCode,
    this.placeId,
    this.destinationCode,
    this.type = 'city',
    this.latitude,
    this.longitude,
  });

  factory HotelDestinationSuggestion.fromJson(Map<String, dynamic> json) {
    double? coordinate(Object? value) {
      if (value is num && value.isFinite) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    String? optionalText(Object? value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    final name = optionalText(json['name']) ??
        optionalText(json['name_en']) ??
        optionalText(json['city']) ??
        '';
    if (name.isEmpty) {
      throw const FormatException('Destination suggestion has no name');
    }

    return HotelDestinationSuggestion(
      name: name,
      localizedName:
          optionalText(json['localized_name']) ?? optionalText(json['name_ar']),
      countryName:
          optionalText(json['country_name']) ?? optionalText(json['country']),
      countryNameLocalized: optionalText(json['country_name_localized']) ??
          optionalText(json['country_name_ar']),
      countryCode: optionalText(json['country_code'])?.toUpperCase(),
      placeId: optionalText(json['place_id']),
      destinationCode:
          optionalText(json['destination_code']) ?? optionalText(json['code']),
      type: optionalText(json['type']) ?? 'city',
      latitude: coordinate(json['latitude'] ?? json['lat']),
      longitude: coordinate(json['longitude'] ?? json['lon']),
    );
  }

  String displayName(String languageCode) {
    if (languageCode.toLowerCase().startsWith('ar') &&
        localizedName?.isNotEmpty == true) {
      return localizedName!;
    }
    return name;
  }

  String displayCountry(String languageCode) {
    if (languageCode.toLowerCase().startsWith('ar') &&
        countryNameLocalized?.isNotEmpty == true) {
      return countryNameLocalized!;
    }
    return countryName ?? '';
  }

  static List<HotelDestinationSuggestion> popularMatches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    return _popular
        .where((destination) =>
            destination.name.toLowerCase().contains(normalized) ||
            (destination.localizedName?.contains(normalized) ?? false) ||
            (destination.countryName?.toLowerCase().contains(normalized) ??
                false) ||
            (destination.countryNameLocalized?.contains(normalized) ?? false))
        .take(12)
        .toList(growable: false);
  }

  /// Scoutly covers Libya only, so the offline fallback lists Libyan cities.
  static const List<HotelDestinationSuggestion> _popular = [
    HotelDestinationSuggestion(
      name: 'Tripoli',
      localizedName: 'طرابلس',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 32.8872,
      longitude: 13.1913,
    ),
    HotelDestinationSuggestion(
      name: 'Benghazi',
      localizedName: 'بنغازي',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 32.1167,
      longitude: 20.0667,
    ),
    HotelDestinationSuggestion(
      name: 'Misrata',
      localizedName: 'مصراتة',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 32.3754,
      longitude: 15.0925,
    ),
    HotelDestinationSuggestion(
      name: 'Sebha',
      localizedName: 'سبها',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 27.0377,
      longitude: 14.4283,
    ),
    HotelDestinationSuggestion(
      name: 'Ghadames',
      localizedName: 'غدامس',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 30.1337,
      longitude: 9.5007,
    ),
    HotelDestinationSuggestion(
      name: 'Al Bayda',
      localizedName: 'البيضاء',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 32.7627,
      longitude: 21.7551,
    ),
    HotelDestinationSuggestion(
      name: 'Tobruk',
      localizedName: 'طبرق',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 32.0836,
      longitude: 23.9764,
    ),
    HotelDestinationSuggestion(
      name: 'Sirte',
      localizedName: 'سرت',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 31.2089,
      longitude: 16.5887,
    ),
    HotelDestinationSuggestion(
      name: 'Al Khums',
      localizedName: 'الخمس',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 32.6486,
      longitude: 14.2619,
    ),
    HotelDestinationSuggestion(
      name: 'Zawiya',
      localizedName: 'الزاوية',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 32.7571,
      longitude: 12.7276,
    ),
    HotelDestinationSuggestion(
      name: 'Derna',
      localizedName: 'درنة',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 32.767,
      longitude: 22.6367,
    ),
    HotelDestinationSuggestion(
      name: 'Ghat',
      localizedName: 'غات',
      countryName: 'Libya',
      countryNameLocalized: 'ليبيا',
      latitude: 24.964,
      longitude: 10.1728,
    ),
  ];
}
