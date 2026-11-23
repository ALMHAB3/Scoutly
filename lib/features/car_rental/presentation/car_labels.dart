import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/attraction_model.dart';
import '../logic/car_controller.dart';

String carFuelLabel(AppLocalizations l10n, String fuel) => switch (fuel) {
      'electric' => l10n.carFuelElectric,
      'hybrid' => l10n.carFuelHybrid,
      'diesel' => l10n.carFuelDiesel,
      _ => l10n.carFuelPetrol,
    };

/// Texts of the car rental screens (English / Arabic). Existing app strings
/// are reused from [AppLocalizations].
class CarLabels {
  final AppLocalizations l10n;
  const CarLabels(this.l10n);

  bool get ar => l10n.localeName.startsWith('ar');
  String _t(String en, String arText) => ar ? arText : en;

  // Car types shown as chips. Values match the listing categories.
  static const carTypes = [
    'all',
    'economy',
    'suv',
    'luxury',
    'electric',
    'van'
  ];

  String carType(String type) => switch (type) {
        'all' => l10n.carTypeAll,
        'economy' => l10n.economy,
        'suv' => l10n.suv,
        'luxury' => l10n.luxury,
        'electric' => l10n.carTypeElectric,
        'van' => l10n.van,
        _ => type,
      };

  String transmission(String value) => value == 'automatic'
      ? l10n.carTransmissionAuto
      : l10n.carTransmissionManual;

  String feature(CarFeature feature) => switch (feature) {
        CarFeature.automatic => l10n.carTransmissionAuto,
        CarFeature.ac => _t('AC', 'تكييف'),
        CarFeature.gps => 'GPS',
        CarFeature.bluetooth => _t('Bluetooth', 'بلوتوث'),
      };

  // Browse
  String get findYour => _t('Find Your', 'اعثر على');
  String get perfectDrive => _t('Perfect Drive', 'سيارتك المثالية');
  String get searchHint =>
      _t('Search location or car', 'ابحث عن موقع أو سيارة');
  String get popularCars => _t('Popular Cars', 'السيارات الأكثر طلبًا');
  String get allLocations => _t('All locations', 'كل المواقع');
  String get filters => _t('Filters', 'الفلاتر');
  String get noCars => _t(
        'No cars match these filters.',
        'لا توجد سيارات تطابق هذه الفلاتر.',
      );
  String noCarsInCity(String name) => ar
      ? 'لا توجد سيارات متاحة حاليًا في ${city(name)}.'
      : 'No cars are available in ${city(name)} right now.';
  String get clearFilters => _t('Clear filters', 'مسح الفلاتر');
  String get loadFailed => _t('Could not load cars. Try again.',
      'تعذّر تحميل السيارات. حاول مرة أخرى.');
  String get retry => _t('Try again', 'إعادة المحاولة');
  String get perDay => l10n.carPerDaySuffix;

  // Search & Filters
  String get searchCars => _t('Search Cars', 'ابحث عن سيارة');
  String get pickupLocation => _t('Pickup Location', 'موقع الاستلام');
  String get dropoffLocation => _t('Drop-off Location', 'موقع التسليم');
  String get pickupHint => l10n.carPickupCityHint;
  String get sameAsPickup => _t('Same as pickup', 'نفس موقع الاستلام');
  String get pickupDate => _t('Pickup Date', 'تاريخ الاستلام');
  String get dropoffDate => _t('Drop-off Date', 'تاريخ التسليم');
  String get carTypeTitle => l10n.carType;
  String get priceRange => _t('Price Range', 'نطاق السعر');
  String get perDayNote => _t('per day', 'لليوم');
  String get features => l10n.carFeatures;
  String showResults(int n) => ar
      ? (n == 0
          ? 'لا توجد نتائج'
          : n == 1
              ? 'عرض نتيجة واحدة'
              : 'عرض $n نتائج')
      : (n == 0
          ? 'No results'
          : n == 1
              ? 'Show 1 Result'
              : 'Show $n Results');
  String get reset => _t('Reset', 'إعادة ضبط');

  // Details
  String get aboutCar => _t('About the car', 'عن السيارة');
  String about(String name, String location) => ar
      ? 'استمتع بقيادة $name. مناسبة للتنقل داخل المدينة والرحلات الطويلة، والاستلام من $location.'
      : 'Enjoy driving the $name. Great for city drives and long road trips, with pickup in $location.';
  String get year => _t('Year', 'سنة الصنع');
  String get transmissionTitle => _t('Transmission', 'ناقل الحركة');
  String get seats => _t('Seats', 'المقاعد');
  String get bags => _t('Bags', 'الحقائب');
  String get bookNow => _t('Book Now', 'احجز الآن');
  String get soldOut => l10n.carSoldOut;
  String get savedToFavorites => _t('Saved to favorites', 'أضيفت إلى المفضلة');
  String get removedFromFavorites =>
      _t('Removed from favorites', 'أزيلت من المفضلة');

  // Booking & Payment
  String get bookingPayment => _t('Booking & Payment', 'الحجز والدفع');
  String get pickup => _t('Pickup', 'الاستلام');
  String get dropoff => _t('Drop-off', 'التسليم');
  String get priceDetails => _t('Price Details', 'تفاصيل السعر');
  String daysLine(String price, int days) =>
      ar ? '$price × ${l10n.carDaysCount(days)}' : '$price x $days days';
  String get insurance => l10n.carInsurance;
  String get taxesFees => _t('Taxes & Fees', 'الضرائب والرسوم');
  String get totalAmount => _t('Total Amount', 'المبلغ الإجمالي');
  String get paymentMethod => _t('Payment Method', 'طريقة الدفع');
  String get cardPayment => _t('Bank card', 'بطاقة مصرفية');
  String get cardPaymentNote => _t(
        'You enter the card on the secure payment page.',
        'تُدخل بيانات البطاقة في صفحة الدفع الآمنة.',
      );
  String get secureNote => _t(
        'Payments are processed securely. Your card details are never stored in the app.',
        'تتم معالجة الدفع بأمان، ولا تُحفظ بيانات بطاقتك في التطبيق.',
      );
  String pay(String amount) => _t('Pay $amount', 'ادفع $amount');

  // Confirmation
  String get bookingConfirmed => _t('Booking Confirmed!', 'تم تأكيد الحجز!');
  String get allSet => _t('Your trip is all set and ready to go.',
      'رحلتك جاهزة وكل شيء على ما يرام.');
  String get bookingId => _t('Booking ID', 'رقم الحجز');
  String get copied => _t('Booking ID copied', 'تم نسخ رقم الحجز');
  String get copy => _t('Copy', 'نسخ');
  String get viewBookingDetails =>
      _t('View Booking Details', 'عرض تفاصيل الحجز');

  // Location (customers only see cars of the city they are in)
  String get locating => _t('Finding your location…', 'جارٍ تحديد موقعك…');
  String get needLocation => _t(
        'Turn on location to see the cars available in your city.',
        'فعّل الموقع لعرض السيارات المتاحة في مدينتك.',
      );
  String get enableLocation => _t('Use my location', 'استخدم موقعي');

  /// City name in the app language (e.g. مصراتة).
  String city(String name) =>
      AttractionModel.localizedCityName(name, l10n.localeName);
  String carsIn(String name) =>
      ar ? 'سيارات متاحة في ${city(name)}' : 'Cars available in ${city(name)}';
  String get pickupPoint =>
      _t('Pickup point (where the car is)', 'موقع الاستلام (مكان السيارة)');
  String get yourLocation => _t('Your location', 'موقعك');
  String get pickupCityNote => _t(
        'Cars are shown for the city you are in.',
        'تُعرض السيارات المتاحة في المدينة التي أنت فيها.',
      );
  String kmAway(double meters) {
    final km = meters / 1000;
    final text = km < 1
        ? (ar ? '${meters.round()} م' : '${meters.round()} m')
        : (ar ? '${km.toStringAsFixed(1)} كم' : '${km.toStringAsFixed(1)} km');
    return ar ? 'على بعد $text' : '$text away';
  }

  // Partner
  String providedBy(String partner) =>
      ar ? 'مقدّمة من $partner' : 'Provided by $partner';
  String get provider => _t('Rental company', 'شركة التأجير');

  // Times
  String get pickupTime => _t('Pickup time', 'وقت الاستلام');
  String get dropoffTime => _t('Drop-off time', 'وقت التسليم');
  String get changeTime => _t('Change date & time', 'تغيير التاريخ والوقت');
  String get dropoffAfterPickup => _t(
        'Drop-off must be after pickup.',
        'يجب أن يكون التسليم بعد الاستلام.',
      );
  String time(DateTime date) => DateFormat.jm(l10n.localeName).format(date);
  String dateTime(DateTime date) => '${shortDate(date)} · ${time(date)}';

  // Extra specs entered by the partner
  String get engine => _t('Engine', 'المحرك');
  String get fuelEconomy => _t('Fuel economy', 'استهلاك الوقود');
  String get doors => _t('Doors', 'الأبواب');
  String get color => _t('Color', 'اللون');

  String shortDate(DateTime date) =>
      DateFormat.yMMMd(l10n.localeName).format(date);
  String dayMonth(DateTime date) =>
      DateFormat.MMMd(l10n.localeName).format(date);
  String dateRange(DateTime from, DateTime to) =>
      '${dayMonth(from)} – ${shortDate(to)}';
}
