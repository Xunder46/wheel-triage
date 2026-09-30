import 'package:wheel_triage/core/haptics/haptics.dart';

/// A recording [Haptics] test double -- the haptics analogue of
/// `FakePurchaseGateway`, so a widget test can assert *that* the feedback
/// fired without touching a platform channel.
///
/// It lives in `test/support/` because two suites need it: the snapshot
/// sheet's (S-322...S-326) and Today's cross-screen liveness (S-331).
class RecordingHaptics implements Haptics {
  /// Every call, in order, as the method name.
  final List<String> calls = [];

  @override
  Future<void> bucketChanged() async {
    calls.add('bucketChanged');
  }
}
