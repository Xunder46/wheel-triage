import 'dart:convert';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/export/ledger_csv.dart';
import '../../data/wheel_repository.dart';
import '../preferences/preferences_provider.dart';
import '../repository_providers.dart';

/// Orchestrates Settings' export/import actions (`docs/brief-ledger.md` §5,
/// Phase 20). The actual JSON/CSV generation and the replace-all restore
/// already live on `WheelRepository`/`buildClosedCyclesCsv` (Phase 19) --
/// this controller's only job is calling them, plus updating
/// `user_preferences.lastExportAt` through `PreferencesController` (the one
/// place that preference is ever written), so `SettingsScreen` itself never
/// imports `WheelRepository` directly -- every other screen in this app
/// already goes through a controller, never the repository, and this keeps
/// that rule intact for the one new persistence surface this phase adds UI
/// for.
class ExportController {
  ExportController(this._ref, this._repo);

  final Ref _ref;
  final WheelRepository _repo;

  /// The exact count `restoreFromJson` would destroy -- read before showing
  /// the hard confirmation (S-151, S-162).
  Future<int> countCyclesForReplace() => _repo.countCyclesForReplace();

  /// Builds both export artifacts as [XFile]s ready for `share_plus`,
  /// constructed entirely in memory (`XFile.fromData`) -- no manual temp
  /// file is written here; `share_plus`'s own platform implementation
  /// materializes a real file from the bytes only if/when the OS share
  /// sheet needs one. Does NOT touch `lastExportAt` -- call
  /// [recordExportSucceeded] only after the caller's own share action
  /// actually completes (S-161), so a cancelled/failed share sheet never
  /// records a stale "last export."
  Future<List<XFile>> buildExportFiles() async {
    final json = await _repo.exportToJson();
    final csv = await buildClosedCyclesCsv(_repo);
    return [
      XFile.fromData(
        utf8.encode(json),
        mimeType: 'application/json',
        path: 'wheel-triage-export.json',
      ),
      XFile.fromData(
        utf8.encode(csv),
        mimeType: 'text/csv',
        path: 'wheel-triage-closed-cycles.csv',
      ),
    ];
  }

  Future<void> recordExportSucceeded({DateTime? now}) => _ref
      .read(preferencesControllerProvider.notifier)
      .update((p) => p.copyWith(lastExportAt: now ?? DateTime.now()));

  /// Replace-all restore (S-151/S-152/S-153). Throws
  /// `LedgerImportFormatException` on any validation failure -- the caller
  /// (`SettingsScreen`) is responsible for catching it and surfacing the
  /// message without touching any other on-screen state (S-163). Nothing
  /// here mutates a provider's `state` on failure, since
  /// `restoreFromJson` validates the whole file before writing anything
  /// (Phase 19) -- a thrown exception leaves every other screen's
  /// already-loaded data completely untouched.
  Future<void> restoreFromJson(String json) => _repo.restoreFromJson(json);
}

final exportControllerProvider = Provider<ExportController>((ref) {
  final repo = ref.watch(wheelRepositoryProvider);
  return ExportController(ref, repo);
});

/// The OS share sheet (`share_plus`), behind this project's own interface
/// (`docs/conventions.md` §6 / the architecture rule that state and screens
/// depend on an interface, never a concrete implementation) so
/// `SettingsScreen` never has to reach for the real `SharePlus.instance`
/// singleton and a test can substitute a recording fake the same way every
/// other test substitutes `InMemoryWheelRepository` for
/// `DriftWheelRepository`.
abstract class ShareSheet {
  Future<void> shareFiles(List<XFile> files, {String? subject});
}

class SharePlusShareSheet implements ShareSheet {
  @override
  Future<void> shareFiles(List<XFile> files, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(files: files, subject: subject));
  }
}

final shareSheetProvider = Provider<ShareSheet>((ref) => SharePlusShareSheet());

/// The OS file picker (`file_selector`), behind the same kind of interface
/// as [ShareSheet] and for the same reason.
abstract class ImportFilePicker {
  Future<XFile?> pickJsonFile();
}

class FileSelectorImportFilePicker implements ImportFilePicker {
  @override
  Future<XFile?> pickJsonFile() => file_selector.openFile(
    acceptedTypeGroups: const [
      file_selector.XTypeGroup(label: 'Wheel Triage export', extensions: ['json']),
    ],
  );
}

final importFilePickerProvider = Provider<ImportFilePicker>((ref) => FileSelectorImportFilePicker());
