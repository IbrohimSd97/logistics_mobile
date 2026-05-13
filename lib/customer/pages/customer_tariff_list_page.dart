import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../customer_api.dart';
import '../customer_models.dart';

class CustomerTariffListPage extends StatefulWidget {
  const CustomerTariffListPage({super.key});

  @override
  State<CustomerTariffListPage> createState() => _CustomerTariffListPageState();
}

class _CustomerTariffListPageState extends State<CustomerTariffListPage> {
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
      appBar: AppBar(title: const Text('Tariflar')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      TextButton(onPressed: _load, child: const Text('Qayta urinish')),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
                        children: [
                          Column(
                            children: const [
                              Icon(Icons.price_change_outlined, size: 56),
                              SizedBox(height: 12),
                              Text('Tariflar topilmadi', textAlign: TextAlign.center),
                              SizedBox(height: 6),
                              Text('Pastga tortib qayta urinib ko‘ring.',
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ],
                      )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final t = _items[i];
                      return Card(
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                            '${_fmt(t.pricePerKm)} so‘m/km · min ${_fmt(t.minOrderPrice)} so‘m',
                          ),
                          isThreeLine: t.description != null && t.description!.isNotEmpty,
                          trailing: t.description != null && t.description!.isNotEmpty
                              ? null
                              : null,
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
