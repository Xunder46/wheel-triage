# Privacy

Wheel Triage is a journal and calculator for one person's own trades. There is
no account, no backend and no sync: the app writes to a local database on the
device and reads market data only from what the user types. This file is the
source the App Store Connect privacy label and the hosted policy are written
from (D-36), so it states what leaves the device, what never does, and what is
still outstanding.

## What leaves the device

**Nothing about a trade.** The only outbound traffic the app makes is the store
request needed to know whether Pro is active, and the store's own purchase
flow. That traffic is handled by RevenueCat's SDK (`purchases_flutter`), and it
carries:

- **Purchase history** — the App Store receipt and the transactions within it,
  so the store's answer about the `pro` entitlement can be verified and
  restored. This is what RevenueCat collects, and it is the store's own record
  of the purchase, not something the app composes.
- **An app-scoped identifier** — RevenueCat's anonymous app user id, generated
  per install. The app sets no custom identifier, so it is not tied to a name,
  an email or an account of any kind: there is no account to tie it to.
- **Device and app metadata** — the platform, OS version, app version, locale
  and a device model string, as the store request requires.

RevenueCat's handling of that data is described in its own privacy policy,
which the owner must host a link to alongside this one.

## What never leaves the device

- **No trade, leg, cycle, snapshot, underlying or ledger row.** The store seam
  is six methods and takes one argument, a product-id `String`
  (`lib/core/purchases/purchase_gateway.dart`); it has no way to express a
  trade. `test/core/purchases/recording_gateway_isolation_test.dart` (S-288)
  records every call the seam makes and asserts that a product id is the only
  value that ever crosses it.
- **No screenshots and no images.** The screenshot scan (Pro Stage 6) reads a
  picture the user picks, on the device, and is not built yet. Nothing in this
  wave sends or stores an image.
- **No share card content.** The share card (Pro D-P7) is an image the user
  exports; it is generated on the device and handed to the system share sheet.
- **No exported file.** Export and import (Iteration 4) write a JSON file to a
  location the user chooses. The file is never uploaded by the app.
- **No analytics, no crash reporting, no advertising SDK.** None is present in
  `pubspec.yaml`, and none is planned.
- **No market-data request of any kind.** There is no quote API, no broker
  connection and no scraping anywhere in the app. Every price in it was typed
  by the user or read from a screenshot they picked.

The app also does not read the device's contacts, photos, location, camera or
microphone. The only permission it asks for is notification delivery, for the
expiration reminders the user configures, and refusing it changes nothing
except whether those reminders fire.

## What the app shows the user

The paywall carries this sentence, verbatim
(`lib/core/purchases/paywall_copy.dart`, `kPaywallPrivacyLine`):

> Your trades never leave your phone. Purchases go through the App Store, with
> no account to create.

The app's persistent disclaimer (`lib/core/disclaimer.dart`, D-P15) is a
separate statement about the app being a calculator rather than advice, and it
is unrelated to this file.

## Still the owner's to do

These are not agent tasks; they are recorded here so they are not lost.

1. **The App Store Connect privacy label.** Fill it in against this file:
   RevenueCat's purchase-history and identifier collection is declared as
   "Purchase History" and "Identifiers", used for app functionality, and **not**
   linked to the user's identity (there is no identity to link it to) and not
   used for tracking.
2. **A hosted privacy policy and Terms of Use page.** The paywall renders both
   as `SelectableText` rather than tappable links this wave, because opening a
   URL needs `url_launcher` and D-P3 pre-approves only `purchases_flutter`
   (D-37). Terms of Use defaults to Apple's standard EULA URL; the Privacy
   Policy URL is the empty constant `kPrivacyPolicyUrl` in
   `lib/core/purchases/pro_plans.dart`, and **its entry stays hidden until that
   constant is filled in** — so the hosted page must exist before the URL is
   added.
3. **The App Privacy answers in App Store Connect for the review notes**, so a
   reviewer reading this file and the label sees the same story.

## The build command

The RevenueCat public key is never committed. The owner's build passes it in:

```
flutter build ios --simulator --no-codesign \
  --dart-define=REVENUECAT_IOS_API_KEY=<the owner's public iOS key>
```

A build without that define runs the free tier with nothing for sale and makes
no store request at all (`UnconfiguredPurchaseGateway`), so a checked-out tree
cannot reach a real store account by accident.
