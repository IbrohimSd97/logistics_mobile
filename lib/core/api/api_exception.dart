class ApiException implements Exception {
  ApiException(this.message, {this.errors = const {}, this.statusCode});

  final String message;
  final Map<String, List<dynamic>> errors;
  final int? statusCode;

  String get firstFieldMessage {
    for (final entry in errors.entries) {
      final list = entry.value;
      if (list.isNotEmpty) return '${entry.key}: ${list.first}';
    }
    return message;
  }

  static ApiException fromJson(Map<String, dynamic> json, [int? statusCode]) {
    final msg = json['message'] as String? ?? 'So‘rov bajarilmadi';
    final raw = json['errors'];
    final Map<String, List<dynamic>> err = {};
    if (raw is Map<String, dynamic>) {
      for (final e in raw.entries) {
        final v = e.value;
        if (v is List) {
          err[e.key] = v;
        } else if (v != null) {
          err[e.key] = [v];
        }
      }
    }
    return ApiException(msg, errors: err, statusCode: statusCode);
  }
}
