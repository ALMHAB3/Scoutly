import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../global_widgets/currency_amount_text.dart';
import '../../../../global_widgets/ui/ui.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/transfer_model.dart';

/// Where a booked taxi ride stands, worked out from its pickup time only
/// (there is no live driver location).
enum TaxiRidePhase { scheduled, soon, onRide, finished }

/// "Soon" starts one hour before pickup.
const taxiSoonWindow = Duration(hours: 1);

TaxiRidePhase taxiRidePhase(TransferModel ride, DateTime now) {
  final pickup = ride.pickupTime;
  final end = pickup.add(
      Duration(minutes: ride.durationMinutes > 0 ? ride.durationMinutes : 60));
  if (now.isBefore(pickup.subtract(taxiSoonWindow))) {
    return TaxiRidePhase.scheduled;
  }
  if (now.isBefore(pickup)) return TaxiRidePhase.soon;
  if (now.isBefore(end)) return TaxiRidePhase.onRide;
  return TaxiRidePhase.finished;
}

/// Ride status message ("Ride scheduled", "Pickup soon", ...) with a
/// countdown to pickup, the driver/company and the car. No live tracking,
/// no call: only what the booking really holds.
class TaxiRideStatusCard extends StatefulWidget {
  final TransferModel ride;

  /// Fixed clock for tests; defaults to the current time (refreshed every
  /// 30 seconds).
  final DateTime Function()? clock;

  const TaxiRideStatusCard({super.key, required this.ride, this.clock});

  @override
  State<TaxiRideStatusCard> createState() => _TaxiRideStatusCardState();
}

class _TaxiRideStatusCardState extends State<TaxiRideStatusCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.clock == null) {
      _timer = Timer.periodic(
          const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ride = widget.ride;
    final now = (widget.clock ?? DateTime.now)();
    final phase = taxiRidePhase(ride, now);
    final material = MaterialLocalizations.of(context);
    final time =
        material.formatTimeOfDay(TimeOfDay.fromDateTime(ride.pickupTime));
    final who = ride.driverName ?? ride.partnerName ?? ride.providerName;
    final car =
        ride.vehicleName.isNotEmpty ? ride.vehicleName : ride.vehicleType;
    final left = ride.pickupTime.difference(now);

    final (title, subtitle) = switch (phase) {
      TaxiRidePhase.scheduled => (
          l10n.taxiStatusScheduled,
          l10n.taxiStatusScheduledSub(who, ride.pickupLocation),
        ),
      TaxiRidePhase.soon => (
          l10n.taxiStatusSoon,
          l10n.taxiStatusSoonSub(who, time),
        ),
      TaxiRidePhase.onRide => (
          l10n.taxiStatusOnRide,
          l10n.taxiStatusOnRideSub(ride.dropoffLocation),
        ),
      TaxiRidePhase.finished => (
          l10n.taxiStatusFinished,
          l10n.taxiStatusFinishedSub(who),
        ),
    };

    // Countdown badge: days / hours / minutes until pickup.
    final (String? value, String unit, IconData? icon) = switch (phase) {
      TaxiRidePhase.onRide => (null, '', Icons.local_taxi_rounded),
      TaxiRidePhase.finished => (null, '', Icons.check_rounded),
      _ when left.inDays >= 1 => ('${left.inDays}', l10n.taxiUnitDays, null),
      _ when left.inHours >= 1 => ('${left.inHours}', l10n.taxiUnitHours, null),
      _ => (
          '${left.inMinutes.clamp(1, 59)}',
          l10n.taxiUnitMinutes,
          null,
        ),
    };

    // Bar: fills during the last hour before pickup, then during the ride.
    final progress = switch (phase) {
      TaxiRidePhase.scheduled => 0.04,
      TaxiRidePhase.soon => 1 - left.inSeconds / taxiSoonWindow.inSeconds,
      TaxiRidePhase.onRide => now.difference(ride.pickupTime).inSeconds /
          (ride.durationMinutes > 0 ? ride.durationMinutes * 60 : 3600),
      TaxiRidePhase.finished => 1.0,
    }
        .clamp(0.04, 1.0)
        .toDouble();

    return AppCard(
      key: const ValueKey('taxi-ride-status'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.uiInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: context.uiMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minWidth: 52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: icon != null
                    ? Icon(icon, color: AppColors.white, size: 24)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            value!,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            unit,
                            style: const TextStyle(
                              color: AppColors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressTrack(progress: progress),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  _initials(who),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: context.uiInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (ride.driverRating != null) ...[
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.amber),
                          Text(
                            ' ${ride.driverRating!.toStringAsFixed(1)} · ',
                            style:
                                TextStyle(fontSize: 12, color: context.uiMuted),
                          ),
                        ],
                        Flexible(
                          child: Text(
                            car,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12, color: context.uiMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 84,
                  height: 50,
                  child: AppNetworkImage(
                    url: ride.vehicleImageUrl,
                    fallbackIcon: Icons.local_taxi_rounded,
                    fallbackGradient: AppColors.destinationGradients[0],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppIconLabel(
                  icon: Icons.schedule_rounded,
                  text: l10n.taxiPickupAt(
                    material.formatShortMonthDay(ride.pickupTime),
                    time,
                  ),
                  color: context.uiMuted,
                ),
              ),
              CurrencyAmountText(
                amount: ride.priceUSD,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: context.uiInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final double progress;
  const _ProgressTrack({required this.progress});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const dot = 22.0;
          final width = constraints.maxWidth;
          final x = (width - dot) * progress;
          return SizedBox(
            height: dot,
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.uiBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: x + dot / 2,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                PositionedDirectional(
                  start: x,
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const Icon(Icons.local_taxi_rounded,
                        size: 12, color: AppColors.white),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}
