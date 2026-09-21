import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/brand/alix_components.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/refresh_icon_button.dart';
import '../customer_api.dart';
import '../customer_models.dart';

class CustomerTariffListPage extends StatefulWidget {
  const CustomerTariffListPage({super.key});

  @override
  State<CustomerTariffListPage> createState() => _CustomerTariffListPageState();
}

class _CustomerTariffListPageState extends State<CustomerTariffListPage>
    with I18nObserverMixin<CustomerTariffListPage> {
  List<TariffItem> _items = [];
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
      final list = await CustomerApi.instance.tariffLists();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.firstFieldMessage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final n = num.tryParse(raw);
    if (n == null) return raw;
    final i = n.round();
    final s = i.abs().toString();
    final buf = StringBuffer();
    for (int k = 0; k < s.length; k++) {
      if (k > 0 && (s.length - k) % 3 == 0) buf.write(' ');
      buf.write(s[k]);
    }
    return i < 0 ? '-$buf' : buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('tariff.title')),
        actions: [
          AppBarRefreshButton(loading: _loading, onPressed: _loading ? null : _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      AlixBanner(
                        message: _error!,
                        icon: Icons.error_outline_rounded,
                        action: TextButton(
                          onPressed: _load,
                          child: Text(I18n.t('common.retry')),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                        children: [
                          AlixEmptyState(
                            icon: Icons.price_change_outlined,
                            title: I18n.t('tariff.empty'),
                            message: I18n.t('tariff.empty_subtitle'),
                          ),
                        ],
                      )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final t = _items[i];
                      final description = t.description ?? '';
                      return AlixCard(
                        tone: AlixSurfaceTone.cream,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined,
                                    size: 18, color: AppPalette.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.name,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              I18n.t('tariff.row_subtitle', {
                                'ppk': _fmt(t.pricePerKm),
                                'min': _fmt(t.minOrderPrice),
                              }),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(description,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
