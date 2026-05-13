import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

typedef JsonMap = Map<String, dynamic>;

bool _looksLikeHtml(String body) {
  final s = body.trimLeft().toLowerCase();
  return s.startsWith('<!doctype html') || s.startsWith('<html');
}

String _humanHttpMessage(int statusCode) {
  return switch (statusCode) {
    400 => 'So‘rov noto‘g‘ri ($statusCode)',
    401 => 'Avtorizatsiya kerak ($statusCode)',
    403 => 'Ruxsat yo‘q ($statusCode)',
    404 => 'Topilmadi ($statusCode)',
    409 => 'Konflikt ($statusCode)',
    422 => 'Validatsiya xatosi ($statusCode)',
    429 => 'Juda koʻp so‘rov ($statusCode)',
    >= 500 && < 600 => 'Server xatosi ($statusCode)',
    _ => 'So‘rov bajarilmadi ($statusCode)',
  };
}

String _sanitizeNonJsonBody(http.Response res) {
  final raw = res.body.trim();
  if (raw.isEmpty) return '';
  final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  const maxLen = 180;
  if (oneLine.length <= maxLen) return oneLine;
  return '${oneLine.substring(0, maxLen)}…';
}

Map<String, List<dynamic>> _normalizeErrorsField(Object? raw) {
  if (raw == null || raw is! Map) return {};

  final out = <String, List<dynamic>>{};
  raw.forEach((k, v) {
    final key = k.toString();

    // Laravel-ish: `{ "errors": { "email": [".."], "nested": {...} } }`
    // We prioritize list-of-messages branches; nested maps aren't expanded here (rare).
    if (v is List) {
      out[key] = v;
      return;
    }
    if (v != null) {
      out[key] = [v];
    }
  });
  return out;
}

/// Decode JSON `{success,...}` envelopes (preferred) OR tolerate Laravel-ish `{message,errors}` payloads.
///
/// Throws [ApiException] for HTTP errors even when JSON decodes successfully.
JsonMap decodeJsonEnvelopeOrThrow(http.Response res) {
  if (res.body.isEmpty && res.statusCode >= 400) {
    throw ApiException(_humanHttpMessage(res.statusCode), statusCode: res.statusCode);
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(res.body);
  } catch (_) {
    if (_looksLikeHtml(res.body)) {
      throw ApiException(_humanHttpMessage(res.statusCode), statusCode: res.statusCode);
    }
    final snippet = _sanitizeNonJsonBody(res);
    throw ApiException(
      snippet.isNotEmpty ? snippet : _humanHttpMessage(res.statusCode),
      statusCode: res.statusCode,
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw ApiException('Server javobi noto‘g‘ri formatda', statusCode: res.statusCode);
  }

  final map = decoded;

  final hasExplicitSuccessKey = map.containsKey('success');
  final success = map['success'] as bool?;

  final errorsRaw = map['errors'];
  final normalizedErrors = _normalizeErrorsField(errorsRaw);

  // Laravel-ish validation without envelope
  if (!hasExplicitSuccessKey && normalizedErrors.isNotEmpty) {
    final msg = (map['message'] as String?) ?? _humanHttpMessage(res.statusCode);
    throw ApiException(msg, errors: normalizedErrors, statusCode: res.statusCode);
  }

  final ok = success == true;
  final failEnvelope = success == false;

  if (failEnvelope) {
    throw ApiException.fromJson(map, res.statusCode);
  }

  if (res.statusCode >= 400) {
    // Some backends return `{message,...}` without `success:false`
    throw ApiException.fromJson(map, res.statusCode);
  }

  // If envelope omits success on 2xx, treat as OK.
  if (!hasExplicitSuccessKey) {
    map['success'] = true;
    return map;
  }

  if (!ok) {
    throw ApiException.fromJson(map, res.statusCode);
  }

  return map;
}
