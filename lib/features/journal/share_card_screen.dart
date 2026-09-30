import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../domain/rules/share_card.dart';
import '../../state/export/export_controller.dart';
import '../../state/journal/journal_controller.dart';
import 'share_card.dart';

/// Stage 8's share screen (Pro Wave 3 D-52…D-55): the month's card, the two
/// toggles, and the one button that turns the card into an image.
///
/// The screen owns no figures of its own — it reads the Journal's own rows
/// (`journalControllerProvider`) and hands them to the pure helpers in
/// `lib/domain/rules/share_card.dart`, so the card and the Journal cannot
/// disagree about a month.
///
/// The two toggles are **local `State`**, not preferences (D-52): they reset
/// to off every time the screen opens, which is what makes the privacy-safe
/// default true by construction rather than by a stored flag a user could
/// flip once and forget. Nothing here writes a preference.
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key, this.now});

  /// The month the card covers. Defaults to the wall clock; tests pass a
  /// fixed date so the month is deterministic (`docs/conventions.md` §3).
  final DateTime? now;

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _cardKey = GlobalKey();
  bool _showDollars = false;
  bool _showTickers = false;
  bool _isSharing = false;

  DateTime get _now => widget.now ?? DateTime.now();

  /// Captures the card's own `RepaintBoundary` at `pixelRatio: 3` — the
  /// preview and the export are the same widget tree, so the image cannot
  /// drift from what the user saw (D-53).
  Future<Uint8List> _captureCard() async {
    final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _share() async {
    // Read the seam before the first `await`: the capture is asynchronous and
    // the screen may be gone by the time it returns, and a `ref` read after
    // disposal throws.
    final sheet = ref.read(shareSheetProvider);
    setState(() => _isSharing = true);
    try {
      final bytes = await _captureCard();
      final now = _now;
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await sheet.shareFiles([
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          path: 'wheel-triage-$month-ledger.png',
        ),
      ], subject: 'Wheel Triage — ${monthYearText(now)} ledger');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final monthYear = monthYearText(now);
    final state = ref.watch(journalControllerProvider);
    final cycles = cyclesInCardMonth(
      cycles: [
        for (final row in state.rows)
          (cycle: row.cycle, ticker: row.ticker, legs: row.legs, pnl: row.pnl),
      ],
      now: now,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Share ${monthName(now)}'),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    'An image of this month\'s closed cycles',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (cycles.isEmpty)
                    _EmptyMonth(monthYear: monthYear)
                  else ...[
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: ShareCard(
                            monthYear: monthYear,
                            cycles: cycles,
                            showDollars: _showDollars,
                            showTickers: _showTickers,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show dollar amounts'),
                      value: _showDollars,
                      onChanged: (value) => setState(() => _showDollars = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show tickers'),
                      value: _showTickers,
                      onChanged: (value) => setState(() => _showTickers = value),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _isSharing ? null : _share,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share image'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// D-55: a month with no closed cycles renders this and **no card**, so there
/// is no share button — an image of nothing is not worth sending to anyone.
/// The app bar still names the month, so the user knows why it is empty.
class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.monthYear});

  final String monthYear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Text(
        'No cycles closed in $monthYear',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
