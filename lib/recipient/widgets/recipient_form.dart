import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_palette.dart';
import '../recipient_api.dart';

/// Buyurtma formasidagi "Yukni kim qabul qiladi?" holati.
///
/// Telefon va STIR/PINFL doim ko'rinadi va majburiy; nom Didox'dan olinadi,
/// topilmasa qo'lda kiritiladi. "O'zim qabul qilaman" belgilansa (`self`) —
/// maydonlar o'chadi va mijoz yukni o'zi qabul qilib, o'zi yakunlaydi.
class RecipientFormController extends ChangeNotifier {
  RecipientFormController() {
    tin.addListener(_onTinChanged);
  }

  bool self = false;
  final phone = TextEditingController();
  final tin = TextEditingController();
  final name = TextEditingController();

  /// Didox nomi (topilgan bo'lsa) — mijozga tasdiqlash uchun ko'rsatiladi.
  String? foundName;
  bool looking = false;

  /// Topilmadi / Didox ishlamadi — nom qo'lda kiritiladi.
  bool manualName = false;
  String _checked = '';
  Timer? _debounce;

  String get phoneDigits => phone.text.replaceAll(RegExp(r'\D'), '');
  String get tinValue => tin.text.trim();

  /// `+998XXXXXXXXX` (9 raqam yoki 998 bilan 12 raqam kiritilishi mumkin).
  String? get phoneE164 {
    final d = phoneDigits;
    if (RegExp(r'^998\d{9}$').hasMatch(d)) return '+$d';
    if (RegExp(r'^\d{9}$').hasMatch(d)) return '+998$d';
    return null;
  }

  void setSelf(bool v) {
    self = v;
    notifyListeners();
  }

  /// Formani yuborishdan oldin: null — hammasi to'g'ri, aks holda xato matni.
  String? validate() {
    if (self) return null;
    if (phoneE164 == null) return I18n.t('order.recipient.phone_invalid');
    if (!RegExp(r'^(\d{9}|\d{14})$').hasMatch(tinValue)) return I18n.t('order.recipient.tin_invalid');
    if (foundName == null && name.text.trim().isEmpty) return I18n.t('order.recipient.name_required');
    return null;
  }

  void _onTinChanged() {
    final v = tinValue;
    if (v == _checked) return;
    _debounce?.cancel();
    foundName = null;
    manualName = false;
    if (!RegExp(r'^(\d{9}|\d{14})$').hasMatch(v)) {
      _checked = '';
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _lookup(v));
    notifyListeners();
  }

  Future<void> _lookup(String v) async {
    _checked = v;
    looking = true;
    notifyListeners();
    RecipientLookup? r;
    try {
      r = await RecipientApi.instance.lookup(v);
    } catch (_) {
      r = null;
    }
    if (tinValue != v) return;
    looking = false;
    foundName = (r?.found ?? false) ? r!.name : null;
    manualName = foundName == null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    tin.removeListener(_onTinChanged);
    phone.dispose();
    tin.dispose();
    name.dispose();
    super.dispose();
  }
}

class RecipientFormSection extends StatelessWidget {
  const RecipientFormSection({super.key, required this.controller});

  final RecipientFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AlixSectionTitle(I18n.t('order.recipient.section')),
            TextField(
              controller: c.phone,
              enabled: !c.self,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+ ]')), LengthLimitingTextInputFormatter(17)],
              decoration: InputDecoration(
                labelText: I18n.t('order.recipient.phone'),
                hintText: '+998 90 123 45 67',
                prefixIcon: const Icon(Icons.phone_rounded),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c.tin,
              enabled: !c.self,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
              decoration: InputDecoration(
                labelText: I18n.t('order.recipient.tin'),
                helperText: c.self ? null : I18n.t('order.recipient.tin_helper'),
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: c.looking
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : c.foundName != null
                        ? const Icon(Icons.verified_rounded, color: AppPalette.success)
                        : null,
              ),
            ),
            if (!c.self && c.foundName != null) ...[
              const SizedBox(height: 8),
              AlixBanner(
                message: I18n.t('order.recipient.found', {'name': c.foundName!}),
                tone: AlixTone.success,
              ),
            ],
            if (c.manualName) ...[
              const SizedBox(height: 12),
              TextField(
                controller: c.name,
                enabled: !c.self,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: I18n.t('order.recipient.name')),
              ),
            ],
            const SizedBox(height: 4),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => c.setSelf(!c.self),
              child: Row(
                children: [
                  Checkbox(
                    value: c.self,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => c.setSelf(v ?? false),
                  ),
                  Text(I18n.t('order.recipient.self'), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (!c.self)
              Text(
                I18n.t('order.recipient.hint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        );
      },
    );
  }
}
