import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../features/favorites/logic/favorites_controller.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/ui/ui.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/offer_stop.dart';
import '../../../../models/travel_package_model.dart';

/// Minutes from the first stop's start to the end of the last stop.
int offerDayMinutes(List<OfferStop> stops) {
  if (stops.isEmpty) return 0;
  final start = stops.first.startMinutes;
  final end = stops
      .map((s) => s.startMinutes + s.durationMinutes)
      .reduce((a, b) => a > b ? a : b);
  return (end - start).clamp(0, 24 * 60 * 2);
}

/// Straight-line km between consecutive stops that have a map location.
double offerDayDistanceKm(List<OfferStop> stops) {
  final points = [
    for (final s in stops)
      if (s.hasLocation) LatLng(s.latitude!, s.longitude!),
  ];
  var km = 0.0;
  for (var i = 1; i < points.length; i++) {
    km +=
        const Distance().as(LengthUnit.Meter, points[i - 1], points[i]) / 1000;
  }
  return km;
}

String _duration(AppLocalizations l10n, int minutes) => minutes < 60
    ? l10n.transferMinutes(minutes)
    : minutes % 60 == 0
        ? l10n.durationHours(minutes ~/ 60)
        : l10n.flightDurationShort(minutes ~/ 60, minutes % 60);

/// Offer with a day plan: "Your day in {city}", the stops of each day on a
/// timeline, the offer details, and the route of the day on a map.
class OfferDayPlanView extends StatefulWidget {
  final TravelPackage package;

  /// The offer's price/description/highlights ("Offer details" tab).
  final List<Widget> details;
  final bool booking;
  final VoidCallback? onBook;

  const OfferDayPlanView({
    super.key,
    required this.package,
    required this.details,
    required this.booking,
    required this.onBook,
  });

  @override
  State<OfferDayPlanView> createState() => _OfferDayPlanViewState();
}

class _OfferDayPlanViewState extends State<OfferDayPlanView> {
  bool _planTab = true;
  late final List<int> _days =
      widget.package.itinerary.map((s) => s.day).toSet().toList()..sort();
  late int _day = _days.first;

  List<OfferStop> get _stops =>
      widget.package.itinerary.where((s) => s.day == _day).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final package = widget.package;
    final lang = Localizations.localeOf(context).languageCode;
    final stops = _stops;
    final city = package.displayLocation(lang);
    return Scaffold(
      backgroundColor: context.uiPageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Text(
                      '$city, ${package.displayCountry(lang)}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.uiInk,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: FavoritesController.instance,
                    builder: (_, __) {
                      final fav =
                          FavoritesController.instance.isFavorite(package.id);
                      return AppIconButton(
                        icon: fav
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        tooltip: package.displayTitle(lang),
                        color: fav ? AppColors.primary : null,
                        onPressed: () => FavoritesController.instance.toggle(
                          FavoritePlace(
                            id: package.id,
                            title: package.displayTitle(lang),
                            subtitle: city,
                            type: 'destination',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  _Header(package: package, multiDay: _days.length > 1),
                  const SizedBox(height: 16),
                  AppChipRow(
                    children: [
                      AppChip(
                        key: const ValueKey('offer-tab-plan'),
                        label: l10n.offerTabPlan,
                        icon: Icons.route_rounded,
                        selected: _planTab,
                        onTap: () => setState(() => _planTab = true),
                      ),
                      AppChip(
                        key: const ValueKey('offer-tab-details'),
                        label: l10n.offerTabDetails,
                        icon: Icons.info_outline_rounded,
                        selected: !_planTab,
                        onTap: () => setState(() => _planTab = false),
                      ),
                    ],
                  ),
                  if (_planTab && _days.length > 1) ...[
                    const SizedBox(height: 10),
                    AppChipRow(
                      children: [
                        for (final d in _days)
                          AppChip(
                            label: l10n.offerDayN(d),
                            soft: true,
                            selected: d == _day,
                            onTap: () => setState(() => _day = d),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_planTab)
                    for (final (i, stop) in stops.indexed)
                      _TimelineStop(
                        stop: stop,
                        first: i == 0,
                        last: i == stops.length - 1,
                      )
                          .animate(delay: (60 * i).ms)
                          .fade(duration: 250.ms)
                          .slideY(begin: 0.06, end: 0)
                  else
                    ...widget.details,
                ],
              ),
            ),
            _BottomBar(
              package: package,
              stops: _planTab ? stops : null,
              booking: widget.booking,
              onBook: widget.onBook,
              onRoute: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OfferRouteScreen(
                    package: package,
                    day: _day,
                    multiDay: _days.length > 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TravelPackage package;
  final bool multiDay;
  const _Header({required this.package, required this.multiDay});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                multiDay ? l10n.offerYourTripIn : l10n.offerYourDayIn,
                style: TextStyle(fontSize: 16, color: context.uiInk),
              ),
              Text(
                package.displayLocation(lang),
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                package.displayTitle(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: context.uiMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 96,
            height: 84,
            child: AppNetworkImage(
              url: package.imageUrl,
              fallbackIcon: package.icon,
              fallbackGradient: package.gradient,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStop extends StatelessWidget {
  final OfferStop stop;
  final bool first;
  final bool last;

  const _TimelineStop({
    required this.stop,
    required this.first,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: stop.hour, minute: stop.minute),
    );
    final parts = time.split(' ');
    final category = stop.displayCategory(lang);
    final description = stop.displayDescription(lang);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                parts.join('\n'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: context.uiInk,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 36,
                  color: first ? AppColors.transparent : context.uiBorder,
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last ? AppColors.transparent : context.uiBorder,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: AppNetworkImage(
                        url: stop.imageUrl,
                        fallbackIcon: Icons.place_rounded,
                        fallbackGradient: AppColors.destinationGradients[0],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.displayName(lang),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: context.uiInk,
                          ),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: context.uiMuted),
                          ),
                        ],
                        const SizedBox(height: 4),
                        AppIconLabel(
                          icon: Icons.schedule_rounded,
                          text: _duration(l10n, stop.durationMinutes),
                          fontSize: 11.5,
                          color: context.uiMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final TravelPackage package;

  /// The day's stops on the plan tab (null on the details tab).
  final List<OfferStop>? stops;
  final bool booking;
  final VoidCallback? onBook;
  final VoidCallback onRoute;

  const _BottomBar({
    required this.package,
    required this.stops,
    required this.booking,
    required this.onBook,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stops = this.stops;
    Widget fact(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: context.uiMuted)),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.uiInk,
              ),
            ),
          ],
        );
    return Container(
      decoration: BoxDecoration(
        color: context.uiSurface,
        border: Border(top: BorderSide(color: context.uiBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stops != null && stops.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          children: [
                            fact(l10n.offerTotalTime,
                                '~${_duration(l10n, offerDayMinutes(stops))}'),
                            const SizedBox(width: 20),
                            fact(l10n.offerStops, '${stops.length}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      key: const ValueKey('offer-view-route'),
                      onPressed: onRoute,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.offerViewRoute),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                key: const ValueKey('offer-book'),
                loading: booking,
                onPressed: onBook,
                child: Text(l10n.offerBookFor(
                    formatPrice(context, package.totalPricePerPerson))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The day's stops on a map (numbered, joined in plan order) or as a list,
/// with a route summary and "Start navigation" (opens the maps app).
class OfferRouteScreen extends StatefulWidget {
  final TravelPackage package;
  final int day;
  final bool multiDay;

  /// Tests turn the map tiles off (no network).
  final bool showMapTiles;

  const OfferRouteScreen({
    super.key,
    required this.package,
    required this.day,
    this.multiDay = false,
    @visibleForTesting this.showMapTiles = true,
  });

  @override
  State<OfferRouteScreen> createState() => _OfferRouteScreenState();
}

class _OfferRouteScreenState extends State<OfferRouteScreen> {
  bool _map = true;

  List<OfferStop> get _stops =>
      widget.package.itinerary.where((s) => s.day == widget.day).toList();

  Future<void> _navigate(List<OfferStop> stops) async {
    final points = [
      for (final s in stops)
        if (s.hasLocation) '${s.latitude},${s.longitude}',
    ];
    if (points.isEmpty) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': points.last,
      if (points.length > 1) 'origin': points.first,
      if (points.length > 2)
        'waypoints': points.sublist(1, points.length - 1).join('|'),
      'travelmode': 'driving',
    });
    final opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication).catchError(
      (_) => false,
    );
    if (!opened && mounted) {
      AppSnackbar.error(
          context, AppLocalizations.of(context).offerNavigationFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final stops = _stops;
    final located = stops.where((s) => s.hasLocation).toList();
    final km = offerDayDistanceKm(stops);
    return Scaffold(
      backgroundColor: context.uiPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.multiDay
                          ? '${l10n.offerRouteTitle} · ${l10n.offerDayN(widget.day)}'
                          : l10n.offerRouteTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: context.uiInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(l10n.offerMapView)),
                  ButtonSegment(value: false, label: Text(l10n.offerListView)),
                ],
                selected: {_map},
                onSelectionChanged: (v) => setState(() => _map = v.first),
              ),
            ),
            Expanded(
              child: _map
                  ? (located.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(l10n.offerNoMapStops,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.uiMuted)),
                          ),
                        )
                      : _RouteMap(
                          stops: stops,
                          showTiles: widget.showMapTiles,
                        ))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final (i, stop) in stops.indexed)
                          AppCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                _NumberDot(i + 1),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stop.displayName(lang),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: context.uiInk,
                                        ),
                                      ),
                                      Text(
                                        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: stop.hour, minute: stop.minute))}'
                                        ' · ${_duration(l10n, stop.durationMinutes)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: context.uiMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: AppCard(
                radius: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.offerRouteSummary,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: context.uiInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryFact(
                            icon: Icons.place_outlined,
                            value: '${stops.length}',
                            label: l10n.offerStops,
                          ),
                        ),
                        Expanded(
                          child: _SummaryFact(
                            icon: Icons.schedule_rounded,
                            value:
                                '~${_duration(l10n, offerDayMinutes(stops))}',
                            label: l10n.offerTotalTime,
                          ),
                        ),
                        Expanded(
                          child: _SummaryFact(
                            icon: Icons.straighten_rounded,
                            value: l10n.taxiDistanceKm(km.toStringAsFixed(1)),
                            label: l10n.offerDistance,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppIconLabel(
                      icon: Icons.info_outline_rounded,
                      text: l10n.offerRouteNote,
                      fontSize: 11.5,
                      color: context.uiMuted,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      key: const ValueKey('offer-start-navigation'),
                      onPressed:
                          located.isEmpty ? null : () => _navigate(stops),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.offerStartNavigation),
                          const SizedBox(width: 8),
                          const Icon(Icons.navigation_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryFact extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SummaryFact(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: context.uiInk,
                    )),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: context.uiMuted)),
              ],
            ),
          ),
        ],
      );
}

class _NumberDot extends StatelessWidget {
  final int number;
  const _NumberDot(this.number);

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          '$number',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _RouteMap extends StatelessWidget {
  final List<OfferStop> stops;
  final bool showTiles;
  const _RouteMap({required this.stops, required this.showTiles});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final numbered = [
      for (final (i, s) in stops.indexed)
        if (s.hasLocation) (i + 1, s, LatLng(s.latitude!, s.longitude!)),
    ];
    final points = [for (final n in numbered) n.$3];
    return FlutterMap(
      options: MapOptions(
        initialCenter: points.first,
        initialZoom: 13,
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(
                coordinates: points,
                // Room on the right for the name labels beside each pin.
                padding: const EdgeInsets.fromLTRB(40, 50, 150, 50),
                maxZoom: 16,
              )
            : null,
      ),
      children: [
        if (showTiles)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.zentrip.app',
          ),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: AppColors.primary,
                borderStrokeWidth: 2,
                borderColor: AppColors.white,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final (n, stop, point) in numbered)
              Marker(
                point: point,
                width: 150,
                height: 30,
                // The dot (26 px, at the left of the 150 px row) must be
                // centered on the point: shift the row so its first 13 px sit
                // left of the point. The row is always left-to-right (label
                // after the dot) so this holds in Arabic too.
                alignment: const Alignment(1 - 26 / 150, 0),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      _NumberDot(n),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.uiSurface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            stop.displayName(lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: context.uiInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
