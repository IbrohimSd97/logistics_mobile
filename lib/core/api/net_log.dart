import 'package:flutter/foundation.dart';

/// Debug tarmoq logi yoqilganmi?
///
/// Debug build'da har doim yoniq. Release build'da `--dart-define=NET_LOG=true`
/// berilsa yoqiladi.
const bool kNetLogEnabled =
    kDebugMode || bool.fromEnvironment('NET_LOG', defaultValue: false);

/// Bitta HTTP so'rov-javob yozuvi.
class NetLogEntry {
  NetLogEntry({
    required this.id,
    required this.method,
    required this.uri,
    required this.requestHeaders,
    required this.requestBody,
    required this.startedAt,
  });

  final int id;
  final String method;
  final String uri;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  final DateTime startedAt;

  int? statusCode;
  Map<String, String>? responseHeaders;
  String? responseBody;
  String? error;
  int? elapsedMs;

  bool get isPending => statusCode == null && error == null;

  /// Holatga qarab "rang darajasi": ok / warn / err.
  String get level {
    if (error != null) return 'err';
    final s = statusCode;
    if (s == null) return 'pending';
    if (s >= 500) return 'err';
    if (s >= 400) return 'warn';
    return 'ok';
  }
}

/// Barcha tarmoq so'rovlarini saqlovchi in-memory store (eng yangisi birinchi).
class NetLog extends ChangeNotifier {
  NetLog._();
  static final NetLog instance = NetLog._();

  static const int _maxEntries = 200;
  final List<NetLogEntry> _entries = <NetLogEntry>[];
  int _seq = 0;

  List<NetLogEntry> get entries => List.unmodifiable(_entries);

  NetLogEntry start({
    required String method,
    required String uri,
    required Map<String, String> requestHeaders,
    String? requestBody,
  }) {
    final entry = NetLogEntry(
      id: ++_seq,
      method: method,
      uri: uri,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      startedAt: DateTime.now(),
    );
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    notifyListeners();
    return entry;
  }

  void complete(
    NetLogEntry entry, {
    required int statusCode,
    required Map<String, String> responseHeaders,
    required String responseBody,
    required int elapsedMs,
  }) {
    entry.statusCode = statusCode;
    entry.responseHeaders = responseHeaders;
    entry.responseBody = responseBody;
    entry.elapsedMs = elapsedMs;
    notifyListeners();
  }

  void fail(NetLogEntry entry, String error, int elapsedMs) {
    entry.error = error;
    entry.elapsedMs = elapsedMs;
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
