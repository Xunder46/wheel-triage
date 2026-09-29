import '../models/leg.dart';
import '../models/snapshot.dart';

/// Where the IV value fed to Gate 3 (`rollBandFor`, inside `classify()`)
/// came from (brief-followup A3; Q9 in Iteration 3's Q&A round). Scoped to
/// the roll-band resolution only — `oneSigmaMove`'s own IV source is
/// unchanged and never consults this order (Feature Invariant 18).
enum IvSource { snapshotIv, legIvAtOpen, profileDefault }

/// [resolveIv]'s result: the resolved IV value (`null` only when neither the
/// snapshot nor the leg has one, i.e. [IvSource.profileDefault]) paired with
/// which source produced it, so callers can render the source-aware label
/// from Feature Invariant 18 without re-deriving the resolution order
/// themselves.
class ResolvedIv {
  final double? value;
  final IvSource source;

  const ResolvedIv({required this.value, required this.source});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResolvedIv && other.value == value && other.source == source);

  @override
  int get hashCode => Object.hash(value, source);

  @override
  String toString() => 'ResolvedIv(value: $value, source: $source)';
}

/// Resolution order (Feature Invariant 18): the most recent [snapshot]'s
/// `iv` -> [leg]'s `ivAtOpen` -> `null` (profile default). This is a
/// **classification-behavior** function, not a display-only one — both
/// `lib/state/today/today_controller.dart` and
/// `position_detail_controller.dart` call this *before* constructing a
/// `TriageInput` and feed the resolved `.value` into `TriageInput.iv`,
/// never `snapshot?.iv` directly (brief-followup A3; a blank IV on a real
/// snapshot must not silently drop to the base roll band when the leg was
/// opened at a known high IV).
ResolvedIv resolveIv({required Snapshot? snapshot, required Leg leg}) {
  final snapshotIv = snapshot?.iv;
  if (snapshotIv != null) {
    return ResolvedIv(value: snapshotIv, source: IvSource.snapshotIv);
  }
  final legIv = leg.ivAtOpen;
  if (legIv != null) {
    return ResolvedIv(value: legIv, source: IvSource.legIvAtOpen);
  }
  return const ResolvedIv(value: null, source: IvSource.profileDefault);
}

/// The exact source-aware "Roll band in use" display templates from Feature
/// Invariant 18 — the middle one is the brief's own example, kept verbatim;
/// the other two are coined to match its register. [band] is
/// `profile.rollBandFor`'s already-computed result for [resolvedIv].
String rollBandLabel({required double band, required ResolvedIv resolvedIv}) {
  final bandText = band.toStringAsFixed(2);
  return switch (resolvedIv.source) {
    IvSource.snapshotIv =>
      "$bandText — from this snapshot's IV (${_trimmedPct(resolvedIv.value!)}%)",
    IvSource.legIvAtOpen =>
      '$bandText — from IV at open (${_trimmedPct(resolvedIv.value!)}%)',
    IvSource.profileDefault => '$bandText — no IV on file',
  };
}

/// Trims trailing zeros the same way `classify.dart`'s `_fmtMagnitude` does
/// (`83.0` -> `"83"`, `87.61` -> `"87.61"`), so a whole-number IV doesn't
/// render as `"83.0000"`.
String _trimmedPct(double value) {
  var s = value.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
