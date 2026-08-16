import '../../domain/models.dart';

enum SessionNavigation { relay, external, blocked }

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

Uri buildSessionUrl(Uri relayOrigin, String deviceId, String ticket) {
  return relayOrigin.replace(
    path: '/s/$deviceId/',
    queryParameters: {'ticket': ticket},
  );
}

bool isSameOrigin(Uri uri, Uri relayOrigin) {
  return uri.scheme == relayOrigin.scheme &&
      uri.host == relayOrigin.host &&
      _effectivePort(uri) == _effectivePort(relayOrigin);
}

SessionNavigation classifySessionNavigation(Uri uri, Uri relayOrigin) {
  if (isSameOrigin(uri, relayOrigin)) return SessionNavigation.relay;
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
