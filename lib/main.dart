import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'data/app_preferences_store.dart';
import 'data/relay_config_store.dart';
import 'data/relay_service.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.preload();
  final relayConfigStore = SecureRelayConfigStore();
  final preferencesStore = SecureAppPreferencesStore();
  final config = AppConfig.fromEnvironment(
    savedRelayUrl: await relayConfigStore.readRelayUrl(),
  );
  AppPreferences preferences;
  try {
    preferences = await preferencesStore.read();
  } catch (_) {
    // A preference read must never block startup; defaults remain usable.
    preferences = const AppPreferences();
  }
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith((ref) => config),
        relayConfigStoreProvider.overrideWithValue(relayConfigStore),
        appPreferencesStoreProvider.overrideWithValue(preferencesStore),
        ...appPreferenceOverrides(preferences),
      ],
      child: const DshRemoteApp(),
    ),
  );
}
