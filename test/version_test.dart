import 'package:dsh_mobile/core/version.dart';
import 'package:dsh_mobile/features/update/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares dotted and prerelease versions', () {
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('1.0.0-beta', '1.0.0'), lessThan(0));
    expect(compareVersions('v2.0.0+12', '2.0.0'), 0);
  });

  test('requires updates below minimum and suggests newer releases', () {
    final policy = AppVersionPolicy(
      latestVersion: '2.0.0',
      minimumVersion: '1.5.0',
      downloadUrl: Uri.parse('https://example.com/app'),
    );
    expect(
      AppUpdateCheck(
        installed: const InstalledAppVersion(
          version: '1.4.9',
          buildNumber: '1',
        ),
        policy: policy,
      ).requirement,
      AppUpdateRequirement.required,
    );
    expect(
      AppUpdateCheck(
        installed: const InstalledAppVersion(
          version: '1.9.0',
          buildNumber: '1',
        ),
        policy: policy,
      ).requirement,
      AppUpdateRequirement.optional,
    );
  });

  test('does not prompt without a configured download URL', () {
    const policy = AppVersionPolicy(
      latestVersion: '2.0.0',
      minimumVersion: '2.0.0',
    );
    expect(
      const AppUpdateCheck(
        installed: InstalledAppVersion(version: '1.0.0', buildNumber: '1'),
        policy: policy,
      ).requirement,
      AppUpdateRequirement.none,
    );
  });

  test('rejects non-HTTPS update destinations', () {
    final policy = AppVersionPolicy.fromJson({
      'latestVersion': '2.0.0',
      'minimumVersion': '1.0.0',
      'downloadUrl': 'http://example.com/app',
      'releaseNotes': null,
    });
    expect(policy.downloadUrl, isNull);
  });
}
