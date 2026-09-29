import 'package:decimal/decimal.dart';

import '../models/leg.dart';
import '../models/snapshot.dart';
import 'bucket.dart';
import 'classify.dart';
import 'formulas.dart' as formulas;
import 'iv_resolution.dart';
import 'rule_profile.dart';
import 'triage_input.dart';

/// The `id`/`legId` carried by the preview's transient [Snapshot]. It is
/// never persisted and never looked up, so the value only has to be
/// recognisable if one ever appears in a log.
const String _previewSnapshotId = 'preview';

/// What the numbers currently in the sheet *would* produce, computed before
/// anything is saved (Pro Wave 1 D-17).
///
/// Everything here is derived by the rules engine — this class only carries
/// the result, so no widget re-derives a threshold, a band or a captured
/// percentage to render the preview card.
class SnapshotPreview {
  /// The bucket the entered numbers produce — never a "would be" variant:
  /// it is `classify()`'s own output for a transient snapshot.
  final Bucket bucket;

  /// Leg-level captured percentage for the entered mark (Feature Invariant 1).
  final Decimal? capturedPct;

  /// The roll band the leg's pinned profile gives the resolved IV.
  final double? rollBand;

  /// Where that IV came from (Feature Invariant 18) — `snapshotIv` for a
  /// typed IV, `legIvAtOpen` when the field is cleared, `profileDefault`
  /// when there is neither.
  final ResolvedIv resolvedIv;

  final Decimal? extrinsic;

  /// The leg's latest saved reading, or `null` before the first one. Used
  /// only for the change line and its date.
  final Snapshot? latestSnapshot;

  /// The bucket the leg is in right now, per its latest saved reading.
  final Bucket currentBucket;

  const SnapshotPreview({
    required this.bucket,
    required this.capturedPct,
    required this.rollBand,
    required this.resolvedIv,
    required this.extrinsic,
    required this.latestSnapshot,
    required this.currentBucket,
  });

  /// The Feature Invariant 18 source-aware band label, e.g.
  /// `"0.30 — from this snapshot's IV (21%)"`.
  String get rollBandLabelText => rollBandLabel(band: rollBand!, resolvedIv: resolvedIv);

  /// True when the preview's verdict differs from the leg's current one.
  bool get changesBucket => bucket.runtimeType != currentBucket.runtimeType;

  /// "Was Leave on the Sep 17 reading" — one line, only when the preview
  /// changes the verdict **and** there is a previous reading to name.
  /// A leg with no reading yet is in `No data`, which is the absence of a
  /// verdict rather than one worth contrasting with.
  String? get changeLine {
    final previous = latestSnapshot;
    if (previous == null || !changesBucket) return null;
    return 'Was ${bucketLabel(currentBucket)} on the ${_monthDay(previous.takenAt)} reading';
  }
}

/// D-17's pure preview: builds a transient [Snapshot] from the sheet's
/// values, assembles the same [TriageInput] the live classifications use
/// (one implementation, three callers — S-227) and calls `classify()` with
/// [profile], which the caller resolves from the leg's **pinned** version.
///
/// [now] is real `now`, never a backdated `takenAt`: classification's DTE is
/// always `expiration - now` (Feature Invariant 7), exactly as
/// `position_detail_controller.dart` computes it.
///
/// Nothing here is written anywhere — the preview is a question, not a save.
SnapshotPreview buildSnapshotPreview({
  required Leg leg,
  required RuleProfile profile,
  required DateTime now,
  required Decimal optionMark,
  required Decimal underlyingPrice,
  required double deltaAsEntered,
  required DeltaConvention deltaConvention,
  double? iv,
  Snapshot? latestSnapshot,
}) {
  final dte = formulas.dte(leg.expiration, now);
  final preview = Snapshot(
    id: _previewSnapshotId,
    legId: leg.id,
    takenAt: now,
    optionMark: optionMark,
    underlyingPrice: underlyingPrice,
    deltaAsEntered: deltaAsEntered,
    deltaConvention: deltaConvention,
    iv: iv,
  );
  final resolved = resolveIv(snapshot: preview, leg: leg);
  return SnapshotPreview(
    bucket: classify(triageInputFor(leg: leg, snapshot: preview, dte: dte), profile),
    capturedPct: formulas.capturedPct(openCredit: leg.openCreditPerShare, currentMark: optionMark),
    rollBand: profile.rollBandFor(resolved.value),
    resolvedIv: resolved,
    extrinsic: formulas.extrinsic(
      currentMark: optionMark,
      intrinsic: formulas.intrinsic(optionType: leg.optionType, strike: leg.strike, spot: underlyingPrice),
    ),
    latestSnapshot: latestSnapshot,
    currentBucket: classify(triageInputFor(leg: leg, snapshot: latestSnapshot, dte: dte), profile),
  );
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthDay(DateTime date) => '${_months[date.month - 1]} ${date.day}';
