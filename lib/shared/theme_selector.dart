import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/app_preferences_store.dart';
import '../l10n/app_localizations.dart';

/// Frame-less theme control for the settings card: the card is the only
/// surface, so the control must not add its own border or fill.
///
/// The same value drives the app theme and the remote file browser opened from
/// settings.
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeProvider);
    final l10n = context.l10n;
    return DropdownButtonHideUnderline(
      child: DropdownButton<ThemeMode>(
        key: ValueKey('theme-${mode.name}'),
        value: mode,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        items: [
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text(l10n.text('themeLight')),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text(l10n.text('themeDark')),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          ref.read(appThemeProvider.notifier).state = value;
          // Persistence is best effort: the current session already switched.
          ref.read(appPreferencesStoreProvider).writeThemeMode(value).ignore();
        },
      ),
    );
  }
}
