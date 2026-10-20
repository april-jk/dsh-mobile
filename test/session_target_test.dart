import 'package:dsh_mobile/features/session/session_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = Uri.parse('http://127.0.0.1:4100/?bootstrap=capability');

  test('keeps the bootstrap capability while applying path and query', () {
    expect(
      sessionTargetUrl(
        start,
        '/dsh-mobile/files?lang=pl&theme=dark',
      ).toString(),
      'http://127.0.0.1:4100/dsh-mobile/files?bootstrap=capability&lang=pl&theme=dark',
    );
  });

  test('leaves the bootstrap-only start URL untouched for the DSH root', () {
    expect(
      sessionTargetUrl(start, '/').toString(),
      'http://127.0.0.1:4100/?bootstrap=capability',
    );
  });
}
