/// One stop of an offer's day plan, set by the admin: on which day of the
/// trip, at what time, where, for how long, with a photo and a map pin.
class OfferStop {
  final int day;

  /// Start time as "HH:mm" (24 h).
  final String time;
  final String name;
  final String nameAr;
  final String category;
  final String categoryAr;
  final String description;
  final String descriptionAr;
  final int durationMinutes;
  final String imageUrl;
  final double? latitude;
  final double? longitude;

  const OfferStop({
    this.day = 1,
    required this.time,
    required this.name,
    this.nameAr = '',
    this.category = '',
    this.categoryAr = '',
    this.description = '',
    this.descriptionAr = '',
    this.durationMinutes = 60,
    this.imageUrl = '',
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  int get hour => int.tryParse(time.split(':').first) ?? 0;
  int get minute => int.tryParse(time.split(':').last) ?? 0;

  /// Minutes from midnight, for sorting and gaps between stops.
  int get startMinutes => hour * 60 + minute;

  static bool _ar(String languageCode) =>
      languageCode.toLowerCase().startsWith('ar');

  String displayName(String languageCode) =>
      _ar(languageCode) && nameAr.trim().isNotEmpty ? nameAr : name;

  String displayCategory(String languageCode) =>
      _ar(languageCode) && categoryAr.trim().isNotEmpty ? categoryAr : category;

  String displayDescription(String languageCode) =>
      _ar(languageCode) && descriptionAr.trim().isNotEmpty
          ? descriptionAr
          : description;

  static double? _double(dynamic value) => value == null
      ? null
      : value is num
          ? value.toDouble()
          : double.tryParse(value.toString());

  factory OfferStop.fromJson(Map<String, dynamic> json) => OfferStop(
        day: int.tryParse('${json['day'] ?? 1}') ?? 1,
        time: (json['time'] ?? '00:00').toString(),
        name: (json['name'] ?? '').toString(),
        nameAr: (json['name_ar'] ?? '').toString(),
        category: (json['category'] ?? '').toString(),
        categoryAr: (json['category_ar'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        descriptionAr: (json['description_ar'] ?? '').toString(),
        durationMinutes:
            int.tryParse('${json['duration_minutes'] ?? 60}') ?? 60,
        imageUrl: (json['image_url'] ?? '').toString(),
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'time': time,
        'name': name,
        'name_ar': nameAr,
        'category': category,
        'category_ar': categoryAr,
        'description': description,
        'description_ar': descriptionAr,
        'duration_minutes': durationMinutes,
        'image_url': imageUrl,
        if (hasLocation) 'latitude': latitude,
        if (hasLocation) 'longitude': longitude,
      };

  OfferStop copyWith({int? day}) => OfferStop(
        day: day ?? this.day,
        time: time,
        name: name,
        nameAr: nameAr,
        category: category,
        categoryAr: categoryAr,
        description: description,
        descriptionAr: descriptionAr,
        durationMinutes: durationMinutes,
        imageUrl: imageUrl,
        latitude: latitude,
        longitude: longitude,
      );

  /// Sorted by day, then start time.
  static List<OfferStop> sorted(Iterable<OfferStop> stops) => stops.toList()
    ..sort((a, b) => a.day != b.day
        ? a.day.compareTo(b.day)
        : a.startMinutes.compareTo(b.startMinutes));
}
