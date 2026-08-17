import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release version and Android version code stay aligned', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    final major = int.parse(match!.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);
    final buildNumber = int.parse(match.group(4)!);
    expect(buildNumber, major * 1000000 + minor * 1000 + patch);

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(
      gradle,
      contains('versionCode = stableAndroidVersionCode(flutter.versionName)'),
    );
  });

  test('Android backups cannot export secure preferences', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );

    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    final cloudBackup = RegExp(
      r'<cloud-backup>([\s\S]*?)</cloud-backup>',
    ).firstMatch(rules);
    final deviceTransfer = RegExp(
      r'<device-transfer>([\s\S]*?)</device-transfer>',
    ).firstMatch(rules);
    expect(
      cloudBackup?.group(1),
      contains('<exclude domain="sharedpref" path="." />'),
    );
    expect(
      deviceTransfer?.group(1),
      contains('<exclude domain="sharedpref" path="." />'),
    );
  });

  test('existing release assets are never overwritten', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    expect(workflow, isNot(contains('--clobber')));
    expect(workflow, contains('cmp --silent dist/SHA256SUMS'));
    expect(workflow, contains('sha256sum --check SHA256SUMS'));
  });
}
