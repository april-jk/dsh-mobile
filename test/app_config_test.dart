import 'package:dsh_mobile/core/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production defaults use the deployed HTTPS Relay without Mock', () {
    final config = AppConfig.fromEnvironment();

    expect(config.useMock, isFalse);
    expect(config.relayBaseUrl, AppConfig.productionRelayUrl);
    expect(config.relayOrigin.scheme, 'https');
  });

  test('release validation rejects a non-HTTPS Relay', () {
    const config = AppConfig(
      relayBaseUrl: 'http://127.0.0.1:8787',
      useMock: false,
    );

    expect(() => config.validate(isRelease: true), throwsStateError);
    expect(() => config.validate(isRelease: false), returnsNormally);
  });

  test('release validation rejects Mock Relay', () {
    const config = AppConfig(
      relayBaseUrl: AppConfig.productionRelayUrl,
      useMock: true,
    );

    expect(() => config.validate(isRelease: true), throwsStateError);
    expect(() => config.validate(isRelease: false), returnsNormally);
  });
}
