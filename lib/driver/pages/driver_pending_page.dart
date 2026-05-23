import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/i18n/i18n.dart';
import '../../core/session/session_store.dart';
import '../../screens/login_screen.dart';
import '../../screens/main_shell.dart';
import '../driver_api.dart';
import '../driver_models.dart';
import 'driver_failed_page.dart';
import 'driver_rejected_page.dart';

class DriverPendingPage extends StatefulWidget {
  const DriverPendingPage({
    super.key,
    required this.phoneDisplay,
    required this.userId,
    this.initialStatus,
  });

  final String phoneDisplay;
  final int userId;
  final DriverRegistrationStatus? initialStatus;

  @override
  State<DriverPendingPage> createState() => _DriverPendingPageState();
}

class _DriverPendingPageState extends State<DriverPendingPage>
    with I18nObserverMixin<DriverPendingPage> {
  Timer? _poll;
  bool _checking = false;
  String? _error;
  DriverRegistrationStatus? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final s = await DriverApi.instance.registrationStatus();
      if (!mounted) return;
      setState(() {
        _status = s;
        _checking = false;
      });
      _routeIfChanged(s);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = I18n.t('driver.network_error_label', {'msg': '$e'});
      });
    }
  }

  void _routeIfChanged(DriverRegistrationStatus s) {
    final st = s.status;
    if (st == 2) {
      _poll?.cancel();
      // Stack'ni tozalab MainShell(driver) bilan almashtiramiz.
      // Bu yerga ham login'dan to'g'ridan, ham toggle orqali kelinishi mumkin —
      // har holatda ham yagona MainShell qoladi.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => MainShell(
            initialMode: 'driver',
            phoneDisplay: widget.phoneDisplay,
            userId: widget.userId,
            hasRefreshSession: true,
          ),
        ),
        (_) => false,
      );
    } else if (st == 3) {
      _poll?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DriverRejectedPage(
            phoneDisplay: widget.phoneDisplay,
            userId: widget.userId,
            status: s,
          ),
        ),
      );
    } else if (st == 4) {
      _poll?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DriverFailedPage(phoneDisplay: widget.phoneDisplay),
        ),
      );
    }
  }

  Future<void> _logout() async {
    _poll?.cancel();
    await SessionStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('driver.pending.title')),
        actions: [
          IconButton(
            tooltip: I18n.t('driver.pending.refresh_tooltip'),
            icon: _checking
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _checking ? null : _check,
          ),
          IconButton(
            tooltip: I18n.t('auth.logout'),
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty_rounded, size: 80, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                I18n.t('driver.pending.heading'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                I18n.t('driver.pending.body'),
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                color: cs.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(I18n.t('driver.pending.phone_label')),
                  subtitle: Text(widget.phoneDisplay),
                ),
              ),
              if (_status != null && _status!.rejectCount > 0)
                Card(
                  color: cs.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: cs.onTertiaryContainer),
                    title: Text(I18n.t('driver.pending.reject_count', {'count': _status!.rejectCount}),
                        style: TextStyle(color: cs.onTertiaryContainer)),
                  ),
                ),
              if (_error != null)
                Card(
                  color: cs.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                    title: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checking ? null : _check,
                icon: _checking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                label: Text(_checking ? I18n.t('driver.pending.checking') : I18n.t('driver.pending.check_status')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
