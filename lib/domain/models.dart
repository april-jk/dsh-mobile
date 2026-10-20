enum DeviceAvailability { online, dshOffline, offline }

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
}

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.online,
    required this.dshStatus,
    this.lastSeenAt,
    this.displayNameKey,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    final rawLastSeen = json['lastSeenAt'];
    DateTime? lastSeen;
    if (rawLastSeen is int) {
      lastSeen = DateTime.fromMillisecondsSinceEpoch(rawLastSeen);
    } else if (rawLastSeen is String) {
      lastSeen = DateTime.tryParse(rawLastSeen);
    }
    final rawName = (json['name'] as String?)?.trim();
    return Device(
      id: json['id'] as String,
      name: rawName ?? '',
      online: json['online'] as bool? ?? false,
      dshStatus: json['dshStatus'] as String? ?? 'offline',
      lastSeenAt: lastSeen,
      displayNameKey: rawName == null || rawName.isEmpty
          ? 'defaultComputer'
          : null,
    );
  }

  final String id;
  final String name;
  final bool online;
  final String dshStatus;
  final DateTime? lastSeenAt;

  /// Stable catalog key for app-authored placeholder names, never user data.
  final String? displayNameKey;

  DeviceAvailability get availability {
    if (!online) return DeviceAvailability.offline;
    if (dshStatus != 'online') return DeviceAvailability.dshOffline;
    return DeviceAvailability.online;
  }

  Device copyWith({String? name}) => Device(
    id: id,
    name: name ?? this.name,
    online: online,
    dshStatus: dshStatus,
    lastSeenAt: lastSeenAt,
    // A user-assigned name always wins over the placeholder catalog key.
    displayNameKey: name == null ? displayNameKey : null,
  );
}

class PairPayload {
  const PairPayload({required this.code, required this.e2eeKey, this.relay});

  final String code;
  final String e2eeKey;
  final Uri? relay;
}

class WebTicket {
  const WebTicket({
    required this.ticket,
    required this.expiresIn,
    required this.accessSessionId,
    required this.tunnelUrl,
  });

  final String ticket;
  final int expiresIn;
  final String accessSessionId;
  final Uri tunnelUrl;
}
