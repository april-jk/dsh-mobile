import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../domain/models.dart';

/// Null follows the operating system. The active value is seeded from the
/// persisted preferences store before the first frame.
final appLocaleProvider = StateProvider<Locale?>((ref) => null);

/// The JSON catalogs are the sole owner of application-authored display copy.
class AppLocalizations {
  AppLocalizations(this.locale, this._messages);

  final Locale locale;
  final Map<String, String> _messages;
  static const supportedLocales = [Locale('en'), Locale('pl'), Locale('zh')];
  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static final Map<String, AppLocalizations> _loaded = {};

  /// Loads every catalog before the first frame so locale switches are
  /// synchronous and a missing asset fails at startup, not mid-build.
  static Future<void> preload() async {
    for (final locale in supportedLocales) {
      final code = locale.languageCode;
      _loaded[code] ??= await _read(locale);
    }
  }

  static Future<AppLocalizations> _read(Locale locale) async {
    final source = await rootBundle.loadString(
      'lib/l10n/${locale.languageCode}.json',
    );
    return AppLocalizations(
      locale,
      Map<String, String>.from(jsonDecode(source) as Map),
    );
  }

  static Locale resolveLocale(Locale? locale, Iterable<Locale> supported) =>
      supported.firstWhere(
        (item) => item.languageCode == locale?.languageCode,
        orElse: () => const Locale('en'),
      );

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static Future<AppLocalizations> load(Locale requested) async {
    final locale = resolveLocale(requested, supportedLocales);
    final cached = _loaded[locale.languageCode];
    if (cached != null) return cached;
    return _read(locale);
  }

  String text(String key, [Map<String, Object> arguments = const {}]) {
    // Catalogs are test-enforced to be complete; an unknown key must never
    // crash a screen at runtime, so the key itself is shown instead.
    final template = _messages[key] ?? key;
    return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final name = match[1]!;
      return arguments.containsKey(name)
          ? arguments[name].toString()
          : match.group(0)!;
    });
  }

  /// Never render arbitrary backend prose or diagnostic exceptions to users.
  String error(Object error) {
    if (error is! ApiException) return text('networkError');
    final key = switch (error.code) {
      'invalid_credentials' => 'invalidCredentials',
      'email_exists' => 'emailExists',
      'invalid_refresh_token' => 'sessionExpired',
      'invalid_or_expired_code' => 'invalidCode',
      'forbidden' => 'forbidden',
      'not_found' => 'notFound',
      'relay_mismatch' => 'relayMismatch',
      'e2ee_pairing_required' => 'encryptedQrRequired',
      'e2ee_required' => 'encryptionRequired',
      'device_offline' => 'computerOffline',
      'dsh_offline' => 'dshOffline',
      'tunnel_timeout' => 'timeoutTitle',
      'network_error' => 'networkError',
      _ => 'requestFailed',
    };
    return text(key);
  }

  String deviceName(Device device) => device.displayNameKey == null
      ? device.name
      : text(device.displayNameKey!);

  String relativeTime(DateTime time, {DateTime? now}) {
    final difference = (now ?? DateTime.now()).difference(time);
    if (difference.inMinutes < 1) return text('justNow');
    final minutes = difference.inHours < 1;
    final count = minutes ? difference.inMinutes : difference.inHours;
    final category = count == 1
        ? 'One'
        : (locale.languageCode == 'pl' &&
              count % 10 >= 2 &&
              count % 10 <= 4 &&
              !(count % 100 >= 12 && count % 100 <= 14))
        ? 'Few'
        : 'Many';
    return text('${minutes ? 'minutes' : 'hours'}Ago$category', {
      'count': count,
    });
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) {
    final resolved = AppLocalizations.resolveLocale(
      locale,
      AppLocalizations.supportedLocales,
    );
    final cached = AppLocalizations._loaded[resolved.languageCode];
    return cached != null
        ? SynchronousFuture(cached)
        : AppLocalizations.load(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
