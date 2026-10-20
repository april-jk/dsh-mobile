class ApiException implements Exception {
  const ApiException(this.code, {this.statusCode, this.message});

  final String code;
  final int? statusCode;

  /// Backend diagnostic text. Never render it directly; map [code] to a
  /// catalog key at the presentation layer.
  final String? message;

  @override
  String toString() => 'ApiException($code, $statusCode)';
}
