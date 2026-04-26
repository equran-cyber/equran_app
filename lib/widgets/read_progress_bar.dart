import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class ReadProgressBar extends StatelessWidget {
  const ReadProgressBar({
    super.key,
    required this.marginValue,
    required this.currentVerse,
    required this.totalVerses,
    required this.isScrubbing,
    required this.scrubStartVerse,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
    required this.onScrubCancel,
  });

  final double marginValue;
  final int currentVerse;
  final int totalVerses;
  final bool isScrubbing;
  final int? scrubStartVerse;
  final void Function(LongPressStartDetails details, double width) onScrubStart;
  final void Function(LongPressMoveUpdateDetails details, double width)
  onScrubUpdate;
  final VoidCallback onScrubEnd;
  final VoidCallback onScrubCancel;

  @override
  Widget build(BuildContext context) {
    final int progressVerse = isScrubbing
        ? (scrubStartVerse ?? currentVerse)
        : currentVerse;
    final double percent = totalVerses <= 1
        ? 1
        : ((progressVerse - 1) / (totalVerses - 1)).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.only(left: marginValue, right: marginValue, top: 14),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double scrubPercent = totalVerses <= 1
              ? 1
              : ((currentVerse - 1) / (totalVerses - 1)).clamp(0.0, 1.0);
          const double indicatorSize = 12;
          final double indicatorLeft =
              (scrubPercent * constraints.maxWidth - (indicatorSize / 2))
                  .clamp(0.0, constraints.maxWidth - indicatorSize)
                  .toDouble();

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (details) =>
                onScrubStart(details, constraints.maxWidth),
            onLongPressMoveUpdate: (details) =>
                onScrubUpdate(details, constraints.maxWidth),
            onLongPressEnd: (_) => onScrubEnd(),
            onLongPressCancel: onScrubCancel,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: <Widget>[
                LinearPercentIndicator(
                  barRadius: const Radius.circular(999),
                  animation: !isScrubbing,
                  animateFromLastPercent: !isScrubbing,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withAlpha(42),
                  lineHeight: 10.0,
                  percent: percent,
                  progressColor: Theme.of(
                    context,
                  ).colorScheme.tertiary.withAlpha(190),
                ),
                if (isScrubbing)
                  Positioned(
                    left: indicatorLeft,
                    child: IgnorePointer(
                      child: Container(
                        width: indicatorSize,
                        height: indicatorSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
