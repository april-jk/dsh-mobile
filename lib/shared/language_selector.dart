import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_preferences_store.dart';
import '../l10n/app_localizations.dart';

/// Frame-less language control for the settings card: the card is the only
/// surface, so the control must not add its own border or fill.
///
/// Language names are catalog entries so the selector itself stays localized.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appLocaleProvider);
    final l10n = context.l10n;
    // An OS locale we do not ship (or a stale value) must not leave the
    // dropdown without a matching item; show "system" in that case.
    const shipped = {'en', 'pl', 'zh'};
    final code = selected?.languageCode;
    final value = code != null && shipped.contains(code) ? code : 'system';
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: ValueKey('language-$value'),
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        items: [
          DropdownMenuItem(
            value: 'system',
            child: Text(l10n.text('systemLanguage')),
          ),
          DropdownMenuItem(
            value: 'en',
            child: Text(l10n.text('languageEnglish')),
          ),
          DropdownMenuItem(
            value: 'pl',
            child: Text(l10n.text('languagePolish')),
          ),
          DropdownMenuItem(
            value: 'zh',
            child: Text(l10n.text('languageChinese')),
          ),
        ],
        onChanged: (value) {
          final locale = value == null || value == 'system'
              ? null
              : Locale(value);
          ref.read(appLocaleProvider.notifier).state = locale;
          // Persistence is best effort: the current session already switched.
          ref.read(appPreferencesStoreProvider).writeLocale(locale).ignore();
        },
      ),
    );
  }
}
