import 'package:flutter/material.dart';

/// A minimal delta-history sparkline (§5.2), drawn with a plain
/// [CustomPainter] rather than a charting package — this app has no other
/// chart yet, and a hand-rolled line keeps the dependency surface (and the
/// risk of guessing an unfamiliar chart API blind) as small as possible for
/// what is, after all, just a line through a handful of points. See
/// `docs/plans/wheel-triage-plan.md`'s Phase 4 Assumption Log.
///
/// Pure presentation: [values] in, nothing computed here. An empty or
/// single-point history renders as a flat/empty line rather than throwing.
class DeltaSparkline extends StatelessWidget {
  const DeltaSparkline({super.key, required this.values, this.height = 40});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            values.isEmpty ? 'No snapshots yet' : 'Not enough history yet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 1e-9 ? 1.0 : (maxValue - minValue);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
