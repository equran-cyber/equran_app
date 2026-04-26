import 'package:equran/widgets/read_verse_player_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('exposes play, continuous playback, and repeat controls', (
    WidgetTester tester,
  ) async {
    int playPauseCount = 0;
    bool? continuousValue;
    int repeatCount = 0;
    final ValueNotifier<Duration> position = ValueNotifier<Duration>(
      const Duration(seconds: 5),
    );
    final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
      const Duration(seconds: 20),
    );

    await tester.pumpWidget(
      materialTestApp(
        Stack(
          children: <Widget>[
            ReadVersePlayerBar(
              viewMode: true,
              isMounted: true,
              isVisible: true,
              isMinimized: false,
              isDragging: false,
              isPlaying: false,
              isLoading: false,
              continuousPlayback: false,
              repeatIntervalEnabled: false,
              collapseProgress: 0,
              currentChapter: 1,
              currentVerse: 1,
              totalVerses: 7,
              playingVerse: 1,
              positionListenable: position,
              durationListenable: duration,
              onHidden: () {},
              onExpand: () {},
              onDismiss: () {},
              onVerticalDragStart: (_) {},
              onVerticalDragUpdate: (_) {},
              onVerticalDragEnd: (_) {},
              onVerticalDragCancel: () {},
              onSeek: (_) {},
              onTogglePlayPause: () => playPauseCount++,
              onContinuousPlaybackChanged: (value) => continuousValue = value,
              onRepeatIntervalPressed: () => repeatCount++,
              onPlayPrevious: () {},
              onPlayNext: () {},
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.tap(find.byIcon(Icons.playlist_play_rounded));
    await tester.tap(find.byIcon(Icons.all_inclusive_rounded));

    expect(playPauseCount, 1);
    expect(continuousValue, isTrue);
    expect(repeatCount, 1);
  });

  testWidgets('renders minimized player summary and dismiss control', (
    WidgetTester tester,
  ) async {
    int dismissCount = 0;
    final ValueNotifier<Duration> position = ValueNotifier<Duration>(
      Duration.zero,
    );
    final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
      Duration.zero,
    );

    await tester.pumpWidget(
      materialTestApp(
        Stack(
          children: <Widget>[
            ReadVersePlayerBar(
              viewMode: true,
              isMounted: true,
              isVisible: true,
              isMinimized: true,
              isDragging: false,
              isPlaying: true,
              isLoading: false,
              continuousPlayback: false,
              repeatIntervalEnabled: false,
              collapseProgress: 1,
              currentChapter: 1,
              currentVerse: 1,
              totalVerses: 7,
              playingVerse: 1,
              positionListenable: position,
              durationListenable: duration,
              onHidden: () {},
              onExpand: () {},
              onDismiss: () => dismissCount++,
              onVerticalDragStart: (_) {},
              onVerticalDragUpdate: (_) {},
              onVerticalDragEnd: (_) {},
              onVerticalDragCancel: () {},
              onSeek: (_) {},
              onTogglePlayPause: () {},
              onContinuousPlaybackChanged: (_) {},
              onRepeatIntervalPressed: () {},
              onPlayPrevious: () {},
              onPlayNext: () {},
            ),
          ],
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Al Fatiha • Ayah 1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));

    expect(dismissCount, 1);
  });
}
