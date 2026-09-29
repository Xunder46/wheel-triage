import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The fixed five-item bar from the reference (`Stage 3 · Stage 1`): Today,
/// Journal, Record, Screener, Settings, with Record raised in the centre.
///
/// It takes [currentPath] rather than reading the router itself, for the same
/// reason [ExportReminderBanner] takes `visible`: the bar is presentation, and
/// the screen that owns the route already knows which one it is. A widget that
/// read `GoRouterState` here would also be untestable outside a router.
///
/// Non-Today destinations are **pushed**, not `go`-ed, so the screen
/// underneath stays alive — Today reloads on arrival rather than being rebuilt
/// from scratch (S-205).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentPath});

  /// The route this bar is being rendered on, so the matching item renders as
  /// selected and does not stack a duplicate of itself.
  final String currentPath;

  static const _items = <({String label, IconData icon, String path})>[
    (label: 'Today', icon: Icons.today_outlined, path: '/positions'),
    (label: 'Journal', icon: Icons.menu_book_outlined, path: '/journal'),
    (label: 'Record', icon: Icons.add, path: '/record'),
    (label: 'Screener', icon: Icons.calculate_outlined, path: '/screener'),
    (label: 'Settings', icon: Icons.settings_outlined, path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      // The bar sits on the card surface, not the screen ground, and carries
      // the hairline the design puts along its top edge.
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in _items)
              Expanded(
                child: _NavItem(
                  label: item.label,
                  icon: item.icon,
                  raised: item.path == '/record',
                  selected: item.path == currentPath,
                  onTap: item.path == currentPath
                      ? null
                      : () => context.push(item.path),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.raised,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;

  /// Record: the accent-filled square in the centre of the bar.
  final bool raised;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, ink) = switch ((raised, selected)) {
      (true, _) => (scheme.primary, scheme.onPrimary),
      (false, true) => (scheme.primaryContainer, scheme.onPrimaryContainer),
      (false, false) => (scheme.surface, scheme.onSurfaceVariant),
    };
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: raised ? 48 : 54,
                height: raised ? 34 : 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(raised ? 14 : 999),
                ),
                child: Icon(icon, size: 20, color: ink),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
