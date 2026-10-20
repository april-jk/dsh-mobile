import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'data/app_preferences_store.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/devices/device_list_page.dart';
import 'features/update/app_update_prompt.dart';

/// Seeds the language and theme providers from persisted preferences before
/// the first frame, so the app starts in the stored state.
List<Override> appPreferenceOverrides(AppPreferences preferences) => [
  appLocaleProvider.overrideWith((ref) => preferences.locale),
  appThemeProvider.overrideWith((ref) => preferences.themeMode),
];

class DshRemoteApp extends ConsumerWidget {
  const DshRemoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DSH Remote',
      locale: ref.watch(appLocaleProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: AppLocalizations.resolveLocale,
      debugShowCheckedModeBanner: false,
      theme: buildDshTheme(),
      darkTheme: buildDshTheme(brightness: Brightness.dark),
      themeMode: ref.watch(appThemeProvider),
      home: const AppUpdateCoordinator(child: AuthGate()),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return switch (auth.status) {
      AuthStatus.initializing => const _StartupScreen(),
      AuthStatus.unauthenticated => const LoginPage(),
      AuthStatus.authenticated => const DeviceListPage(),
    };
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: context.l10n.text('loading'),
          ),
        ),
      ),
    );
  }
}
