import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';

/// Buyurtma formasidagi "Yukni kim qabul qiladi?" holati.
///
/// Qabul qiluvchidan faqat telefon so'raladi — u yukni kuzatadi (SMS havola),
/// buyurtmani esa uni yaratgan mijoz yakunlaydi. "O'zim qabul qilaman"
/// belgilansa (`self`) — telefon maydoni o'chadi.
class RecipientFormController extends ChangeNotifier {
  bool self = false;
  final phone = TextEditingController();

  String get phoneDigits => phone.text.replaceAll(RegExp(r'\D'), '');

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
    return null;
  }

  @override
  void dispose() {
    phone.dispose();
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
