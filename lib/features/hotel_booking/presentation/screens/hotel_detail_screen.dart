import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_result.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/booking_load_error.dart';
import '../../../../global_widgets/review_form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/hotel_model.dart';
import '../../../../models/review_model.dart';
import '../../../favorites/logic/favorites_controller.dart';
import '../../logic/hotel_controller.dart';
import '../hotel_labels.dart';
import '../widgets/hotel_widgets.dart';
import 'hotel_booking_screen.dart';
import '../../../../global_widgets/ui/ui.dart';

/// Hotel details: photos, favorite, price per night, amenities, about, room
/// rates, reviews, location and Book Now (same design as the car details).
class HotelDetailScreen extends StatefulWidget {
  const HotelDetailScreen({super.key, this.loadReviews});

  final Future<ApiResult<List<ReviewModel>>> Function(String itemId)?
      loadReviews;

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  HotelController? _ctrl;
  int _photoIndex = 0;
  Future<ApiResult<List<ReviewModel>>>? _hotelReviewsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller =
        ModalRoute.of(context)?.settings.arguments as HotelController?;
    if (_ctrl != controller) {
      _ctrl = controller;
      final hotel = controller?.selectedHotel;
      if (hotel != null) {
        final loadReviews = widget.loadReviews;
        _hotelReviewsFuture = loadReviews == null
            ? ApiService.instance.getReviews(itemId: hotel.id)
            : loadReviews(hotel.id);
      }
    }
  }

  void _writeHotelReview(HotelModel hotel) {
    ReviewFormSheet.show(
      context,
      itemId: hotel.id,
      itemType: 'hotel',
      onSubmitted: () {
        if (!mounted) return;
        setState(() {
          _hotelReviewsFuture =
              ApiService.instance.getReviews(itemId: hotel.id);
        });
      },
    );
  }

  String _favoriteId(HotelModel hotel) => 'hotel:${hotel.id}';

  Future<void> _toggleFavorite(HotelModel hotel, HotelLabels labels) async {
    final favorites = FavoritesController.instance;
    final wasFavorite = favorites.isFavorite(_favoriteId(hotel));
    await favorites.toggle(FavoritePlace(
      id: _favoriteId(hotel),
      title: hotel.name,
      subtitle: hotel.address.isEmpty ? hotel.city : hotel.address,
      type: 'hotel',
      imageUrl: hotel.imageUrl,
      latitude: hotel.latitude,
      longitude: hotel.longitude,
    ));
    if (!mounted) return;
    AppSnackbar.success(
      context,
      wasFavorite ? labels.removedFromFavorites : labels.savedToFavorites,
    );
  }

  void _book(HotelModel hotel) {
    final params = _ctrl?.searchParams;
    final checkIn = params?.checkIn ?? DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelBookingScreen(
          hotel: hotel,
          params: params ??
              HotelSearchParams(
                city: hotel.city,
                checkIn: checkIn,
                checkOut: checkIn.add(const Duration(days: 1)),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = HotelLabels(AppLocalizations.of(context));
    final ctrl = _ctrl;
    final hotel = ctrl?.selectedHotel;
    if (hotel == null) return const BookingLoadError();
    final rooms = ctrl?.searchParams?.rooms ?? 1;
    final soldOut = hotel.availabilityKnown && hotel.availableRooms < rooms;
    final priced = hotel.comparisonNightlyPrice != null;
    final photos = hotel.photos;

    return Scaffold(
      backgroundColor: context.uiPageBackground,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                SizedBox(
                  height: 300,
                  child: photos.isEmpty
                      ? HotelPhoto(hotel: hotel, height: 300)
                      : PageView.builder(
                          itemCount: photos.length,
                          onPageChanged: (i) => setState(() => _photoIndex = i),
                          itemBuilder: (_, i) => HotelPhoto(
                            hotel: hotel,
                            url: photos[i],
                            height: 300,
                          ),
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const Spacer(),
                        ListenableBuilder(
                          listenable: FavoritesController.instance,
                          builder: (context, _) {
                            final saved = FavoritesController.instance
                                .isFavorite(_favoriteId(hotel));
                            return AppIconButton(
                              icon: saved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: saved ? AppColors.accentRed : null,
                              tooltip: saved
                                  ? labels.removedFromFavorites
                                  : labels.savedToFavorites,
                              onPressed: () => _toggleFavorite(hotel, labels),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (photos.length > 1)
                  PositionedDirectional(
                    start: 16,
                    bottom: 30,
                    child: AppPill(
                      icon: Icons.photo_library_outlined,
                      text: '${_photoIndex + 1}/${photos.length}',
                    ),
                  ),
                PositionedDirectional(
                  end: 16,
                  bottom: 30,
                  child: AppRatingBadge(
                    rating: hotel.hasGoogleRating ? hotel.rating : 0,
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: context.uiSurface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              transform: Matrix4.translationValues(0, -18, 0),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          hotel.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: context.uiInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      HotelNightlyPrice(
                        hotel: hotel,
                        labels: labels,
                        fontSize: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      HotelStars(stars: hotel.starRating, size: 15),
                      if (hotel.starRating > 0) const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          hotel.hasGoogleRating
                              ? '${hotel.rating.toStringAsFixed(1)} · '
                                  '${labels.reviewsCount(hotel.reviewCount)}'
                              : labels.ratingUnavailable,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.uiMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((hotel.partnerName ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    HotelProviderLine(
                        hotel: hotel, labels: labels, fontSize: 13),
                  ],
                  if (hotel.address.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 16, color: context.uiMuted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            hotel.distanceMeters == null
                                ? hotel.address
                                : '${hotel.address} · '
                                    '${labels.kmAway(hotel.distanceMeters!)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.uiMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hotel.amenities.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    AppSectionTitle(labels.amenities),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, box) {
                        final width = (box.maxWidth - 20) / 3;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final amenity in hotel.amenities)
                              SizedBox(
                                width: width,
                                child: AppFeatureTile(
                                  icon: hotelAmenityIcon(amenity),
                                  label: amenity,
                                  maxLines: 2,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 22),
                  AppSectionTitle(labels.about),
                  const SizedBox(height: 8),
                  Text(
                    hotel.description.isEmpty
                        ? labels.defaultDescription
                        : hotel.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: context.uiMuted,
                    ),
                  ),
                  if (hotel.offers.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    AppSectionTitle(labels.roomRates),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Column(
                        children: [
                          for (var i = 0; i < hotel.offers.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: context.uiBorder),
                            _OfferRow(
                              name:
                                  _offerName(hotel.offers[i], labels.roomRates),
                              price: _offerPrice(
                                  hotel.offers[i], hotel.priceCurrencyCode),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _hotelReviewsSection(hotel),
                  if (hotel.latitude != null &&
                      hotel.longitude != null &&
                      !(hotel.latitude == 0 && hotel.longitude == 0)) ...[
                    const SizedBox(height: 22),
                    AppSectionTitle(labels.location),
                    const SizedBox(height: 10),
                    AppPlaceMap(
                      latitude: hotel.latitude!,
                      longitude: hotel.longitude!,
                      address: hotel.address,
                      addressIcon: Icons.hotel_rounded,
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ).animate().fade(duration: 250.ms),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: context.uiSurface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: AppButton.label(
              key: const ValueKey('hotel-book-now'),
              text: soldOut ? labels.soldOut : labels.bookNow,
              onPressed: soldOut || !priced ? null : () => _book(hotel),
            ),
          ),
        ),
      ),
    );
  }

  String _offerName(Map<String, dynamic> offer, String fallback) {
    final roomName = offer['room_name']?.toString().trim() ?? '';
    final rateName = offer['name']?.toString().trim() ?? '';
    final label =
        [roomName, rateName].where((value) => value.isNotEmpty).join(' · ');
    return label.isEmpty ? fallback : label;
  }

  /// Offer total in the user's currency (converted from the offer's).
  String _offerPrice(Map<String, dynamic> offer, String fallbackCurrency) {
    final amount = double.tryParse(
      '${offer['total_amount'] ?? offer['stay_total'] ?? ''}',
    );
    if (amount == null || !amount.isFinite) return '—';
    final currency = (offer['total_currency'] ??
            offer['price_currency'] ??
            offer['currency'] ??
            fallbackCurrency)
        .toString()
        .toUpperCase();
    return formatPrice(context, amount, from: currency);
  }

  Widget _hotelReviewsSection(HotelModel hotel) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: AppSectionTitle(l10n.hotelGuestReviews)),
            AppButton.icon(
              onPressed: () => _writeHotelReview(hotel),
              icon: const Icon(Icons.star_rate_rounded),
              label: Text(l10n.writeAReview),
              variant: AppButtonVariant.text,
            ),
          ],
        ),
        const SizedBox(height: 4),
        FutureBuilder<ApiResult<List<ReviewModel>>>(
          future: _hotelReviewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final result = snapshot.data;
            if (snapshot.hasError || result == null || result.isFailure) {
              return Text(l10n.genericError,
                  style: TextStyle(color: context.uiMuted));
            }
            final reviews = result.data ?? const <ReviewModel>[];
            if (reviews.isEmpty) {
              return Text(l10n.hotelNoGuestReviews,
                  style: TextStyle(color: context.uiMuted));
            }
            return Column(
              children: [
                for (final review in reviews.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              review.userName.isEmpty
                                  ? '?'
                                  : review.userName
                                      .substring(0, 1)
                                      .toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        review.userName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: context.uiInk,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.star_rounded,
                                        color: AppColors.accentYellow,
                                        size: 16),
                                    Text(review.rating.toStringAsFixed(1)),
                                  ],
                                ),
                                if (review.comment.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      review.comment,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.uiMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OfferRow extends StatelessWidget {
  final String name;
  final String price;
  const _OfferRow({required this.name, required this.price});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.bed_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.uiInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
}
