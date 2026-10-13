import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api/api_exception.dart';
import '../core/api/http_response_codec.dart';
import '../core/api/request_headers.dart';
import '../core/brand/alix_components.dart';
import '../core/config/api_config.dart';
import '../core/i18n/i18n.dart';
import '../core/session/session_store.dart';
import 'login_screen.dart';

/// Akkauntni ilovaning o'zidan o'chirish (Google Play / App Store talabi).
///
/// Server (`DELETE /api/account`) shaxsiy ma'lumotlarni o'chiradi; buyurtma va
/// to'lov yozuvlari qonun bo'yicha shaxssiz holda qoladi. Faol buyurtma yoki
/// hamyonda qoldiq bo'lsa server 409 qaytaradi — xabarini ko'rsatamiz.
Future<void> deleteAccountFlow(BuildContext context) async {
  final ok = await showAlixConfirm(
    context,
    icon: Icons.delete_forever_rounded,
    title: I18n.t('account.delete.title'),
    message: I18n.t('account.delete.confirm'),
    confirmLabel: I18n.t('account.delete.confirm_btn'),
    cancelLabel: I18n.t('common.cancel'),
    danger: true,
  );
  if (!ok || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  String? error;
  try {
    final token = await SessionStore().getRefreshToken();
    if (token == null || token.isEmpty) {
      throw ApiException(I18n.t('auth.session_not_found'));
    }
    final res = await http
        .delete(Uri.parse('${ApiConfig.baseUrl}/api/account'), headers: jsonAuthHeaders(token))
        .timeout(const Duration(seconds: 20));
    decodeJsonEnvelopeOrThrow(res);
  } on ApiException catch (e) {
    error = e.message;
  } catch (_) {
    error = I18n.t('account.delete.failed');
  }

  navigator.pop(); // progress
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error), duration: const Duration(seconds: 6)));
    return;
  }

  await SessionStore().clear();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (_) => false,
  );
  messenger.showSnackBar(SnackBar(content: Text(I18n.t('account.delete.done'))));
}

/// Profil sahifasidagi "Akkauntni o'chirish" tugmasi ("Chiqish" ostida).
class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: () => deleteAccountFlow(context),
      icon: const Icon(Icons.delete_forever_rounded),
      label: Text(I18n.t('account.delete.title')),
      style: TextButton.styleFrom(foregroundColor: cs.error),
    );
  }
}
