import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'net_log.dart';

/// Ilova ustiga debug tarmoq logini ko'rsatadigan overlay.
///
/// `MaterialApp.builder` ichida [child] ni o'raydi: pastki-o'ng burchakda
/// suzuvchi tugma, bosilganda — so'rov/javoblar ro'yxati ochiladi.
/// [kNetLogEnabled] false bo'lsa hech narsa qo'shmaydi.
class NetLogOverlay extends StatefulWidget {
  const NetLogOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<NetLogOverlay> createState() => _NetLogOverlayState();
}

class _NetLogOverlayState extends State<NetLogOverlay> {
  bool _open = false;
  // Suzuvchi tugma pozitsiyasi (pastki-o'ngdan offset).
  Offset _btn = const Offset(16, 90);

  @override
  Widget build(BuildContext context) {
    if (!kNetLogEnabled) return widget.child;

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_open)
          Positioned.fill(
            child: _NetLogPanel(onClose: () => setState(() => _open = false)),
          )
        else
          Positioned(
            right: _btn.dx,
            bottom: _btn.dy,
            child: _FloatingButton(
              onTap: () => setState(() => _open = true),
              onDrag: (delta) => setState(() {
                _btn = Offset(
                  (_btn.dx - delta.dx).clamp(0.0, 320.0),
                  (_btn.dy - delta.dy).clamp(0.0, 700.0),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({required this.onTap, required this.onDrag});

  final VoidCallback onTap;
  final void Function(Offset delta) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onPanUpdate: (d) => onDrag(d.delta),
      child: AnimatedBuilder(
        animation: NetLog.instance,
        builder: (_, __) {
          final count = NetLog.instance.entries.length;
          return Material(
            color: Colors.black.withValues(alpha: 0.78),
            shape: const StadiumBorder(),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_vert, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text('NET $count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NetLogPanel extends StatelessWidget {
  const _NetLogPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF21A1A1A),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.wifi_tethering, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                const Text('Tarmoq logi',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                  onPressed: NetLog.instance.clear,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child: AnimatedBuilder(
                animation: NetLog.instance,
                builder: (_, __) {
                  final items = NetLog.instance.entries;
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('Hali so\'rov yo\'q',
                          style: TextStyle(color: Colors.white54)),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (_, i) => _LogTile(entry: items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final NetLogEntry entry;

  Color get _color {
    switch (entry.level) {
      case 'ok':
        return const Color(0xFF4CAF50);
      case 'warn':
        return const Color(0xFFFFB300);
      case 'err':
        return const Color(0xFFE53935);
      default:
        return Colors.white38;
    }
  }

  String get _status => entry.error != null
      ? 'ERR'
      : (entry.statusCode?.toString() ?? '...');

  String get _path {
    final u = Uri.tryParse(entry.uri);
    if (u == null) return entry.uri;
    return u.path + (u.hasQuery ? '?${u.query}' : '');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Container(
          width: 46,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(_status,
              style: TextStyle(
                  color: _color, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        title: Text('${entry.method}  $_path',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        subtitle: Text(
            '${entry.uri}${entry.elapsedMs != null ? '  •  ${entry.elapsedMs}ms' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        children: [
          _section('SO\'ROV', '${entry.method} ${entry.uri}'),
          _kv('Headers', _fmtHeaders(entry.requestHeaders)),
          if (entry.requestBody != null) _kv('Body', entry.requestBody!),
          const SizedBox(height: 8),
          _section('JAVOB',
              entry.error != null ? 'XATO' : 'HTTP ${entry.statusCode ?? '-'}'),
          if (entry.error != null) _kv('Error', entry.error!),
          if (entry.responseHeaders != null)
            _kv('Headers', _fmtHeaders(entry.responseHeaders!)),
          if (entry.responseBody != null) _kv('Body', entry.responseBody!),
        ],
      ),
    );
  }

  static String _fmtHeaders(Map<String, String> h) =>
      h.entries.map((e) => '${e.key}: ${e.value}').join('\n');

  Widget _section(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ),
          ],
        ),
      );

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: value)),
                  child: const Icon(Icons.copy, size: 14, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ),
          ],
        ),
      );
}
