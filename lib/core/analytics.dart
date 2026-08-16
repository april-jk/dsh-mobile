import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsProvider = Provider<Analytics>((ref) => const DebugAnalytics());

abstract interface class Analytics {
  void track(String event, [Map<String, Object?> properties = const {}]);
}

class DebugAnalytics implements Analytics {
  const DebugAnalytics();

  @override
  void track(String event, [Map<String, Object?> properties = const {}]) {
    debugPrint('analytics:$event $properties');
  }
}
