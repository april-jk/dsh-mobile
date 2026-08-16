class ApiException implements Exception {
  const ApiException(this.code, {this.statusCode, this.message});

  final String code;
  final int? statusCode;
  final String? message;

  @override
  String toString() => 'ApiException($code, $statusCode)';
}

String userMessage(Object error) {
  if (error is! ApiException) return '网络异常，请检查连接后重试。';
  return switch (error.code) {
    'invalid_credentials' => '邮箱或密码错误。',
    'email_exists' => '该邮箱已注册。',
    'invalid_refresh_token' => '登录已过期，请重新登录。',
    'invalid_or_expired_code' => '配对码无效或已过期。',
    'forbidden' => '你无权访问该设备。',
    'not_found' => '设备不存在或已被解绑。',
    _ => error.message ?? '请求失败，请稍后重试。',
  };
}
