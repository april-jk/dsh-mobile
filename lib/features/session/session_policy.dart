import '../../domain/models.dart';

const dshMobileFontCss = '''
:root {
  --dsw-font-family: "PingFang SC", "Apple Color Emoji", "Apple Symbols", -apple-system, BlinkMacSystemFont, "Hiragino Sans GB", sans-serif !important;
  --ds-font-family-code: "SF Mono", "PingFang SC", "Apple Color Emoji", Menlo, monospace !important;
}
html, body, button, input, textarea, select {
  font-family: var(--dsw-font-family) !important;
}
code, pre, kbd, samp {
  font-family: var(--ds-font-family-code) !important;
}
''';

String dshFontBootstrapScript() {
  final css = dshMobileFontCss
      .replaceAll(r'\', r'\\')
      .replaceAll('`', r'\`')
      .replaceAll(r'${', r'\${');
  return '''
(() => {
  const style = document.createElement('style');
  style.id = 'dsh-mobile-font-fallback';
  style.textContent = `$css`;
  (document.head || document.documentElement).appendChild(style);
})();
''';
}

enum SessionNavigation { session, external, blocked }

enum SessionHttpAction {
  ignore,
  renewTicket,
  refreshDeviceStatus,
  tunnelTimeout,
  failed,
}

class TicketRenewalGuard {
  bool _used = false;

  bool take() {
    if (_used) return false;
    _used = true;
    return true;
  }

  void reset() => _used = false;
}

bool isSameOrigin(Uri uri, Uri sessionOrigin) {
  return uri.scheme == sessionOrigin.scheme &&
      uri.host == sessionOrigin.host &&
      _effectivePort(uri) == _effectivePort(sessionOrigin);
}

SessionNavigation classifySessionNavigation(Uri uri, Uri sessionOrigin) {
  if (isSameOrigin(uri, sessionOrigin)) return SessionNavigation.session;
  if (const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
    return SessionNavigation.external;
  }
  return SessionNavigation.blocked;
}

SessionHttpAction sessionHttpAction(int? statusCode) {
  return switch (statusCode) {
    401 => SessionHttpAction.renewTicket,
    503 => SessionHttpAction.refreshDeviceStatus,
    504 => SessionHttpAction.tunnelTimeout,
    final status when status != null && status >= 400 =>
      SessionHttpAction.failed,
    _ => SessionHttpAction.ignore,
  };
}

DeviceAvailability? latestDeviceAvailability(
  Iterable<Device> devices,
  String deviceId,
) {
  return devices
      .where((device) => device.id == deviceId)
      .firstOrNull
      ?.availability;
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return uri.scheme == 'https' ? 443 : 80;
}
