import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/cargo_types_api.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/location_picker_page.dart';
import '../customer_api.dart';
import 'customer_payment_select_page.dart';

/// `POST /api/customer/orders/create`
class CustomerOrderCreatePage extends StatefulWidget {
  const CustomerOrderCreatePage({super.key});

  @override
  State<CustomerOrderCreatePage> createState() => _CustomerOrderCreatePageState();
}

class _CustomerOrderCreatePageState extends State<CustomerOrderCreatePage> {
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

  @override
  void initState() {
    super.initState();
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
          title: isPickup ? 'Olib ketish manzili' : 'Yetkazish manzili',
          initialLatLng: initialLat,
          initialAddress: initialAddr.isEmpty ? null : initialAddr,
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
      setState(() {
        _cargoTypes = list;
        _selected = list.isNotEmpty ? list.first : null;
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

  Future<void> _submit() async {
    final pickup = _pickupAddr.text.trim();
    final delivery = _deliveryAddr.text.trim();
    if (pickup.isEmpty || _pickup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Olib ketish manzilini kartadan tanlang.')),
      );
      return;
    }
    if (delivery.isEmpty || _delivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yetkazish manzilini kartadan tanlang.')),
      );
      return;
    }
    if (pickup.toLowerCase() == delivery.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Olib ketish va yetkazish manzili bir xil bo‘lmasin.')),
      );
      return;
    }
    if (_selected == null) {
      if (_loadingTariffs) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tariflar yuklanmoqda...')));
      } else if (_tariffError != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tariflar yuklanmadi. Qayta urining.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarif topilmadi.')));
      }
      return;
    }
    final w = int.tryParse(_weight.text.trim());
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yuk og‘irligini kiriting (kg).')));
      return;
    }
    if (w > 20000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yuk og‘irligi juda katta (max 20000 kg).')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final r = await CustomerApi.instance.createOrder(
        cargoTypeId: _selected!.id,
        pickupAddress: pickup,
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        deliveryAddress: delivery,
        deliveryLat: _delivery!.latitude,
        deliveryLng: _delivery!.longitude,
        cargoWeightKg: w,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
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
      appBar: AppBar(title: const Text('Yangi buyurtma')),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Kartadan olib ketish va yetkazish manzilini tanlang, tarif tanlang, yuk og‘irligini kiriting.',
              style: TextStyle(height: 1.35),
            ),
            const SizedBox(height: 16),
            if (_loadingTariffs)
              const LinearProgressIndicator()
            else if (_tariffError != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                  title: Text(
                    _tariffError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  trailing: FilledButton.tonal(onPressed: _loadTariffs, child: const Text('Retry')),
                ),
              )
            else if (_cargoTypes.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Yuk turlari topilmadi'),
                  subtitle: const Text('Qayta urinish uchun pastdan torting yoki Retry bosing.'),
                  trailing: FilledButton.tonal(onPressed: _loadTariffs, child: const Text('Retry')),
                ),
              )
            else
              DropdownMenu<CargoType>(
                initialSelection: _selected,
                expandedInsets: EdgeInsets.zero,
                label: const Text('Yuk turi *'),
                dropdownMenuEntries: _cargoTypes
                    .map((t) => DropdownMenuEntry<CargoType>(value: t, label: t.name))
                    .toList(),
                onSelected: (v) => setState(() => _selected = v),
              ),
            const SizedBox(height: 12),
            _LocationField(
              label: 'Olib ketish manzili *',
              icon: Icons.my_location_outlined,
              controller: _pickupAddr,
              latLng: _pickup,
              onPickFromMap: () => _pickFromMap(isPickup: true),
            ),
            const SizedBox(height: 8),
            _LocationField(
              label: 'Yetkazish manzili *',
              icon: Icons.flag_outlined,
              controller: _deliveryAddr,
              latLng: _delivery,
              onPickFromMap: () => _pickFromMap(isPickup: false),
            ),
            TextField(
              controller: _weight,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
              decoration: const InputDecoration(labelText: 'Yuk og‘irligi (kg) *'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _comment,
              decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Hisoblash va davom etish',
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

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.latLng,
    required this.onPickFromMap,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final LatLng? latLng;
  final VoidCallback onPickFromMap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPick = latLng != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (hasPick)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 14, color: cs.onPrimaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          'tanlangan',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Manzil matni (kartadan to‘ldiriladi)',
                isDense: true,
              ),
              readOnly: false,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasPick)
                  Expanded(
                    child: Text(
                      '${latLng!.latitude.toStringAsFixed(5)}, ${latLng!.longitude.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      'Hali tanlanmagan',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                FilledButton.tonalIcon(
                  onPressed: onPickFromMap,
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: Text(hasPick ? 'O‘zgartirish' : 'Kartadan tanlash'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
