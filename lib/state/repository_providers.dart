import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wheel_repository.dart';

/// The single source of a [WheelRepository] for the whole app. Deliberately
/// has no default implementation — every entrypoint must override it
/// explicitly:
///
/// * `lib/main.dart` overrides it with `DriftWheelRepository`.
/// * Every test's `ProviderScope` overrides it with `InMemoryWheelRepository`.
///
/// This way a screen can never be accidentally wired to a repository nobody
/// chose on purpose, and `lib/state/`/`lib/features/` never import a
/// concrete storage implementation directly (`docs/conventions.md` §6).
final wheelRepositoryProvider = Provider<WheelRepository>((ref) {
  throw UnimplementedError(
    'wheelRepositoryProvider has no default implementation. Override it in '
    "main.dart's ProviderScope (DriftWheelRepository) or in a test's "
    'ProviderScope (InMemoryWheelRepository).',
  );
});
