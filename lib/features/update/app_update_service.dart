import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_config.dart';
import '../../core/version.dart';
import '../../data/relay_service.dart';

enum AppPlatform {
  android,
  ios;

  String get apiValue => name;
}

enum AppUpdateRequirement { none, optional, required }

class InstalledAppVersion {
  const InstalledAppVersion({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  String get displayVersion =>
      buildNumber.isEmpty ? version : '$version ($buildNumber)';
}

class AppVersionPolicy {
  const AppVersionPolicy({
    required this.latestVersion,
    required this.minimumVersion,
    this.downloadUrl,
    this.releaseNotes,
  });

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    final downloadUrl = Uri.tryParse(json['downloadUrl'] as String? ?? '');
    return AppVersionPolicy(
      latestVersion: json['latestVersion'] as String,
      minimumVersion: json['minimumVersion'] as String,
      downloadUrl: downloadUrl?.scheme == 'https' ? downloadUrl : null,
      releaseNotes: json['releaseNotes'] as String?,
    );
  }

  final String latestVersion;
  final String minimumVersion;
  final Uri? downloadUrl;
  final String? releaseNotes;
}

class AppUpdateCheck {
  const AppUpdateCheck({required this.installed, required this.policy});

  final InstalledAppVersion installed;
  final AppVersionPolicy policy;

  AppUpdateRequirement get requirement {
    if (policy.downloadUrl == null) return AppUpdateRequirement.none;
    if (compareVersions(installed.version, policy.minimumVersion) < 0) {
      return AppUpdateRequirement.required;
    }
    if (compareVersions(installed.version, policy.latestVersion) < 0) {
      return AppUpdateRequirement.optional;
    }
    return AppUpdateRequirement.none;
  }
}

class AppUpdateService {
  AppUpdateService(AppConfig config)
    : _dio = Dio(
        BaseOptions(
          baseUrl: config.relayBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

  final Dio _dio;

  Future<AppVersionPolicy> fetchPolicy(AppPlatform platform) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/app/version',
      queryParameters: {'platform': platform.apiValue},
    );
    return AppVersionPolicy.fromJson(response.data!);
  }

  void dispose() => _dio.close(force: true);
}

final appPlatformProvider = Provider<AppPlatform?>((ref) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AppPlatform.android,
    TargetPlatform.iOS => AppPlatform.ios,
    _ => null,
  };
});

final installedAppVersionProvider = FutureProvider<InstalledAppVersion>((
  ref,
) async {
  final info = await PackageInfo.fromPlatform();
  return InstalledAppVersion(
    version: info.version,
    buildNumber: info.buildNumber,
  );
});

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService(ref.watch(appConfigProvider));
  ref.onDispose(service.dispose);
  return service;
});

final appUpdateCheckProvider = FutureProvider<AppUpdateCheck?>((ref) async {
  final platform = ref.watch(appPlatformProvider);
  if (platform == null || ref.watch(appConfigProvider).useMock) return null;
  final installed = await ref.watch(installedAppVersionProvider.future);
  final policy = await ref
      .watch(appUpdateServiceProvider)
      .fetchPolicy(platform);
  return AppUpdateCheck(installed: installed, policy: policy);
});
