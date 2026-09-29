/// The RevenueCat public SDK key for the iOS app (Pro Wave 2, D-27/D-P3).
///
/// **This constant is empty in the repository, on purpose.** The key is passed
/// in at build time, so it is never committed and a checked-out tree can never
/// reach a real store account by accident:
///
/// ```
/// flutter build ios --simulator --no-codesign \
///   --dart-define=REVENUECAT_IOS_API_KEY=<the owner's public iOS key>
/// ```
///
/// `lib/main.dart` reads it once and chooses the gateway from it: a build with
/// no key gets `UnconfiguredPurchaseGateway`, which shows the free tier and
/// offers nothing for sale — never a broken paywall, and never a silent
/// purchase attempt against nothing.
const String kRevenueCatIosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
