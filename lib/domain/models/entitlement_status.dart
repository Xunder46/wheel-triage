/// The tri-valued entitlement state (Pro Wave 2, D-26).
///
/// `active` is the only value that unlocks a Pro feature. `inactive` and
/// `unknown` are both the free tier, and `unknown` is deliberately **not** a
/// third behaviour: Pro is never forged from an absent answer, and it is never
/// revoked because a read failed either — a failed read falls back to the last
/// known good state (the cache) in `lib/state/`.
///
/// * `active` — the store (or the cache) reports the entitlement. A
///   subscription in its trial, in a grace period or in billing retry is
///   `active`; a billing problem rides alongside it for display only.
/// * `inactive` — a store read **succeeded** and reported no entitlement.
/// * `unknown` — no store read has ever succeeded. Behaves exactly as
///   `inactive` everywhere, including at the free-tier gate.
///
/// Pure Dart, no imports: the status is reasoned about by `lib/state/` and
/// rendered by `lib/features/`, and it is never persisted as such — the cache
/// stores the store's own facts plus `checkedAt`, and the status is derived
/// from those on read.
enum EntitlementStatus { active, inactive, unknown }
