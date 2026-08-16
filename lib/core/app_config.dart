class AppConfig {
  const AppConfig({required this.relayBaseUrl, required this.useMock});

  static const productionRelayUrl =
      'https://dsh-relay-production.up.railway.app';

  factory AppConfig.fromEnvironment({String? savedRelayUrl}) {
    final config = AppConfig(
      relayBaseUrl:
          savedRelayUrl ??
          const String.fromEnvironment(
            'DSH_RELAY_URL',
            defaultValue: productionRelayUrl,
          ),
      useMock: const bool.fromEnvironment('DSH_USE_MOCK', defaultValue: false),
    );
    const isRelease = bool.fromEnvironment('dart.vm.product');
    config.validate(isRelease: isRelease);
    return config;
  }

  final String relayBaseUrl;
  final bool useMock;

  Uri get relayOrigin => Uri.parse(relayBaseUrl);

  AppConfig withRelayBaseUrl(String value) => AppConfig(
    relayBaseUrl: value.trim().replaceFirst(RegExp(r'/+$'), ''),
    useMock: false,
  );

  void validate({required bool isRelease}) {
    final relay = relayOrigin;
    if (!relay.hasScheme || relay.host.isEmpty) {
      throw StateError('DSH_RELAY_URL must be an absolute Relay URL.');
    }
    if (isRelease && relay.scheme != 'https') {
      throw StateError('Release builds require an HTTPS Relay.');
    }
    if (isRelease && useMock) {
      throw StateError('Release builds cannot enable Mock Relay.');
    }
  }
}
