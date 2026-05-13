import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/session/session_store.dart';
import '../../screens/login_screen.dart';
import '../driver_api.dart';
import '../driver_models.dart';

class DriverRejectedPage extends StatefulWidget {
  const DriverRejectedPage({
    super.key,
    required this.phoneDisplay,
    required this.userId,
    required this.status,
  });

  final String phoneDisplay;
  final int userId;
  final DriverRegistrationStatus status;

  @override
  State<DriverRejectedPage> createState() => _DriverRejectedPageState();
}

class _DriverRejectedPageState extends State<DriverRejectedPage> {
  DriverRegistrationRejects? _rejects;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await DriverApi.instance.registrationRejects();
      if (!mounted) return;
      setState(() {
        _rejects = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.firstFieldMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Tarmoq xatosi: $e';
      });
    }
  }

  Future<void> _logoutAndRetry() async {
    await SessionStore().clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _stepCard(int stepNo, String title, Map<String, dynamic>? errors, ColorScheme cs) {
    if (errors == null || errors.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline_rounded, color: Colors.green),
          title: Text('Step $stepNo: $title'),
          subtitle: const Text('Xatolik yo‘q'),
        ),
      );
    }
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  'Step $stepNo: $title',
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...errors.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• ${_humanize(e.key)}: ${_describe(e.value)}',
                  style: TextStyle(color: cs.onErrorContainer, height: 1.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _humanize(String key) =>
      key.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m[0]!.toUpperCase());

  String _describe(dynamic v) {
    if (v == null) return '—';
    if (v is List) return v.join(', ');
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ariza rad etildi')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.report_gmailerrorred_rounded, color: cs.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sizning arizangiz rad etildi',
                            style: TextStyle(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quyidagi kamchiliklarni tuzatib, qayta kiring va ro‘yxatdan o‘ting.',
                            style: TextStyle(color: cs.onErrorContainer, height: 1.35),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rad etilgan: ${widget.status.rejectCount}/3 marta',
                            style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Card(
                color: cs.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                  title: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                  trailing: FilledButton.tonal(onPressed: _load, child: const Text('Qayta')),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_rejects != null) ...[
              if ((_rejects!.comment ?? '').isNotEmpty) ...[
                Card(
                  color: cs.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin izohi',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onTertiaryContainer,
                            )),
                        const SizedBox(height: 6),
                        Text(
                          _rejects!.comment!,
                          style: TextStyle(color: cs.onTertiaryContainer, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _stepCard(1, 'Shaxsiy ma‘lumotlar', _rejects!.step1Errors, cs),
              _stepCard(2, 'Mashina ma‘lumotlari', _rejects!.step2Errors, cs),
              _stepCard(3, 'Egalik va yuridik holat', _rejects!.step3Errors, cs),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _logoutAndRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Qayta kirish va tuzatish'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Qayta kirish: telefoningizga yangi OTP yuboriladi va siz kamchiliklarni tuzatib qayta yuborishingiz mumkin.',
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.35, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
