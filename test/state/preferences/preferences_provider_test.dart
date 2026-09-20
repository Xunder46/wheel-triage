import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wheel_triage/data/in_memory_wheel_repository.dart';
import 'package:wheel_triage/domain/models/snapshot.dart';
import 'package:wheel_triage/state/preferences/preferences_provider.dart';
import 'package:wheel_triage/state/repository_providers.dart';

void main() {
  group('PreferencesController -- the one shared preferences source', () {
    late InMemoryWheelRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = InMemoryWheelRepository();
      container = ProviderContainer(overrides: [wheelRepositoryProvider.overrideWithValue(repo)]);
      container.listen(preferencesControllerProvider, (previous, next) {});
    });

    tearDown(() => container.dispose());

    test('loads the seeded defaults', () async {
      await container.read(preferencesControllerProvider.notifier).ready;
      final prefs = container.read(preferencesControllerProvider).value!;
      expect(prefs.totalPerContractToggle, isFalse);
      expect(prefs.deltaConventionDefault, DeltaConvention.position);
      expect(prefs.firstRunExplainerShown, isFalse);
      expect(prefs.ivResolutionNoticeDismissed, isFalse);
    });

    test('update persists and is visible from a fresh read via the repository', () async {
      final controller = container.read(preferencesControllerProvider.notifier);
      await controller.ready;
      await controller.update((p) => p.copyWith(totalPerContractToggle: true));

      final state = container.read(preferencesControllerProvider).value!;
      expect(state.totalPerContractToggle, isTrue);

      // Round-trips through the repository, not just held in local state.
      final reread = await repo.getPreferences();
      expect(reread.totalPerContractToggle, isTrue);
    });
  });
}
