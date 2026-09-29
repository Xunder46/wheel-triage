import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S-287 and S-265: the wave's permanent structural guards, asserted against
/// `lib/` itself rather than by a human's grep -- a future edit that adds an
/// HTTP client, a socket, a URL launcher, a second `purchases_flutter`
/// importer, a trade type in the purchase seam, or a second evaluation of the
/// free-tier limit fails here instead of in review.
void main() {
  final libFiles = _dartFilesUnder('lib');

  test('S-287: lib/ has no HTTP client, socket or URL-opening path', () {
    // The pre-wave baseline of this pattern over `lib/` is zero matches, so a
    // hit here is always a new violation rather than a pre-existing one.
    final pattern = RegExp(
      r'dart:io|package:http|HttpClient|Socket|WebSocket|NetworkImage|package:dio|url_launcher',
      caseSensitive: false,
    );
    final hits = <String>[];
    for (final file in libFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason: 'the purchase SDK is the only network path the app has',
    );
  });

  test('S-287: exactly one file imports purchases_flutter, and it imports no '
      'storage or model type', () {
    final importers = libFiles
        .where((file) => file.readAsStringSync().contains('purchases_flutter'))
        .map((file) => file.path)
        .toList();
    expect(importers, ['lib/core/purchases/revenuecat_purchase_gateway.dart']);

    final imports = _importsOf(File(importers.single));
    expect(imports.where((uri) => uri.contains('data/')), isEmpty);
    expect(imports.where((uri) => uri.contains('domain/models/')), isEmpty);
  });

  test('S-287: no screen imports the gateway or the SDK', () {
    final offenders = <String>[];
    for (final file in libFiles.where((f) => f.path.startsWith('lib/features/'))) {
      final source = _codeOf(file);
      if (source.contains('purchases_flutter') ||
          source.contains('purchase_gateway.dart') ||
          source.contains('purchaseGatewayProvider')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('S-287: main.dart always overrides purchaseGatewayProvider', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('purchaseGatewayProvider.overrideWithValue('));
    expect(main, contains('kRevenueCatIosApiKey'));
  });

  test('S-265: NewCycleGate is evaluated from exactly one place', () {
    final gateReferences = _filesMentioning(libFiles, RegExp(r'NewCycleGate\b'));
    expect(gateReferences, [
      'lib/state/entitlements/new_cycle_gate.dart',
      'lib/state/record/record_save_service.dart',
    ]);
    expect(_filesMentioning(libFiles, RegExp(r'newCycleGateProvider\b')), [
      'lib/state/entitlements/entitlement_providers.dart',
      'lib/state/record/record_save_service.dart',
    ]);
  });

  test('S-265: the free-tier limit is written down once and read in two '
      'places', () {
    final defining = _filesMentioning(
      libFiles,
      RegExp(r'kFreeTierOpenCycles\s*='),
    );
    expect(defining, ['lib/core/purchases/pro_plans.dart']);
    expect(_filesMentioning(libFiles, RegExp(r'kFreeTierOpenCycles\b')), [
      'lib/core/purchases/pro_plans.dart',
      'lib/features/settings/pro_plan_section.dart',
      'lib/state/entitlements/new_cycle_gate.dart',
    ]);
  });
}

/// Every `.dart` file under [root], sorted, so an expectation reads as a list
/// of paths rather than a set with an arbitrary order.
List<File> _dartFilesUnder(String root) {
  final files = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// The relative URIs every `import`/`export` in [file] names.
List<String> _importsOf(File file) => RegExp(r"""^(?:import|export)\s+'([^']+)'""", multiLine: true)
    .allMatches(file.readAsStringSync())
    .map((match) => match.group(1)!)
    .toList();

/// [file] with its comments removed, so a structural assertion counts a real
/// reference rather than a file that merely names the thing in prose.
String _codeOf(File file) => file
    .readAsStringSync()
    .split('\n')
    .map((line) => line.contains('//') ? line.substring(0, line.indexOf('//')) : line)
    .join('\n');

List<String> _filesMentioning(List<File> files, RegExp pattern) => files
    .where((file) => pattern.hasMatch(_codeOf(file)))
    .map((file) => file.path)
    .toList();
