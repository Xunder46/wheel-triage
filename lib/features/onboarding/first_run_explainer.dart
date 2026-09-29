import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/disclaimer.dart';
import '../../state/preferences/preferences_provider.dart';

/// Three swipeable cards, skippable, reachable again from Settings
/// (brief-followup §C3). Content is verbatim.
///
/// Finishing or skipping always sets `firstRunExplainerShown = true`
/// (Feature Invariant/S-072). Reopening from Settings when the flag is
/// already `true` is a no-op write -- the automatic first-launch trigger
/// only fires on `!firstRunExplainerShown`, so this can never "re-arm" it
/// (S-073).
class FirstRunExplainerScreen extends ConsumerStatefulWidget {
  const FirstRunExplainerScreen({super.key});

  @override
  ConsumerState<FirstRunExplainerScreen> createState() => _FirstRunExplainerScreenState();
}

const List<(String, String)> _cards = [
  (
    'What this does',
    '"You type the numbers off your broker screen. The app runs your own '
        'thresholds against them and tells you which rule fired. It has no '
        'market data connection and no opinion about any stock."',
  ),
  (
    'The loop',
    "Screen a trade before you sell it -> track it once you've sold -> "
        'update the snapshot weekly -> act when a rule fires.',
  ),
  (
    'The rules are yours',
    'the defaults shipped are a common starting point, not doctrine. '
        "Everything is editable in Settings, and changing a profile won't "
        "reclassify trades you've already closed.",
  ),
];

class _FirstRunExplainerScreenState extends ConsumerState<FirstRunExplainerScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref
        .read(preferencesControllerProvider.notifier)
        .update((p) => p.copyWith(firstRunExplainerShown: true));
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/positions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _cards.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  for (final (title, body) in _cards) _ExplainerCard(title: title, body: body),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _cards.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLastPage
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                  child: Text(isLastPage ? 'Done' : 'Next'),
                ),
              ),
            ),
            // D-18: the persistent disclaimer, verbatim. Outside the
            // PageView so it is a footer of the explainer itself rather than
            // one card's body -- it is on screen on every card, and no page
            // turn can hide it (S-249).
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                kAppDisclaimer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(body, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
