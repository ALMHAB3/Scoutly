import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/hotel_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../car_rental/presentation/widgets/car_widgets.dart';
import '../../logic/hotel_controller.dart';
import '../hotel_labels.dart';
import '../widgets/hotel_widgets.dart';

/// Hotels found for the search: price range chips, sort chips and large
/// photo cards (same design as the car rental list). Prices follow the
/// profile currency.
class HotelResultsScreen extends StatefulWidget {
  const HotelResultsScreen({super.key});

  @override
  State<HotelResultsScreen> createState() => _HotelResultsScreenState();
}

class _HotelResultsScreenState extends State<HotelResultsScreen> {
  HotelController? _ctrl;
  String? _lastWarningMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= ModalRoute.of(context)?.settings.arguments as HotelController?;
  }

  void _showSearchWarnings(List<String> warnings) {
    final message = warnings.join(' ').trim();
    if (message.isEmpty) {
      _lastWarningMessage = null;
      return;
    }
    if (message == _lastWarningMessage) return;
    _lastWarningMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppSnackbar.warning(context, message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = HotelLabels(l10n);
    final ctrl = _ctrl;
    if (ctrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _showSearchWarnings(
      ctrl.searchWarnings.isNotEmpty
          ? ctrl.searchWarnings
          : ctrl.hasSearchError
              ? [l10n.genericError]
              : const [],
    );
    return Scaffold(
      backgroundColor: carPageBackground(context),
      appBar: AppBar(
        backgroundColor: carPageBackground(context),
        surfaceTintColor: AppColors.transparent,
        centerTitle: true,
        title: ListenableBuilder(
          listenable: ctrl,
          builder: (_, __) {
            final params = ctrl.searchParams;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels.resultsTitle(params?.city ?? ''),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: carInk(context),
                  ),
                ),
                if (params != null)
                  Text(
                    '${labels.dayMonth(params.checkIn)} – '
                    '${labels.dayMonth(params.checkOut)} · '
                    '${labels.stay(params.nights.clamp(1, 99), params.rooms, params.guests)}',
                    style: TextStyle(fontSize: 11, color: carMuted(context)),
                  ),
              ],
            );
          },
        ),
      ),
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChipsRow(
                      children: [
                        for (final f in HotelFilter.values)
                          _Chip(
                            label: labels.filter(f),
                            selected: ctrl.filter == f,
                            onTap: () => ctrl.setFilter(f),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ChipsRow(
                      children: [
                        Icon(Icons.sort_rounded,
                            size: 18, color: carMuted(context)),
                        const SizedBox(width: 6),
                        for (final s in HotelSort.values)
                          _Chip(
                            label: labels.sort(s),
                            selected: ctrl.sort == s,
                            small: true,
                            onTap: () => ctrl.setSort(s),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (ctrl.isLoading)
              const SliverPadding(
                padding: EdgeInsets.only(top: 40),
                sliver: SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (ctrl.results.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                  child: Column(
                    children: [
                      Icon(
                        ctrl.hasSearchError
                            ? Icons.cloud_off_rounded
                            : Icons.hotel_rounded,
                        size: 48,
                        color: carMuted(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ctrl.hasSearchError
                            ? labels.searchUnavailable
                            : labels.noResults,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: carMuted(context)),
                      ),
                      if (ctrl.searchParams != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 220,
                          child: CarCtaButton(
                            label: labels.tryAgain,
                            onPressed: () => ctrl.search(ctrl.searchParams!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.builder(
                  itemCount: ctrl.results.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _HotelCard(
                      hotel: ctrl.results[i],
                      rooms: ctrl.searchParams?.rooms ?? 1,
                      labels: labels,
                      onTap: () {
                        ctrl.selectHotel(ctrl.results[i]);
                        Navigator.pushNamed(context, AppRoutes.hotelDetail,
                            arguments: ctrl);
                      },
                    )
                        .animate(delay: Duration(milliseconds: 60 * (i % 6)))
                        .fade()
                        .slideY(begin: 0.04, end: 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final List<Widget> children;
  const _ChipsRow({required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool small;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                  horizontal: small ? 12 : 16, vertical: small ? 7 : 9),
              decoration: BoxDecoration(
                color: selected
                    ? (small
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : AppColors.primary)
                    : carSurface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : carBorder(context),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? (small ? AppColors.primary : AppColors.white)
                      : carInk(context),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: small ? 12 : 13,
                ),
              ),
            ),
          ),
        ),
      );
}

class _HotelCard extends StatelessWidget {
  final HotelModel hotel;
  final int rooms;
  final HotelLabels labels;
  final VoidCallback onTap;

  const _HotelCard({
    required this.hotel,
    required this.rooms,
    required this.labels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final soldOut = hotel.availabilityKnown && hotel.availableRooms < rooms;
    final partner = hotel.partnerName?.trim() ?? '';
    return Semantics(
      button: true,
      label: '${hotel.name}, ${hotelNightlyText(context, hotel, labels)} '
          '${labels.perNight}'
          '${partner.isEmpty ? '' : ', ${labels.providedBy(partner)}'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CarCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  HotelPhoto(
                    hotel: hotel,
                    height: 170,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  PositionedDirectional(
                    top: 12,
                    end: 12,
                    child: CarRatingBadge(
                      rating: hotel.hasGoogleRating ? hotel.rating : 0,
                    ),
                  ),
                  if (hotel.distanceMeters != null)
                    PositionedDirectional(
                      top: 12,
                      start: 12,
                      child: PhotoPill(
                        icon: Icons.near_me_rounded,
                        text: labels.kmAway(hotel.distanceMeters!),
                      ),
                    )
                  else if (hotel.isFeatured)
                    PositionedDirectional(
                      top: 12,
                      start: 12,
                      child: PhotoPill(
                        icon: Icons.workspace_premium_rounded,
                        text: labels.featured,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hotel.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: carInk(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              HotelStars(stars: hotel.starRating),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        HotelNightlyPrice(
                          hotel: hotel,
                          labels: labels,
                          fontSize: 16,
                        ),
                      ],
                    ),
                    if (hotel.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 15, color: carMuted(context)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hotel.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: carMuted(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (hotel.amenities.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final amenity in hotel.amenities.take(3))
                            _AmenityChip(amenity),
                          if (hotel.amenities.length > 3)
                            _AmenityChip('+${hotel.amenities.length - 3}',
                                showIcon: false),
                        ],
                      ),
                    ],
                    if (soldOut) ...[
                      const SizedBox(height: 8),
                      Text(
                        labels.soldOut,
                        style: const TextStyle(
                          color: AppColors.accentRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (partner.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Divider(height: 1, color: carBorder(context)),
                      const SizedBox(height: 10),
                      HotelProviderLine(hotel: hotel, labels: labels),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final String text;
  final bool showIcon;
  const _AmenityChip(this.text, {this.showIcon = true});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(hotelAmenityIcon(text), size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
}
