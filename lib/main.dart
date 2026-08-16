import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'data/relay_config_store.dart';
import 'data/relay_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final relayConfigStore = SecureRelayConfigStore();
  final config = AppConfig.fromEnvironment(
    savedRelayUrl: await relayConfigStore.readRelayUrl(),
  );
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith((ref) => config),
        relayConfigStoreProvider.overrideWithValue(relayConfigStore),
      ],
      child: const DshRemoteApp(),
    ),
  );
}
