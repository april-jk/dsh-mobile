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
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    final rawLastSeen = json['lastSeenAt'];
    DateTime? lastSeen;
    if (rawLastSeen is int) {
      lastSeen = DateTime.fromMillisecondsSinceEpoch(rawLastSeen);
    } else if (rawLastSeen is String) {
      lastSeen = DateTime.tryParse(rawLastSeen);
    }
    return Device(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'DSH Computer',
      online: json['online'] as bool? ?? false,
      dshStatus: json['dshStatus'] as String? ?? 'offline',
      lastSeenAt: lastSeen,
    );
  }

  final String id;
  final String name;
  final bool online;
  final String dshStatus;
  final DateTime? lastSeenAt;

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
  );
}

class PairPayload {
  const PairPayload({required this.code, this.relay});

  final String code;
  final Uri? relay;
}

class WebTicket {
  const WebTicket({required this.ticket, required this.expiresIn});

  final String ticket;
  final int expiresIn;
}
