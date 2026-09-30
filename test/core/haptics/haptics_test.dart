import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/core/haptics/haptics.dart';

/// S-328(d): the seam's real implementation, against the platform channel it
/// actually talks to. The rest of the suite overrides `hapticsProvider`, so
/// this is the only place `HapticFeedback` is exercised.
void main() {
  testWidgets('SystemHaptics sends exactly one mediumImpact', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await const SystemHaptics().bucketChanged();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
  });

  testWidgets('hapticsProvider defaults to SystemHaptics', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(hapticsProvider), isA<SystemHaptics>());
  });
}
