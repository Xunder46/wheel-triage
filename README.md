# Wheel Triage

A journal and calculator for options traders running the **wheel strategy**
(sell cash-secured puts → take assignment → sell covered calls → repeat).

Wheel Triage does three things:

1. **Screen** a candidate trade against thresholds you set.
2. **Triage** your open positions into four buckets — **Close**, **Roll**,
   **Assign**, **Leave** — by plain arithmetic, always showing the reason that
   put a position in its bucket.
3. **Record** what happened: rolls, assignments, expirations, fees and cycle
   P&L, in a journal you can export.

> Wheel Triage is a journal and calculator for your own options trades. It
> keeps a record of what you enter and checks those numbers against the
> thresholds you set. It is not investment advice. It has no market data
> connection and no view on any security.

## Design principles

- **You type the numbers in.** There are no quote APIs, no broker
  integration and no scraping. The app works entirely from what you enter.
- **A calculator, not an advisor.** It has no opinion on any security and
  makes no predictions. Bucket names are neutral verbs, and every result
  shows the rule that fired it.
- **Your data stays on your device.** No accounts, no backend, no sync, no
  analytics, crash-reporting or ad SDKs. See [docs/privacy.md](docs/privacy.md).
- **Exact money math.** Prices, credits and P&L use `Decimal` end to end, so
  a 50% profit target fires at exactly 50%, not at 49.999999%.

## Features

| Feature | Free | Pro |
|---|:---:|:---:|
| Trade screener with a sorting score | ✓ | ✓ |
| Position triage (Close / Roll / Assign / Leave) | ✓ | ✓ |
| Roll planner (net credit / debit, IV-adjusted roll band) | ✓ | ✓ |
| Assignment flow, wheel basis and tax basis | ✓ | ✓ |
| Journal with cycle P&L, fees and peak capital committed | ✓ | ✓ |
| Editable, versioned rule thresholds | ✓ | ✓ |
| Expiration notifications, export / import | ✓ | ✓ |
| Share card (an exported image) | ✓ | ✓ |
| Open wheel cycles | up to 3 | unlimited |
| Full portfolio view and assignment calendar | summary only | ✓ |

Pro is available monthly, annually or as a one-time lifetime unlock, through
the App Store. Nothing you have already recorded is ever locked.

Rule thresholds are versioned: every position remembers the version it was
opened under, so editing a threshold never silently re-classifies history.

## Status

The core app (screener, triage, roll planner, journal, portfolio, share card)
is built and tested. The Pro release is in progress — see
[docs/brief-pro.md](docs/brief-pro.md) for the roadmap, including on-device
screenshot scan, broker CSV import and Android. iOS ships first.

## Building from source

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart `^3.11.5`) and, for iOS, Xcode on macOS.

```bash
flutter pub get
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

```bash
flutter run
```

Checks:

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter build ios --simulator --no-codesign
```

Golden tests are rendered on macOS and may differ on other operating systems.

## Project layout

```
lib/domain/rules/   pure Dart rules engine — formulas, classify(), thresholds
lib/domain/models/  persisted data classes (freezed + json_serializable)
lib/data/           WheelRepository with Drift (SQLite) and in-memory implementations
lib/state/          Riverpod controllers
lib/features/       screens (today, screener, roll, journal, portfolio, …)
lib/widgets/        shared UI
lib/core/           router, theme, purchases, notifications
```

The rules engine in `lib/domain/rules/` has no Flutter imports and every
function is pure (the current time is always passed in), so the triage logic
is fully deterministic and testable. Both repository implementations run
against one shared contract test suite.

Built with Flutter, Riverpod, Drift, go_router, freezed and `decimal`.

## Documentation

- [docs/brief.md](docs/brief.md) — the original specification, followed by
  [brief-followup.md](docs/brief-followup.md),
  [brief-ledger.md](docs/brief-ledger.md) and
  [brief-pro.md](docs/brief-pro.md)
- [docs/conventions.md](docs/conventions.md) — binding code conventions
- [docs/architecture/wheel-triage.md](docs/architecture/wheel-triage.md) —
  architecture overview
- [docs/plans/](docs/plans/) — implementation plans and the scenario
  register (`S-001`, `S-002`, …) that tests are named after
- [docs/privacy.md](docs/privacy.md) — what leaves the device and what never
  does

## Contributing

Bug reports and suggestions are welcome as GitHub issues. Pull requests are
not accepted.

## License

Copyright © 2026 Xunder46. All rights reserved.

The source is published for viewing only. No permission is granted to copy,
modify, distribute, sublicense or sell any part of it, or to publish an app
built from it.
