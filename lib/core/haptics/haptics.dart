import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The injectable seam between the snapshot save (which decides *whether* a
/// bucket changed, D-66) and Flutter's own `HapticFeedback`. Built into the
/// framework, so this wave adds no dependency -- but it is still a seam, for
/// the same reason `NotificationGateway` and `ShareSheet` are: a test can
/// assert *that* the feedback fired, and a widget test cannot observe a real
/// vibration.
abstract class Haptics {
  /// A save that changed the bucket. Deliberately `mediumImpact`: noticeable
  /// confirmation, not `heavyImpact` (which reads as an alarm) and not
  /// `selectionClick` (which reads as a scroll tick).
  Future<void> bucketChanged();
}

class SystemHaptics implements Haptics {
  const SystemHaptics();

  @override
  Future<void> bucketChanged() => HapticFeedback.mediumImpact();
}

/// Presentation, so it has a default: a missing override means "vibrate
/// normally", not a crash -- unlike `wheelRepositoryProvider`, which throws.
final hapticsProvider = Provider<Haptics>((ref) => const SystemHaptics());
