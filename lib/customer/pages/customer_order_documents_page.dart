import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../customer_api.dart';

class CustomerOrderDocumentsPage extends StatefulWidget {
  const CustomerOrderDocumentsPage({super.key, required this.orderId});

  final int orderId;

  @override
  State<CustomerOrderDocumentsPage> createState() => _CustomerOrderDocumentsPageState();
}

class _CustomerOrderDocumentsPageState extends State<CustomerOrderDocumentsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = CustomerApi.instance.orderDocuments(widget.orderId);
  }

  void _retry() {
    setState(() {
      _future = CustomerApi.instance.orderDocuments(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtma hujjatlari')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final err = snap.error;
            final msg = err is ApiException ? err.firstFieldMessage : 'Tarmoq xatosi: $err';
            return _retryView(context, msg);
          }
          final map = snap.data;
          if (map == null) {
            return _retryView(context, 'Ma’lumot topilmadi.');
          }
          final raw = map['data'];
          final list = _flatten(raw);
          if (list.isEmpty) {
            return _retryView(context, 'Hujjatlar bo‘sh.');
          }
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, i) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = list[i];
                return ListTile(
                  dense: true,
                  title: Text(_humanizeKey(e.key)),
                  subtitle: SelectableText(e.value, style: const TextStyle(height: 1.35)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _retryView(BuildContext context, String msg) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: _retry, child: const Text('Qayta urinish')),
      ],
    );
  }

  List<MapEntry<String, String>> _flatten(dynamic raw, [String prefix = '']) {
    final out = <MapEntry<String, String>>[];
    if (raw is Map) {
      raw.forEach((k, v) {
        final key = prefix.isEmpty ? k.toString() : '$prefix.$k';
        out.addAll(_flatten(v, key));
      });
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        out.addAll(_flatten(raw[i], '$prefix[$i]'));
      }
    } else {
      out.add(MapEntry(prefix, raw?.toString() ?? '—'));
    }
    return out;
  }

  String _humanizeKey(String k) {
    return k.replaceAll('_', ' ').replaceAllMapped(
          RegExp(r'(^|\.|\s)([a-zA-Z])'),
          (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
        );
  }
}
