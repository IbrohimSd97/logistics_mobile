import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'net_log.dart';

/// Ichki [http.Client] ni o'rab, har bir so'rov va javobni [NetLog] ga
/// (va debug konsolga) yozadigan client.
///
/// `runWithClient` orqali ildiz zonaga o'rnatiladi, shuning uchun ilovadagi
/// barcha top-level `http.get/post/...` chaqiruvlari shu client orqali o'tadi —
/// hech bir call-site'ni o'zgartirish shart emas.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final entry = NetLog.instance.start(
      method: request.method,
      uri: request.url.toString(),
      requestHeaders: Map<String, String>.from(request.headers),
      requestBody: _requestBody(request),
    );

    if (kDebugMode) {
      debugPrint('→ ${request.method} ${request.url}');
      final body = entry.requestBody;
      if (body != null && body.isNotEmpty) debugPrint('  body: $body');
    }

    final sw = Stopwatch()..start();
    try {
      final streamed = await _inner.send(request);
      final res = await http.Response.fromStream(streamed);
      sw.stop();

      NetLog.instance.complete(
        entry,
        statusCode: res.statusCode,
        responseHeaders: res.headers,
        responseBody: res.body,
        elapsedMs: sw.elapsedMilliseconds,
      );

      if (kDebugMode) {
        debugPrint(
            '← ${res.statusCode} ${request.method} ${request.url} (${sw.elapsedMilliseconds}ms)');
        debugPrint('  ${_truncate(res.body, 1000)}');
      }

      // Javob stream'i o'qib bo'lindi — qayta tiklab qaytaramiz.
      return http.StreamedResponse(
        Stream<List<int>>.value(res.bodyBytes),
        res.statusCode,
        contentLength: res.bodyBytes.length,
        request: res.request,
        headers: res.headers,
        isRedirect: res.isRedirect,
        persistentConnection: res.persistentConnection,
        reasonPhrase: res.reasonPhrase,
      );
    } catch (e) {
      sw.stop();
      NetLog.instance.fail(entry, e.toString(), sw.elapsedMilliseconds);
      if (kDebugMode) {
        debugPrint('✗ ${request.method} ${request.url} — $e');
      }
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  String? _requestBody(http.BaseRequest request) {
    if (request is http.Request) {
      return request.body.isEmpty ? null : request.body;
    }
    if (request is http.MultipartRequest) {
      final files = request.files
          .map((f) => '${f.field}:${f.filename ?? 'file'} (${f.length}b)')
          .join(', ');
      return 'multipart fields=${jsonEncode(request.fields)} files=[$files]';
    }
    return null;
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}… (+${s.length - max})';
}
