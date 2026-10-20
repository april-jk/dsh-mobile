import 'package:dsh_mobile/features/settings/remote_files_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the file browser path carries the app language and theme', () {
    expect(
      remoteFilesPath(languageCode: 'pl', dark: true),
      '/dsh-mobile/files?lang=pl&theme=dark',
    );
    expect(
      remoteFilesPath(languageCode: 'en', dark: false),
      '/dsh-mobile/files?lang=en&theme=light',
    );
    expect(
      remoteFilesPath(languageCode: 'zh', dark: false),
      '/dsh-mobile/files?lang=zh&theme=light',
    );
  });
}
