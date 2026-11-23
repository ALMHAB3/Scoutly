import '../../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/money_format.dart';
import '../../../../global_widgets/currency_amount_text.dart';
import '../../../../models/flight_model.dart';
import '../../../../models/flight_seat_map.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/ui/ui.dart';

class FlightCabinSelector extends StatelessWidget {
  final FlightSeatCabin cabin;
  final List<FlightSeatCabin> cabins;
  final String selectedCabinId;
  final bool enabled;
  final ValueChanged<FlightSeatCabin> onCabinSelected;

  const FlightCabinSelector({
    super.key,
    required this.cabin,
    required this.cabins,
    required this.selectedCabinId,
    required this.enabled,
    required this.onCabinSelected,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final maxPillWidth =
              (constraints.maxWidth * .58).clamp(124.0, 248.0).toDouble();
          final pillViewportWidth =
              (cabins.length * 54.0 - 8).clamp(0.0, maxPillWidth).toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cabin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.seatInk,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '${cabin.availableSeats}/${cabin.totalSeats} available',
                      style: const TextStyle(
                          color: AppColors.seatMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: pillViewportWidth,
                height: 48,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < cabins.length; index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        _CabinPill(
                          number: '${index + 1}',
                          selected: cabins[index].id == selectedCabinId,
                          enabled: enabled,
                          onTap: () => onCabinSelected(cabins[index]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _CabinPill extends StatelessWidget {
  final String number;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _CabinPill({
    required this.number,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: AppLocalizations.of(context).cabinNumber(number),
        child: Material(
          color: selected ? AppColors.seatNavy : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: Text(number,
                    style: TextStyle(
                        color: selected ? AppColors.white : AppColors.seatInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      );
}

class FlightSeatLegend extends StatelessWidget {
  const FlightSeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 15,
      runSpacing: 9,
      children: [
        _LegendItem(
            color: AppColors.seatAvailable,
            label: isArabic ? 'متاح' : 'Available'),
        _LegendItem(
            color: AppColors.white,
            border: AppColors.seatNavy,
            label: isArabic ? 'مساحة إضافية للأرجل' : 'Extra legroom'),
        _LegendItem(
            color: AppColors.seatNavy, label: isArabic ? 'مقعدك' : 'Your seat'),
        _LegendItem(
            color: AppColors.seatTaken, label: isArabic ? 'محجوز' : 'Taken'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? border;
  final String label;

  const _LegendItem({required this.color, this.border, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: border ?? color, width: border == null ? 0 : 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.seatMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class FlightExtrasPanel extends StatelessWidget {
  final Map<String, double> extras;
  final Set<String> selectedExtras;
  final bool enabled;
  final void Function(String key, bool selected) onChanged;

  const FlightExtrasPanel({
    super.key,
    required this.extras,
    required this.selectedExtras,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.seatLine),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        iconColor: AppColors.seatNavy,
        title: Text(AppLocalizations.of(context).optionalExtras,
            style: const TextStyle(
                color: AppColors.seatInk, fontWeight: FontWeight.w800)),
        subtitle: Text(AppLocalizations.of(context).optionalExtrasSubtitle,
            style: const TextStyle(color: AppColors.seatMuted, fontSize: 12)),
        children: [
          for (final entry in extras.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.seatNavy,
              value: selectedExtras.contains(entry.key),
              title: Text(_extraLabel(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: CurrencyAmountText(
                amount: entry.value,
                decimalDigits: 2,
                style: DefaultTextStyle.of(context).style,
              ),
              onChanged: enabled
                  ? (value) => onChanged(entry.key, value == true)
                  : null,
            ),
        ],
      ),
    );
  }

  String _extraLabel(String key) => key
      .split(RegExp(r'[_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class FlightSeatMapSkeleton extends StatelessWidget {
  const FlightSeatMapSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 235,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: SizedBox(
            width: 210,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkeletonLine(width: 140, height: 13),
                SizedBox(height: 23),
                _SkeletonLine(width: 190, height: 92),
              ],
            ),
          ),
        ),
      );
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.seatPlaceholder,
          borderRadius: BorderRadius.circular(10),
        ),
      );
}

class FlightSeatErrorPanel extends StatelessWidget {
  final String message;
  final bool retrying;
  final VoidCallback? onRetry;

  const FlightSeatErrorPanel({
    super.key,
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.seatLine),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_seat_outlined,
                color: AppColors.seatMuted, size: 27),
            const SizedBox(height: 9),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.seatInk, fontWeight: FontWeight.w600)),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              AppButton.icon(
                onPressed: retrying ? null : onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context).retryShort),
                variant: AppButtonVariant.text,
              ),
            ],
          ],
        ),
      );
}
