class AppConfig {
  const AppConfig({required this.relayBaseUrl, required this.useMock});

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      relayBaseUrl: String.fromEnvironment(
        'DSH_RELAY_URL',
        defaultValue: 'http://127.0.0.1:8787',
      ),
      useMock: bool.fromEnvironment('DSH_USE_MOCK', defaultValue: true),
    );
  }

  final String relayBaseUrl;
  final bool useMock;

  Uri get relayOrigin => Uri.parse(relayBaseUrl);
}
