import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/attraction_model.dart';
import '../logic/hotel_controller.dart';

/// Texts of the hotel booking screens (English / Arabic). Existing app
/// strings are reused from [AppLocalizations].
class HotelLabels {
  final AppLocalizations l10n;
  const HotelLabels(this.l10n);

  bool get ar => l10n.localeName.startsWith('ar');
  String _t(String en, String arText) => ar ? arText : en;

  String city(String name) =>
      AttractionModel.localizedCityName(name, l10n.localeName);

  // Search
  String get findYour => _t('Find Your', 'اعثر على');
  String get perfectStay => _t('Perfect Stay', 'إقامتك المثالية');
  String get destination => l10n.destination;
  String get destinationHint => l10n.hotelDestinationHint;
  String get checkIn => l10n.checkIn;
  String get checkOut => l10n.checkOut;
  String get rooms => l10n.hotelRoomsLabel;
  String get guests => l10n.hotelGuestsLabel;
  String get searchHotels => l10n.searchHotelsBtn;
  String get searchNearby => l10n.hotelSearchNearby;
  String stay(int nights, int roomCount, int guestCount) =>
      '${l10n.hotelNightsSummary(nights)} · '
      '${l10n.hotelRoomsSummary(roomCount)} · '
      '${l10n.hotelGuestsSummary(guestCount)}';

  // Results
  String resultsTitle(String cityName) =>
      ar ? 'فنادق ${city(cityName)}' : 'Hotels in ${city(cityName)}';
  String filter(HotelFilter f) => switch (f) {
        HotelFilter.all => l10n.hotelFilterAll,
        HotelFilter.budget => l10n.hotelFilterBudget,
        HotelFilter.midRange => l10n.hotelFilterMidRange,
        HotelFilter.luxury => l10n.hotelFilterLuxury,
      };
  String sort(HotelSort s) => switch (s) {
        HotelSort.rating => _t('Top rated', 'الأعلى تقييمًا'),
        HotelSort.priceLow => _t('Lowest price', 'الأقل سعرًا'),
        HotelSort.priceHigh => _t('Highest price', 'الأعلى سعرًا'),
        HotelSort.distance => _t('Nearest', 'الأقرب'),
      };
  String get perNight => _t('/ night', '/ ليلة');
  String get priceUnavailable => l10n.priceUnavailable;
  String get noResults => l10n.hotelNoResults;
  String get searchUnavailable => l10n.hotelSearchUnavailable;
  String get tryAgain => l10n.tryAgain;
  String kmAway(double meters) {
    final km = meters / 1000;
    final text = km < 1
        ? (ar ? '${meters.round()} م' : '${meters.round()} m')
        : (ar ? '${km.toStringAsFixed(1)} كم' : '${km.toStringAsFixed(1)} km');
    return ar ? 'على بعد $text' : '$text away';
  }

  String providedBy(String partner) =>
      ar ? 'مقدّمة من $partner' : 'Provided by $partner';
  String get featured => l10n.hotelFeatured;
  String get soldOut => l10n.hotelSoldOut;

  // Details
  String get amenities => l10n.hotelAmenities;
  String get about => l10n.hotelAbout;
  String get defaultDescription => l10n.hotelDefaultDescription;
  String get roomRates => l10n.hotelRoomRatesTitle;
  String get location => _t('Location', 'الموقع');
  String get bookNow => l10n.hotelBookNow;
  String get ratingUnavailable => l10n.hotelRatingUnavailable;
  String reviewsCount(int n) => ar ? '$n تقييم' : '$n reviews';
  String get savedToFavorites => _t('Saved to favorites', 'أضيف إلى المفضلة');
  String get removedFromFavorites =>
      _t('Removed from favorites', 'أزيل من المفضلة');

  // Booking & Payment
  String get bookingPayment => _t('Booking & Payment', 'الحجز والدفع');
  String get priceDetails => _t('Price Details', 'تفاصيل السعر');
  String nightsLine(String price, int nights, int roomCount) => ar
      ? '$price × ${l10n.hotelNightsSummary(nights)}'
          '${roomCount > 1 ? ' × ${l10n.hotelRoomsSummary(roomCount)}' : ''}'
      : '$price x ${l10n.hotelNightsSummary(nights)}'
          '${roomCount > 1 ? ' x ${l10n.hotelRoomsSummary(roomCount)}' : ''}';
  String taxes(double percent) =>
      '${l10n.hotelTaxesFees} (${percent.toStringAsFixed(0)}%)';
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
  String get yourStay => _t('Your stay', 'إقامتك');

  // Confirmation
  String get bookingConfirmed => _t('Booking Confirmed!', 'تم تأكيد الحجز!');
  String get allSet => _t(
        'Your stay is all set. We look forward to welcoming you.',
        'إقامتك جاهزة، ونتطلع لاستقبالك.',
      );
  String get bookingId => _t('Booking ID', 'رقم الحجز');
  String get copied => _t('Booking ID copied', 'تم نسخ رقم الحجز');
  String get copy => _t('Copy', 'نسخ');
  String get viewBookingDetails =>
      _t('View Booking Details', 'عرض تفاصيل الحجز');

  String shortDate(DateTime date) =>
      DateFormat.yMMMd(l10n.localeName).format(date);
  String weekdayDate(DateTime date) =>
      DateFormat.MMMEd(l10n.localeName).format(date);
  String dayMonth(DateTime date) =>
      DateFormat.MMMd(l10n.localeName).format(date);
}
