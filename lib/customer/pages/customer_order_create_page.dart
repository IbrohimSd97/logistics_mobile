import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/brand/alix_components.dart';
import '../../core/api/cargo_types_api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/location/yandex_route.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/location_picker_page.dart';
import '../../core/widgets/refresh_icon_button.dart';
import '../customer_api.dart';
import 'customer_payment_select_page.dart';

/// `POST /api/customer/orders/create`
///
/// `prefill*` parametrlari yakunlangan buyurtmadan "Takrorlash" tugmasi bosilganda
/// uzatiladi — form maydonlari oldindan to'ldiriladi (cargo type tariflar yuklangach
/// id bo'yicha tanlanadi).
class CustomerOrderCreatePage extends StatefulWidget {
  const CustomerOrderCreatePage({
    super.key,
    this.prefillCargoTypeId,
    this.prefillPickupAddress,
    this.prefillPickupLat,
    this.prefillPickupLng,
    this.prefillDeliveryAddress,
    this.prefillDeliveryLat,
    this.prefillDeliveryLng,
    this.prefillCargoWeightKg,
    this.prefillComment,
  });

  final int? prefillCargoTypeId;
  final String? prefillPickupAddress;
  final double? prefillPickupLat;
  final double? prefillPickupLng;
  final String? prefillDeliveryAddress;
  final double? prefillDeliveryLat;
  final double? prefillDeliveryLng;
  final int? prefillCargoWeightKg;
  final String? prefillComment;

  @override
  State<CustomerOrderCreatePage> createState() => _CustomerOrderCreatePageState();
}

class _CustomerOrderCreatePageState extends State<CustomerOrderCreatePage>
    with I18nObserverMixin<CustomerOrderCreatePage> {
  final _pickupAddr = TextEditingController();
  final _deliveryAddr = TextEditingController();
  final _weight = TextEditingController(text: '1');
  final _comment = TextEditingController();
  LatLng? _pickup;
  LatLng? _delivery;

  List<CargoType> _cargoTypes = [];
  CargoType? _selected;
  bool _loadingTariffs = true;
  String? _tariffError;
  bool _submitting = false;

  /// Rejali buyurtma — agar yoqilgan bo'lsa `_scheduledAt` orqali
  /// olib ketish vaqti tanlanadi. Bo'sh bo'lsa buyurtma zudlik bilan
  /// (radius bo'yicha haydovchilarga ko'rinadi).
  bool _scheduledMode = false;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    // Takrorlash uchun prefill — sana/rejali rejimga tegmaymiz, yangi buyurtma
    // doim zudlik bilan boshlanadi (default). Foydalanuvchi rejalashtirishni
    // qo'lda yoqishi mumkin.
    if (widget.prefillPickupAddress != null) {
      _pickupAddr.text = widget.prefillPickupAddress!;
    }
    if (widget.prefillDeliveryAddress != null) {
      _deliveryAddr.text = widget.prefillDeliveryAddress!;
    }
    if (widget.prefillPickupLat != null && widget.prefillPickupLng != null) {
      _pickup = LatLng(widget.prefillPickupLat!, widget.prefillPickupLng!);
    }
    if (widget.prefillDeliveryLat != null && widget.prefillDeliveryLng != null) {
      _delivery = LatLng(widget.prefillDeliveryLat!, widget.prefillDeliveryLng!);
    }
    if (widget.prefillCargoWeightKg != null) {
      _weight.text = widget.prefillCargoWeightKg!.toString();
    }
    if (widget.prefillComment != null && widget.prefillComment!.isNotEmpty) {
      _comment.text = widget.prefillComment!;
    }
    _loadTariffs();
  }

  @override
  void dispose() {
    _pickupAddr.dispose();
    _deliveryAddr.dispose();
    _weight.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickFromMap({required bool isPickup}) async {
    final initialLat = isPickup ? _pickup : _delivery;
    final initialAddr = isPickup ? _pickupAddr.text : _deliveryAddr.text;
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute<LocationPickerResult>(
        builder: (_) => LocationPickerPage(
          title: isPickup ? I18n.t('order.create.pickup_picker_title') : I18n.t('order.create.delivery_picker_title'),
          initialLatLng: initialLat,
          initialAddress: initialAddr.isEmpty ? null : initialAddr,
          // A nuqta (pickup) — ochilishi bilan joriy joylashuvga o'tadi.
          useCurrentLocation: isPickup,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isPickup) {
        _pickup = result.latLng;
        _pickupAddr.text = result.address;
      } else {
        _delivery = result.latLng;
        _deliveryAddr.text = result.address;
      }
    });
  }

  Future<void> _loadTariffs() async {
    setState(() {
      _loadingTariffs = true;
      _tariffError = null;
    });
    try {
      final list = await const CargoTypesApi().list();
      if (!mounted) return;
      // Prefill cargoType — agar ko'rsatilgan bo'lsa shu id'ni topib tanlaymiz,
      // bo'lmasa default sifatida birinchisini.
      CargoType? prefilled;
      if (widget.prefillCargoTypeId != null) {
        for (final t in list) {
          if (t.id == widget.prefillCargoTypeId) {
            prefilled = t;
            break;
          }
        }
      }
      setState(() {
        _cargoTypes = list;
        _selected = prefilled ?? (list.isNotEmpty ? list.first : null);
        _loadingTariffs = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTariffs = false;
        _tariffError = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTariffs = false;
        _tariffError = '$e';
      });
    }
  }

  Future<void> _pickScheduledDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(hours: 2));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: I18n.t('order.create.pickup_date_help'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: I18n.t('order.create.pickup_time_help'),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _scheduledAt = picked);
  }

  Future<void> _submit() async {
    final pickup = _pickupAddr.text.trim();
    final delivery = _deliveryAddr.text.trim();
    // Faqat LatLng tekshiramiz — manzil matni map'dan kelmasligi ham mumkin
    // (geocoding null qaytarsa "lat,lng" formatda fallback ko'rsatiladi).
    if (_pickup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('order.create.pickup_required'))),
      );
      return;
    }
    if (_delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('order.create.delivery_required'))),
      );
      return;
    }
    // LocationPickerPage endi address majburlaydi — bo'sh bo'lmaydi.
    // Lekin xavfsizlik uchun yana tekshiramiz.
    if (pickup.isEmpty || delivery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('order.create.address_required'))),
      );
      return;
    }
    final pickupAddr = pickup;
    final deliveryAddr = delivery;
    // Bir xil koordinata bo'lsa rad qilamiz (5 mga aniq).
    if (_pickup!.latitude.toStringAsFixed(5) == _delivery!.latitude.toStringAsFixed(5) &&
        _pickup!.longitude.toStringAsFixed(5) == _delivery!.longitude.toStringAsFixed(5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('order.create.same_address'))),
      );
      return;
    }
    if (_selected == null) {
      if (_loadingTariffs) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('tariff.loading'))));
      } else if (_tariffError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('tariff.load_failed'))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('tariff.not_found'))));
      }
      return;
    }
    final w = int.tryParse(_weight.text.trim());
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('order.create.weight_required'))));
      return;
    }
    if (w > 20000) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(I18n.t('order.create.weight_too_big'))));
      return;
    }
    // Rejali rejim: vaqt tanlangan bo'lishi kerak va kelajakda (min +5 daq).
    if (_scheduledMode) {
      if (_scheduledAt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('order.create.scheduled_time_required'))),
        );
        return;
      }
      final minAllowed = DateTime.now().add(const Duration(minutes: 5));
      if (_scheduledAt!.isBefore(minAllowed)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('order.create.scheduled_min_5min'))),
        );
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      // Yo'l vaqtini Yandex'dan olamiz — u tirbandlikni hisobga oladi,
      // serverdagi OSRM esa yo'q. Marshrut topilmasa `null` yuboriladi va
      // server o'z hisobiga qaytadi.
      final route = await MapRoute.fetch(_pickup!, _delivery!);

      final r = await CustomerApi.instance.createOrder(
        cargoTypeId: _selected!.id,
        pickupAddress: pickupAddr,
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        deliveryAddress: deliveryAddr,
        deliveryLat: _delivery!.latitude,
        deliveryLng: _delivery!.longitude,
        cargoWeightKg: w,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        scheduledPickupAt: _scheduledMode ? _scheduledAt : null,
        durationMin: route?.durationMin,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CustomerPaymentSelectPage(result: r),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.firstFieldMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('order.create_title')),
        actions: [
          AppBarRefreshButton(
            loading: _loadingTariffs,
            onPressed: _loadingTariffs ? null : _loadTariffs,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              I18n.t('order.create.intro'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 22),
            AlixSectionTitle(I18n.t('tariff.cargo_type_required')),
            if (_loadingTariffs)
              const LinearProgressIndicator(minHeight: 3)
            else if (_tariffError != null)
              AlixBanner(
                message: _tariffError!,
                icon: Icons.error_outline_rounded,
                action: TextButton(
                  onPressed: _loadTariffs,
                  child: Text(I18n.t('common.retry_short')),
                ),
              )
            else if (_cargoTypes.isEmpty)
              AlixBanner(
                message: I18n.t('tariff.cargo_types_empty'),
                tone: AlixTone.warning,
                action: TextButton(
                  onPressed: _loadTariffs,
                  child: Text(I18n.t('common.retry_short')),
                ),
              )
            else
              DropdownMenu<CargoType>(
                initialSelection: _selected,
                expandedInsets: EdgeInsets.zero,
                label: Text(I18n.t('tariff.cargo_type_required')),
                dropdownMenuEntries: _cargoTypes
                    .map((t) => DropdownMenuEntry<CargoType>(value: t, label: t.name))
                    .toList(),
                onSelected: (v) => setState(() => _selected = v),
              ),
            const SizedBox(height: 24),
            AlixSectionTitle(I18n.t('order.create.addresses_section')),
            _LocationField(
              label: I18n.t('order.create.pickup_field_label'),
              // Yo'nalish tili ro'yxatdagidek: boshlanish to'q, manzil orange.
              markerColor: Theme.of(context).colorScheme.onSurface,
              controller: _pickupAddr,
              latLng: _pickup,
              onPickFromMap: () => _pickFromMap(isPickup: true),
            ),
            const SizedBox(height: 12),
            _LocationField(
              label: I18n.t('order.create.delivery_field_label'),
              markerColor: AppPalette.orange,
              controller: _deliveryAddr,
              latLng: _delivery,
              onPickFromMap: () => _pickFromMap(isPickup: false),
            ),
            const SizedBox(height: 24),
            AlixSectionTitle(I18n.t('order.create.details_section')),
            TextField(
              controller: _weight,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5)
              ],
              decoration: InputDecoration(
                labelText: I18n.t('order.create.weight_field_label'),
                prefixIcon: const Icon(Icons.scale_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              decoration: InputDecoration(
                labelText: I18n.t('order.create.comment_field_label'),
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            AlixSectionTitle(I18n.t('order.create.schedule_section')),
            _ScheduledPickupCard(
              enabled: _scheduledMode,
              scheduledAt: _scheduledAt,
              onToggle: (v) => setState(() {
                _scheduledMode = v;
                if (!v) _scheduledAt = null;
              }),
              onPick: _pickScheduledDateTime,
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: I18n.t('order.create.calculate_continue'),
              icon: Icons.calculate_rounded,
              loading: _submitting,
              onPressed: (_submitting || _loadingTariffs) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Rejali buyurtma" karta — toggle + datetime picker.
/// Ochilgan paytda kelajakdagi olib ketish vaqtini tanlash imkonini beradi.
class _ScheduledPickupCard extends StatelessWidget {
  const _ScheduledPickupCard({
    required this.enabled,
    required this.scheduledAt,
    required this.onToggle,
    required this.onPick,
  });

  final bool enabled;
  final DateTime? scheduledAt;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPick;

  String _formatScheduled(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: onToggle,
              title: Text(I18n.t('order.create.scheduled_card_title')),
              subtitle: Text(I18n.t('order.create.scheduled_card_subtitle')),
            ),
            if (enabled) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event_rounded, size: 18, color: AppPalette.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scheduledAt == null
                          ? I18n.t('order.create.time_not_picked')
                          : _formatScheduled(scheduledAt!),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(scheduledAt == null
                        ? I18n.t('order.create.pick_btn')
                        : I18n.t('order.create.change_btn')),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: cs.surface,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                I18n.t('order.create.scheduled_driver_hint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ],
      ),
    );
  }
}

/// Manzil bloki: nuqta belgisi, tanlangan manzil va xaritadan tanlash tugmasi.
///
/// Manzil faqat xaritadan tanlanadi — qo'lda yozilsa LatLng bo'lmaydi va
/// server buyurtmani qabul qilmaydi.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.markerColor,
    required this.controller,
    required this.latLng,
    required this.onPickFromMap,
  });

  final String label;

  /// Yo'nalishdagi nuqta rangi: olib ketish to'q, yetkazish orange.
  final Color markerColor;

  final TextEditingController controller;
  final LatLng? latLng;
  final VoidCallback onPickFromMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasPick = latLng != null;

    return AlixCard(
      tone: AlixSurfaceTone.cream,
      padding: const EdgeInsets.all(16),
      onTap: onPickFromMap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: markerColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              if (hasPick)
                AlixStatusChip(
                  label: I18n.t('order.create.location_selected'),
                  tone: AlixTone.success,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              // Karta krem, shuning uchun ichki maydon oq — aks holda ular
              // qo'shilib ketadi va maydon ko'rinmaydi.
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppPalette.radiusField),
            ),
            child: Text(
              controller.text.trim().isEmpty
                  ? I18n.t('order.create.pick_from_map_hint')
                  : controller.text.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: controller.text.trim().isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                fontWeight: controller.text.trim().isEmpty
                    ? FontWeight.w400
                    : FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasPick
                      ? '${latLng!.latitude.toStringAsFixed(5)}, ${latLng!.longitude.toStringAsFixed(5)}'
                      : I18n.t('order.create.location_not_yet'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPickFromMap,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: Text(hasPick
                    ? I18n.t('order.create.change_btn')
                    : I18n.t('order.create.pick_from_map_btn')),
                style: OutlinedButton.styleFrom(
                  backgroundColor: cs.surface,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
