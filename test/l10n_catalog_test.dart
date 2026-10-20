import 'dart:convert';
import 'dart:io';

import 'package:dsh_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _catalog(String languageCode) {
  final file = File('lib/l10n/$languageCode.json');
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, value as String));
}

Set<String> _placeholders(String value) {
  final matches = RegExp(r'\{(\w+)\}').allMatches(value);
  return matches.map((match) => match[1]!).toSet();
}

void main() {
  final catalogs = {
    for (final code in const ['en', 'pl', 'zh']) code: _catalog(code),
  };
  final referenceKeys = catalogs['en']!.keys.toSet();

  test('every catalog has the same keys', () {
    expect(referenceKeys, isNotEmpty);
    for (final entry in catalogs.entries) {
      expect(entry.value.keys.toSet(), referenceKeys, reason: entry.key);
    }
  });

  test('every catalog keeps the same placeholders', () {
    for (final key in referenceKeys) {
      final expected = _placeholders(catalogs['en']![key]!);
      for (final entry in catalogs.entries) {
        expect(
          _placeholders(entry.value[key]!),
          expected,
          reason: '$entry.key:$key',
        );
      }
    }
  });

  test('English and Polish catalogs stay free of Han characters', () {
    final han = RegExp(r'[\u4e00-\u9fff]');
    for (final code in const ['en', 'pl']) {
      for (final entry in catalogs[code]!.entries) {
        expect(
          han.hasMatch(entry.value),
          isFalse,
          reason: '$code:${entry.key}',
        );
      }
    }
  });

  test('locale resolution follows the system and falls back to English', () {
    final supported = AppLocalizations.supportedLocales;
    expect(
      AppLocalizations.resolveLocale(const Locale('pl', 'PL'), supported),
      const Locale('pl'),
    );
    expect(
      AppLocalizations.resolveLocale(const Locale('zh', 'CN'), supported),
      const Locale('zh'),
    );
    expect(
      AppLocalizations.resolveLocale(const Locale('de', 'DE'), supported),
      const Locale('en'),
    );
    expect(AppLocalizations.resolveLocale(null, supported), const Locale('en'));
  });
}
