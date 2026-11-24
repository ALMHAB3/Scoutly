import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../global_widgets/ui/ui.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/flight_model.dart';
import '../../../../models/offer_stop.dart';
import 'car_pickup_point_picker.dart';

/// "Day plan" section of the admin offer form: the stops customers see on
/// the offer, grouped by day, with add / edit / delete.
class AdminOfferStopsEditor extends StatelessWidget {
  final List<OfferStop> stops;

  /// Last day of the trip (nights + 1).
  final int maxDay;

  /// City of the offer, used to center the map for a new stop.
  final String city;
  final ValueChanged<List<OfferStop>> onChanged;

  const AdminOfferStopsEditor({
    super.key,
    required this.stops,
    required this.maxDay,
    required this.city,
    required this.onChanged,
  });

  Future<void> _edit(BuildContext context, {int? index}) async {
    final stop = await showDialog<OfferStop>(
      context: context,
      builder: (_) => _StopDialog(
        stop: index == null ? null : stops[index],
        maxDay: maxDay,
        city: city,
        defaultDay: stops.isEmpty ? 1 : stops.last.day,
      ),
    );
    if (stop == null) return;
    final next = List<OfferStop>.of(stops);
    if (index == null) {
      next.add(stop);
    } else {
      next[index] = stop;
    }
    onChanged(OfferStop.sorted(next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.adminDayPlan,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(l10n.adminDayPlanHint,
                      style: TextStyle(fontSize: 12, color: context.uiMuted)),
                ],
              ),
            ),
            AppButton.icon(
              key: const ValueKey('admin-add-stop'),
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l10n.adminAddStop),
              variant: AppButtonVariant.secondary,
              expand: false,
              height: 42,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (stops.isEmpty)
          Text(l10n.adminNoStops,
              style: TextStyle(fontSize: 12.5, color: context.uiMuted))
        else
          for (final (i, stop) in stops.indexed) ...[
            if (i == 0 || stops[i - 1].day != stop.day)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Text(
                  l10n.offerDayN(stop.day),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            AppCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              shadow: false,
              onTap: () => _edit(context, index: i),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: AppNetworkImage(
                        url: stop.imageUrl,
                        fallbackIcon: Icons.place_outlined,
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
                          '${stop.time} · ${stop.displayName(lang)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.uiInk,
                          ),
                        ),
                        Text(
                          [
                            if (stop.displayCategory(lang).isNotEmpty)
                              stop.displayCategory(lang),
                            '${stop.durationMinutes} min',
                            if (!stop.hasLocation) '⚠︎',
                          ].join(' · '),
                          style:
                              TextStyle(fontSize: 12, color: context.uiMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).deleteButtonTooltip,
                    onPressed: () =>
                        onChanged(List<OfferStop>.of(stops)..removeAt(i)),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.accentRed),
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}

class _StopDialog extends StatefulWidget {
  final OfferStop? stop;
  final int maxDay;
  final String city;
  final int defaultDay;

  const _StopDialog({
    required this.stop,
    required this.maxDay,
    required this.city,
    required this.defaultDay,
  });

  @override
  State<_StopDialog> createState() => _StopDialogState();
}

class _StopDialogState extends State<_StopDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.stop?.name ?? '');
  late final _nameAr = TextEditingController(text: widget.stop?.nameAr ?? '');
  late final _category =
      TextEditingController(text: widget.stop?.category ?? '');
  late final _categoryAr =
      TextEditingController(text: widget.stop?.categoryAr ?? '');
  late final _description =
      TextEditingController(text: widget.stop?.description ?? '');
  late final _descriptionAr =
      TextEditingController(text: widget.stop?.descriptionAr ?? '');
  late final _duration =
      TextEditingController(text: '${widget.stop?.durationMinutes ?? 60}');
  late final _photo = TextEditingController(text: widget.stop?.imageUrl ?? '');
  late int _day =
      (widget.stop?.day ?? widget.defaultDay).clamp(1, widget.maxDay).toInt();
  late TimeOfDay _time = widget.stop == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay(hour: widget.stop!.hour, minute: widget.stop!.minute);
  late LatLng? _point = widget.stop?.hasLocation == true
      ? LatLng(widget.stop!.latitude!, widget.stop!.longitude!)
      : null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _nameAr,
      _category,
      _categoryAr,
      _description,
      _descriptionAr,
      _duration,
      _photo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPoint() async {
    final l10n = AppLocalizations.of(context);
    final c = AirportOption.byCity(widget.city)?.coordinates;
    final point = await CarPickupPointPicker.open(
      context,
      initial: _point ??
          (c == null ? const LatLng(32.8872, 13.1913) : LatLng(c.$1, c.$2)),
      hasInitialPin: _point != null,
      title: l10n.adminStopMapTitle,
      hint: l10n.adminStopMapHint,
    );
    if (point != null && mounted) setState(() => _point = point);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    String two(int v) => v.toString().padLeft(2, '0');
    Navigator.pop(
      context,
      OfferStop(
        day: _day,
        time: '${two(_time.hour)}:${two(_time.minute)}',
        name: _name.text.trim(),
        nameAr: _nameAr.text.trim(),
        category: _category.text.trim(),
        categoryAr: _categoryAr.text.trim(),
        description: _description.text.trim(),
        descriptionAr: _descriptionAr.text.trim(),
        durationMinutes: int.parse(_duration.text.trim()),
        imageUrl: _photo.text.trim(),
        latitude: _point?.latitude,
        longitude: _point?.longitude,
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    TextDirection? direction,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          maxLines: lines,
          keyboardType: keyboard,
          textDirection: direction,
          decoration: InputDecoration(labelText: label),
          validator: validator ??
              (required
                  ? (v) => v == null || v.trim().isEmpty
                      ? AppLocalizations.of(context).partnerRequiredField
                      : null
                  : null),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.stop == null ? l10n.adminAddStop : l10n.adminEditStop),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey('admin-stop-day'),
                        initialValue: _day,
                        decoration: const InputDecoration(),
                        items: [
                          for (var d = 1; d <= widget.maxDay; d++)
                            DropdownMenuItem(
                                value: d, child: Text(l10n.offerDayN(d))),
                        ],
                        onChanged: (d) => setState(() => _day = d ?? _day),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Tooltip(
                        message: l10n.adminStopTime,
                        child: OutlinedButton.icon(
                          key: const ValueKey('admin-stop-time'),
                          onPressed: () async {
                            final t = await showTimePicker(
                                context: context, initialTime: _time);
                            if (t != null) setState(() => _time = t);
                          },
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(_time.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _text(_name, l10n.adminStopName, required: true),
                _text(_nameAr, l10n.adminStopNameAr,
                    direction: TextDirection.rtl),
                _text(_category, l10n.adminStopCategory),
                _text(_categoryAr, l10n.adminStopCategoryAr,
                    direction: TextDirection.rtl),
                _text(_description, l10n.adminStopDescription, lines: 2),
                _text(_descriptionAr, l10n.adminStopDescriptionAr,
                    lines: 2, direction: TextDirection.rtl),
                _text(
                  _duration,
                  l10n.adminStopDuration,
                  keyboard: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return n == null || n < 5 || n > 1440
                        ? l10n.partnerInvalidServiceField
                        : null;
                  },
                ),
                _text(
                  _photo,
                  l10n.adminStopPhotoUrl,
                  keyboard: TextInputType.url,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    return t.isEmpty ||
                            RegExp(r'^https?://\S+$', caseSensitive: false)
                                .hasMatch(t)
                        ? null
                        : l10n.partnerInvalidServiceField;
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _point == null
                            ? l10n.adminStopNoLocation
                            : '${_point!.latitude.toStringAsFixed(5)}, '
                                '${_point!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _point == null
                              ? AppColors.accentOrange
                              : context.uiMuted,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('admin-stop-map'),
                      onPressed: _pickPoint,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(l10n.adminStopChooseOnMap),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        AppButton(
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.partnerCancel),
        ),
        AppButton(
          key: const ValueKey('admin-stop-save'),
          onPressed: _save,
          expand: false,
          child: Text(l10n.partnerSave),
        ),
      ],
    );
  }
}
