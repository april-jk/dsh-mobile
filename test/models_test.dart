import 'package:dsh_mobile/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Relay millisecond timestamps and derives status', () {
    final device = Device.fromJson({
      'id': 'dev_test',
      'name': 'Test Mac',
      'online': true,
      'dshStatus': 'offline',
      'lastSeenAt': 1786860000000,
    });

    expect(device.lastSeenAt, isNotNull);
    expect(device.availability, DeviceAvailability.dshOffline);
  });

  test('offline connection overrides stale DSH status', () {
    final device = Device.fromJson({
      'id': 'dev_test',
      'name': 'Test Mac',
      'online': false,
      'dshStatus': 'online',
      'lastSeenAt': null,
    });

    expect(device.availability, DeviceAvailability.offline);
  });
}
