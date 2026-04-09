import 'package:equran/backend/bookmark_db.dart';
import 'package:equran/backend/library.dart' show SettingsDB, QuranAudioService;
import 'package:equran/widgets/library.dart' show ReadQuranCard;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:quran/quran.dart' as quran;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:vibration/vibration.dart';

class ReadPage extends StatefulWidget {
  final int chapter;
  final bool juzMode;
  final int? startVerse;

  const ReadPage(
      {super.key,
      required this.chapter,
      this.startVerse,
      this.juzMode = false});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  late int _currentVerse;
  late int _currentChapter;
  late ScrollController _scrollController;
  late int _totalVerses;
  late FocusNode _buttonFocusNode;
  late FocusNode _pageFocusNode;
  late ItemPositionsListener _ipl;
  late ItemScrollController _isc;
  late bool _viewMode;
  bool _hasSavedOnExit = false;
  bool _isScrubbingProgress = false;
  int? _scrubStartVerse;
  double? _scrubStartDx;
  double? _scrubStartDy;
  double _scrubPrecision = 1.0;

  @override
  void initState() {
    super.initState();
    _ipl = ItemPositionsListener.create();
    _isc = ItemScrollController();
    _ipl.itemPositions.addListener(() {
      onScroll();
    });

    _viewMode = SettingsDB().get("viewMode", defaultValue: true);

    _scrollController = ScrollController();
    _currentChapter = widget.chapter;
    _currentVerse = widget.startVerse is int ? widget.startVerse! : 1;
    _buttonFocusNode = FocusNode(debugLabel: 'Menu Button');
    _pageFocusNode = FocusNode(debugLabel: 'Read Page Keyboard Focus');
    _getTotalVerses();
  }

  @override
  void dispose() {
    if (!_hasSavedOnExit) {
      BookmarkDB().addReadingEntry(_currentChapter, _currentVerse);
    }
    _scrollController.dispose();
    _buttonFocusNode.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  void onScroll() {
    final positions = _ipl.itemPositions.value;
    int currentIndex = positions.first.index + 1;
    if (_currentVerse != currentIndex) {
      _setVerse(currentIndex);
      _updateDB();
    }
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    int picker = _currentVerse;

    // Define margin values for different screen sizes
    double marginValue;
    if (screenSize.width > 1200) {
      marginValue = 90.0; // Large screen
    } else if (screenSize.width > 700) {
      marginValue = 40.0; // Medium screen
    } else {
      marginValue = 8.0; // Small screen
    }
    return WillPopScope(
      onWillPop: () async {
        await _saveProgressOnExit();
        return true;
      },
      child: Focus(
        autofocus: true,
        focusNode: _pageFocusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }

          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _increase();
            return KeyEventResult.handled;
          }

          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _decrease();
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: Scaffold(
          appBar: AppBar(
        leading: const BackButton(),
        title: Text(quran.getSurahName(_currentChapter)),
        centerTitle: true,
        actions: <Widget>[
          MenuAnchor(
            childFocusNode: _buttonFocusNode,
            menuChildren: <Widget>[
              MenuItemButton(
                child: Padding(
                  padding: const EdgeInsets.only(
                      right: 120, bottom: 10, top: 10, left: 5),
                  child: Text(
                    "Reset",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                onPressed: () => showDialog(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                          icon: const Icon(Icons.warning_amber),
                          title: const Text(
                            "Reset",
                          ),
                          content: const Text(
                            "Would you like to start over?",
                          ),
                          actions: <Widget>[
                            TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("CANCEL")),
                            TextButton(
                              child: const Text("OK"),
                              onPressed: () {
                                _reset();
                                _updateDB();
                                if (!SettingsDB()
                                    .get("viewMode", defaultValue: true)) {
                                  _isc.jumpTo(index: 0);
                                }
                                Navigator.of(context).pop();
                              },
                            )
                          ],
                        )),
              ),
              MenuItemButton(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(bottom: 10, top: 10, left: 5),
                    child: Text(
                      "Jump to Verse",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  onPressed: () => showDialog(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text("Select Verse"),
                          actions: [
                            TextButton(
                                child: const Text("CONFIRM"),
                                onPressed: () {
                                  _setVerse(picker);
                                  if (!SettingsDB()
                                      .get("viewMode", defaultValue: true)) {
                                    _isc.jumpTo(index: picker - 1);
                                  }
                                  _updateDB();
                                  Navigator.of(context).pop();
                                }),
                            TextButton(
                                child: const Text("CANCEL"),
                                onPressed: () => Navigator.of(context).pop())
                          ],
                          content: StatefulBuilder(
                            builder: (context, sBsetState) => NumberPicker(
                                minValue: 1,
                                maxValue: _totalVerses,
                                value: picker,
                                onChanged: (int value) {
                                  setState(() => picker = value);
                                  sBsetState(() => picker = value);
                                }),
                          ),
                        ),
                      )),
            ],
            child: const Text('Background Color'),
            builder: (BuildContext context, MenuController controller,
                Widget? child) {
              return TextButton(
                  focusNode: _buttonFocusNode,
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  child: const Icon(Icons.more_vert));
            },
          ),
        ],
      ),
        body: _viewMode ? cardView(marginValue: marginValue) : listView(),
        ),
      ),
    );
  }

  Future<void> _saveProgressOnExit() async {
    if (_hasSavedOnExit) return;

    if (!_viewMode) {
      final positions = _ipl.itemPositions.value;
      if (positions.isNotEmpty) {
        final int currentIndex = positions.first.index + 1;
        _currentVerse = currentIndex;
      }
    }

    _hasSavedOnExit = true;
    await BookmarkDB().addReadingEntry(_currentChapter, _currentVerse);
  }

  void _increase() {
    _vibrate();
    _scrollUp();
    // If the viewMode is to ListView, you just directly ignore this if and go to else
    if (_currentVerse != _totalVerses && _viewMode) {
      _incrementVerse();
      _updateDB();
    } else {
      // Surah completed: remove its last-read progress, then move to next chapter.
      BookmarkDB().delete(_currentChapter);
      _reset();
      if (_currentChapter != 114) {
        _incrementChapter();
      } else {
        _resetChapter();
      }
      _getTotalVerses();
      _updateDB();
    }
  }

  void _decrease() {
    _vibrate();
    _scrollUp();
    if (_currentVerse != 1) {
      _decrementVerse();
      _updateDB();
    }
  }

  void _incrementVerse() {
    setState(() {
      _currentVerse++;
    });
  }

  void _setVerse(int value) {
    setState(() {
      _currentVerse = value;
    });
  }

  void _decrementVerse() {
    setState(() {
      _currentVerse--;
    });
  }

  void _reset() {
    setState(() {
      _currentVerse = 1;
    });
  }

  void _getTotalVerses() {
    setState(() {
      _totalVerses = quran.getVerseCount(_currentChapter);
    });
  }

  void _incrementChapter() {
    setState(() {
      _currentChapter++;
    });
  }

  void _resetChapter() {
    setState(() {
      _currentChapter = 1;
    });
  }

  void _vibrate() async {
    if (SettingsDB().get("vibration", defaultValue: true) != true) return;
    if (kIsWeb) return;

    final bool supportedPlatform = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!supportedPlatform) return;

    try {
      final bool hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) return;
      await Vibration.vibrate(duration: 10);
    } catch (_) {
      // Ignore vibration failures on unsupported platforms/devices.
    }
  }

  void _scrollUp() {
    _viewMode
        ? _scrollController.jumpTo(_scrollController.position.minScrollExtent)
        : _isc.jumpTo(index: 0);
  }

  void _updateDB() {
    BookmarkDB().addReadingEntry(_currentChapter, _currentVerse);
  }

  void _updateVerseFromProgress({
    required double localDx,
    required double localDy,
    required double width,
    bool vibrateOnChange = false,
  }) {
    if (_totalVerses <= 0 || width <= 0) return;

    final double startDx = _scrubStartDx ?? localDx;
    final double startDy = _scrubStartDy ?? localDy;
    final int anchorVerse = _scrubStartVerse ?? _currentVerse;
    final double downwardOffset = (localDy - startDy).clamp(0.0, double.infinity);

    double precision = 1.0;
    if (downwardOffset > 120) {
      precision = 0.12;
    } else if (downwardOffset > 80) {
      precision = 0.2;
    } else if (downwardOffset > 40) {
      precision = 0.35;
    } else if (downwardOffset > 16) {
      precision = 0.6;
    }

    if ((precision - _scrubPrecision).abs() > 0.0001) {
      _scrubPrecision = precision;
      _scrubStartDx = localDx;
      _scrubStartDy = localDy;
      _scrubStartVerse = _currentVerse;
      return;
    }

    final double verseDelta =
        (((localDx - startDx) * precision) / width) * (_totalVerses - 1);
    final int preciseTargetVerse =
        (anchorVerse + verseDelta.round()).clamp(1, _totalVerses);

    if (preciseTargetVerse == _currentVerse) return;

    _setVerse(preciseTargetVerse);
    _updateDB();

    if (vibrateOnChange) {
      _vibrate();
    }
  }

  Widget _buildProgressBar(double marginValue) {
    final int progressVerse = _isScrubbingProgress
        ? (_scrubStartVerse ?? _currentVerse)
        : _currentVerse;
    final double percent = _totalVerses <= 1
        ? 1
        : ((progressVerse - 1) / (_totalVerses - 1)).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.only(left: marginValue, right: marginValue, top: 20),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double scrubPercent = _totalVerses <= 1
              ? 1
              : ((_currentVerse - 1) / (_totalVerses - 1)).clamp(0.0, 1.0);
          final double indicatorSize = 16;
          final double indicatorLeft =
              (scrubPercent * constraints.maxWidth - (indicatorSize / 2))
                  .clamp(0.0, constraints.maxWidth - indicatorSize)
                  .toDouble();

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (details) {
              setState(() {
                _isScrubbingProgress = true;
                _scrubStartVerse = _currentVerse;
                _scrubStartDx = details.localPosition.dx;
                _scrubStartDy = details.localPosition.dy;
                _scrubPrecision = 1.0;
              });
              _updateVerseFromProgress(
                localDx: details.localPosition.dx,
                localDy: details.localPosition.dy,
                width: constraints.maxWidth,
              );
            },
            onLongPressMoveUpdate: (details) {
              _updateVerseFromProgress(
                localDx: details.localPosition.dx,
                localDy: details.localPosition.dy,
                width: constraints.maxWidth,
                vibrateOnChange: true,
              );
            },
            onLongPressEnd: (_) {
              setState(() {
                _isScrubbingProgress = false;
                _scrubStartVerse = null;
                _scrubStartDx = null;
                _scrubStartDy = null;
                _scrubPrecision = 1.0;
              });
            },
            onLongPressCancel: () {
              setState(() {
                _isScrubbingProgress = false;
                _scrubStartVerse = null;
                _scrubStartDx = null;
                _scrubStartDy = null;
                _scrubPrecision = 1.0;
              });
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: <Widget>[
                LinearPercentIndicator(
                  barRadius: const Radius.circular(30),
                  animation: !_isScrubbingProgress,
                  animateFromLastPercent: !_isScrubbingProgress,
                  backgroundColor: Theme.of(context).colorScheme.onTertiary,
                  lineHeight: 20.0,
                  percent: percent,
                  progressColor: Theme.of(context).colorScheme.tertiary,
                ),
                if (_isScrubbingProgress)
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
                            width: 3,
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

  Widget cardView({required double marginValue}) {
    return SafeArea(
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final double velocity = details.primaryVelocity ?? 0;
          if (velocity < -200) {
            _increase();
          } else if (velocity > 200) {
            _decrease();
          }
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  _buildProgressBar(marginValue),
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: ReadQuranCard(
                      currentChapter: _currentChapter,
                      currentVerse: _currentVerse,
                      totalVerses: _totalVerses,
                      juzNumber:
                          quran.getJuzNumber(_currentChapter, _currentVerse),
                      basmala: _currentChapter != 1 &&
                              _currentVerse == 1 &&
                              _currentChapter != 9
                          ? quran.basmala
                          : null,
                      verse: _buildVerseText(_currentChapter, _currentVerse),
                      translation: quran.getVerseTranslation(
                          _currentChapter, _currentVerse,
                          translation: quran.Translation.values[
                              SettingsDB().get("translation", defaultValue: 0)]),
                      url: QuranAudioService()
                          .getAyahUrl(_currentChapter, _currentVerse),
                      fontSize: SettingsDB().get("fontSize", defaultValue: 38.0),
                      fontSizeTranslation: SettingsDB().get("fontSizeTranslation", defaultValue: 20.0),
                    ),
                  ),
                  const SizedBox(
                    height: 120,
                  )
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 80,
                padding: const EdgeInsets.only(right: 12, left: 12),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment
                      .spaceBetween, // Distribute buttons horizontally
                  children: [
                    ElevatedButton(
                      onPressed: () => _decrease(),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 12.0, horizontal: 18),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 30,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _increase(),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 12.0, horizontal: 18),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget listView() {

    return ScrollablePositionedList.builder(
        itemScrollController: _isc,
        initialScrollIndex: _currentVerse - 1,
        itemPositionsListener: _ipl,
        itemCount: _totalVerses,
        itemBuilder: (context, index) {
          int currentVerse = index + 1;
          return Column(
            children: [
              ReadQuranCard(
                currentChapter: _currentChapter,
                currentVerse: currentVerse,
                totalVerses: _totalVerses,
                juzNumber: quran.getJuzNumber(_currentChapter, currentVerse),
                basmala: _currentChapter != 1 &&
                        currentVerse == 1 &&
                        _currentChapter != 9
                    ? quran.basmala
                    : null,
                verse: _buildVerseText(_currentChapter, currentVerse),
                translation: quran.getVerseTranslation(
                    _currentChapter, currentVerse,
                    translation: quran.Translation.values[
                        SettingsDB().get("translation", defaultValue: 0)]),
                url: QuranAudioService()
                    .getAyahUrl(_currentChapter, currentVerse),
                fontSize: SettingsDB().get("fontSize", defaultValue: 38.0),
                fontSizeTranslation: SettingsDB().get("fontSizeTranslation", defaultValue: 20.0),
              ),
              currentVerse != _totalVerses
                  ? const Divider()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // Distribute buttons horizontally
                      children: [
                        ElevatedButton(
                          onPressed: () => _decrease(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 18),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 30,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _increase(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 18),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          );
        });
  }
  String _buildVerseText(int chapter, int verse) {
    final verseText = quran.getVerse(chapter, verse);
    if (verse == 1 && chapter != 1) {
      return verseText.replaceAll(
        "بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ",
        "",
      );
    }
    return verseText;
  }
}
