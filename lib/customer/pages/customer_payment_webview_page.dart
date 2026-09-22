import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';

/// Kapitalbank to'lov sahifasini WebView'da ochadi.
///
/// Karta raqami, muddati va CVV FAQAT bank sahifasida kiritiladi — ilova
/// ularni na ko'radi, na saqlaydi. Shu sababli bizda PCI DSS talabi yo'q.
///
/// Sahifa `redirectUrl` ga o'tganini payqaganda o'zini yopadi va `true`
/// qaytaradi. Bu "to'lov muvaffaqiyatli" degani EMAS — haqiqiy natija
/// serverdan (`topUpStatus`) so'raladi, chunki faqat imzolangan webhook
/// ishonchli manba hisoblanadi.
class CustomerPaymentWebviewPage extends StatefulWidget {
  const CustomerPaymentWebviewPage({
    super.key,
    required this.paymentUrl,
    required this.redirectUrl,
  });

  final String paymentUrl;

  /// To'lovdan keyin bank qaytaradigan manzil (homeRedirectUrl).
  final String redirectUrl;

  @override
  State<CustomerPaymentWebviewPage> createState() => _CustomerPaymentWebviewPageState();
}

class _CustomerPaymentWebviewPageState extends State<CustomerPaymentWebviewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _checkRedirect(url);
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            if (_isRedirect(request.url)) {
              _finish();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// Faqat manzil boshini solishtiramiz: bank qaytarishda query parametr
  /// qo'shishi mumkin (masalan ?operationId=...).
  bool _isRedirect(String url) {
    final target = widget.redirectUrl.trim();
    if (target.isEmpty) return false;
    return url.startsWith(target);
  }

  void _checkRedirect(String url) {
    if (_isRedirect(url)) _finish();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(true);
  }

  Future<bool> _confirmLeave() async {
    if (_finished) return true;

    return showAlixConfirm(
      context,
      icon: Icons.close_rounded,
      title: I18n.t('payment.webview_leave_title'),
      message: I18n.t('payment.webview_leave_body'),
      confirmLabel: I18n.t('payment.webview_leave_confirm'),
      cancelLabel: I18n.t('common.cancel'),
      danger: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Navigator'ni async bo'shliqdan OLDIN olamiz — keyin `context` ni
        // qayta ishlatish xavfli (widget yo'q bo'lib ketishi mumkin).
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) {
          // Bekor qilingan bo'lsa ham `false` bilan qaytamiz — chaqiruvchi
          // baribir holatni serverdan tekshiradi.
          navigator.pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(I18n.t('payment.webview_title')),
          bottom: _loading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
