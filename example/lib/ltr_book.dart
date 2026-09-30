// The English edition — the DRESSED book.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:page_curl_flip/page_curl_flip.dart';

import 'chrome_tour.dart';
import 'export_dialog.dart';
import 'flip_sound.dart';
import 'reader.dart';
import 'shared_pages.dart';
import 'stores.dart';

// The palette lives in shared_pages.dart and is three colours used as
// blocks: pink for the reader's own marks and for display type, teal for the
// chrome, and a stock that is deliberately a shade off white. Nothing the
// author wrote is pink, so anything pink on screen belongs to the reader.

class LtrBook extends StatefulWidget {
  const LtrBook({super.key});

  @override
  State<LtrBook> createState() => _LtrBookState();
}

class _LtrBookState extends State<LtrBook> {
  final _reader = Reader();
  final _sound = FlipSound();

  /// The reader's saved marks. A real app loads these from storage on open
  /// and writes them back here — see MarkStore in stores.dart for a Hive
  /// wiring.
  List<ReaderMark> _marks = MarkStore.load();

  /// The reader's chosen pace. The package draws the control and reports
  /// the tap; applying it to the engine is the app's job.
  FlipBookReadSpeed _speed = FlipBookReadSpeed.normal;

  /// The footer and × outlined by the "?" tour, or null while it is closed.
  List<Rect>? _tour;

  // Three pages, one theme, every feature of the package spread across them.
  // See shared_pages.dart for why: a `body:` widget buys the look and loses
  // marking, read-aloud and auto-scroll. `background` + a per-page `style`
  // keeps the look AND the features.
  static final _pages = <FlipBookPage>[
    FlipBookPage(
      id: 'ltr-0',
      title: kTitle1,
      tagline: kStand1,
      background: const MagazinePaper(quote: kQuote1),
      style: magazineStyle,
      bodySegments: kPage1,
      bodyWidgets: {
        2: const CircleCut(
          caption:
              'The same build runs on both platforms. Only the voice and '
              'the system fonts differ, and both are the app\'s choice.',
        ),
        4: const PullQuote(text: kQuote1),
      },
    ),
    FlipBookPage(
      id: 'ltr-1',
      title: kTitle2,
      tagline: kStand2,
      background: const MagazinePaper(quote: kQuote2, variant: 1),
      style: magazineStyle,
      bodySegments: kPage2,
      bodyWidgets: {
        3: const PullQuote(text: kQuote2, color: kTeal),
        5: const CircleCut(
          doodle: Doodle.android,
          logoOnEnd: false,
          caption:
              'The package makes no sound of its own. It owns the '
              'control, the state and the label, and hands the choice to you.',
        ),
      },
    ),
    FlipBookPage(
      id: 'ltr-2',
      title: kTitle3,
      tagline: kStand3,
      background: const MagazinePaper(quote: kQuote3, variant: 2),
      style: magazineStyle,
      bodySegments: kPage3,
      bodyWidgets: {
        2: const CircleCut(
          doodle: Doodle.apple,
          caption:
              'Marks, bookmarks and kept pages all leave through '
              'callbacks and come back through fields. Hive, SQLite, a file, '
              'a server — the choice was never the book\'s to make.',
        ),
        4: const PullQuote(text: kQuote3),
      },
    ),
  ];

  @override
  void dispose() {
    _reader.dispose();
    _sound.dispose();
    super.dispose();
  }

  void _saveMarks(List<ReaderMark> marks) {
    setState(() => _marks = marks);
    MarkStore.save(marks);
  }

  @override
  Widget build(BuildContext context) {
    // ── THE DRESSED BOOK ─────────────────────────────────────────────────
    // Nothing below is a default. Every icon, word, colour and type face is
    // this app's, to show how far the skeleton bends. The RTL book is the
    // same package with almost nothing set; open both and compare.
    return Stack(
      children: [
        _book(context),
        if (_tour case final holes?)
          ChromeTour(holes: holes, onDone: () => setState(() => _tour = null)),
      ],
    );
  }

  Widget _book(BuildContext context) {
    return FlipBook(
      // Coated stock catches light as it bends — the sheen on the curling
      // page, turned up from the default for the magazine look.
      shine: 0.55,
      onClose: () => Navigator.of(context).pop(),

      pages: FlipBookPages(
        items: _pages,
        textDirection: TextDirection.ltr,
        paperColor: kStock,
        // No book-level style: every page sets its own, which is what
        // FlipBookPage.style is for. The package default stands underneath.
        showNumber: true,
        initialPage: PlaceStore.ltr.openAt,
        onChanged: (page) {
          PlaceStore.ltr.resume = page;
          Persist.save();
        },
      ),

      // Every control below uses the package's DEFAULT icon. Only colour
      // and the spoken/tap label are set here, because the bar is dark grey
      // and an icon in the page's own ink would be invisible on it. The
      // defaults are the ordinary glyph for each action — a reader should
      // never have to learn what a button means.
      // Header and footer retire together on a tap, so the book reads as
      // paper rather than as an app with a toolbar.
      header: FlipBookHeader(
        closeColor: kInk,
        closeLabel: 'CLOSE',
        autoHide: true,
        // The "?" shows the package's two keys at work: it outlines the
        // footer bar and the × wherever they are on this screen.
        action: IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: kInk),
          tooltip: 'Show the controls',
          onPressed: () => setState(() => _tour = bookChromeRects(context)),
        ),
      ),

      // The bar belongs to the same magazine as the page: teal bar, white
      // icons, and the tap label in the pink that marks text — three colours
      // everywhere, chrome included.
      footer: FlipBookFooter(
        autoHide: true,
        color: kTeal,
        radius: 26,
        iconSize: 26,
        iconColor: kOnColour,
        revealFor: const Duration(seconds: 4),
        tapLabelFor: const Duration(seconds: 2),
        tapLabelColor: kPink,
        tapLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
          color: kOnColour,
        ),
        pageNumberStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: kOnColour.withValues(alpha: 0.75),
        ),
        index: const FlipBookIndexButton(label: 'CONTENTS'),
        nav: const FlipBookNavButtons(
          previousLabel: 'PREVIOUS',
          nextLabel: 'NEXT',
        ),
        sound: FlipBookSound(
          onFlip: _sound.play,
          muteLabel: 'MUTE',
          unmuteLabel: 'SOUND ON',
          color: kOnColourDim,
        ),
      ),

      swipe: FlipBookSwipe(
        hint: SwipeMemory.learned
            ? null
            : FlipBookSwipeHint(
                onRetired: SwipeMemory.retire,
                showFor: const Duration(seconds: 4),
                child: const HintBar(child: Text('swipe')),
              ),
      ),

      readAloud: FlipBookReadAloud(
        onRead: (unit) => _reader.read(unit, 'en-US', _speed),
        onStop: _reader.stop,
        onPause: _reader.pause,
        onResume: _reader.resume,
        playAll: true,
        // Play is a play triangle. Resume is the same triangle, because
        // resuming IS playing. Play-all is the playlist glyph — a play mark
        // against a stack of lines, which is exactly what it does.
        play: const Icon(Icons.play_arrow_rounded, color: kOnColour),
        playAllControl: const Icon(
          Icons.playlist_play_rounded,
          color: kOnColour,
        ),
        pause: const Icon(Icons.pause_rounded, color: kOnColour),
        resume: const Icon(Icons.play_arrow_rounded, color: kOnColour),
        stop: const Icon(Icons.stop_rounded, color: kOnColour),
        playLabel: 'PLAY',
        playAllLabel: 'PLAY ALL',
        pauseLabel: 'PAUSE',
        resumeLabel: 'RESUME',
        stopLabel: 'STOP',
        readAloudSemantics: 'Play — read this page aloud',
        readAllSemantics: 'Play all — read the whole book aloud',
        pauseSemantics: 'Pause the reading',
        stopSemantics: 'Stop the reading',
        // The title is read first, then keeps its ink for the whole page:
        // a heading is the page's anchor and should not flicker.
        readTitle: true,
        fadeTitle: false,
        speed: FlipBookSpeedControl(
          // All three, listed explicitly. Naming them is still the point:
          // a book that wants only two simply leaves one out, and the RTL
          // book passes no options at all and gets the same three.
          options: const [
            FlipBookReadSpeed.slow,
            FlipBookReadSpeed.normal,
            FlipBookReadSpeed.fast,
          ],
          // The package already labels these 0.5x / 1x / 1.5x. The
          // typographic ½× read as decoration rather than a speed, so the
          // overrides are gone and the defaults stand.
          semantics: 'Reading pace',
          tapSuffix: 'pace',
          selectedColor: kPink,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kOnColourDim,
          ),
          selectedStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: kTeal,
          ),
          initial: _speed,
          // Both halves matter. setState redraws the pill; setSpeed
          // reaches the engine, and that is what makes the change land at
          // the NEXT WORD instead of the next paragraph.
          onChanged: (speed) {
            setState(() => _speed = speed);
            unawaited(_reader.setSpeed(speed));
          },
        ),
        highlight: const FlipBookHighlight(
          style: FlipBookMarkerStyle.focus,
          // Deep enough that the spoken line clearly leads, shallow enough
          // that the rest is still readable if the eye wanders.
          dimOpacity: 0.28,
        ),
      ),

      // Where the reader stopped, and the pages they kept. Both report and
      // nothing else — this app decides what remembering means.
      bookmarks: FlipBookBookmarks(
        bookmarkedPage: PlaceStore.ltr.bookmark,
        // Tapping a page that is ALREADY bookmarked removes the bookmark, so
        // the button has a way back and its label can name an action rather
        // than describe a state.
        onBookmark: (page) => setState(() {
          final store = PlaceStore.ltr;
          store.bookmark = store.bookmark == page ? null : page;
          Persist.save();
        }),
        saved: PlaceStore.ltr.saved,
        onSavedChanged: (ids) => setState(() {
          PlaceStore.ltr.saved = ids;
          Persist.save();
        }),
        bookmarkLabel: 'Bookmark this page',
        bookmarkedLabel: 'Remove bookmark',
        saveLabel: 'Add to my pages',
        unsaveLabel: 'Remove from my pages',
        color: kOnColour,
        // The reader's colour again: pink means "this one is mine".
        activeColor: kPink,
      ),

      // Marking wears the accent: a reader's own hand is the one thing on
      // the page that is not the author's.
      marker: FlipBookMarker(
        marks: _marks,
        onChanged: _saveMarks,
        // The reader's colour is the magazine pink, so a mark belongs to the
        // same palette as the page it sits on. The alpha keeps the words
        // underneath legible — a highlighter sits ON paper, it does not
        // replace it.
        color: kPink.withValues(alpha: 0.32),
        iconColor: kOnColour,
        // The package's default pencil, trash, tick and cross. The labels
        // below name each control on tap, which is how an icon that cannot
        // explain itself gets explained.
        pencilLabel: 'MARK',
        stopLabel: 'DONE MARKING',
        clearLabel: 'CLEAR ALL MARKS',
        saveLabel: 'SAVE',
        cancelLabel: 'CANCEL',
      ),

      contents: FlipBookContents(
        // The package hands over plain page numbers, titles and text. Making
        // a PDF out of them is this app's job — the package carries no
        // dependencies, and a document writer is a big one.
        export: FlipBookExport(
          onExport: (kind, entries) => showExport(context, kind, entries),
          savedLabel: 'Pages I kept',
          markedLabel: 'Passages I marked',
          wholeLabel: 'The whole book',
          optionStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kInk,
          ),
          headingStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: kPink,
          ),
          cancelLabel: 'Not now',
        ),
        heading: 'CONTENTS',
        searchHint: 'find a page',
        dividerColor: const Color(0x1F2A2A2A),
        splashColor: kPink.withValues(alpha: 0.12),
        searchFocusBorder: kTeal,
        searchIcon: Icons.search_rounded,
        currentIcon: Icons.bookmark_rounded,
        currentIconColor: kPink,
        // The contents is a page of the same magazine: display heading in
        // pink, the same tracking as a standfirst, on the same stock.
        headingStyle: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.0,
          color: kPink,
        ),
        titleStyle: const TextStyle(fontSize: 15, color: kInk, height: 1.4),
        currentStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: kPink,
          height: 1.4,
        ),
        numberStyle: const TextStyle(fontSize: 11, color: kInkSoft),
        searchStyle: const TextStyle(fontSize: 14, color: kInk),
        searchHintStyle: const TextStyle(fontSize: 14, color: kInkSoft),
        searchIconColor: kInkSoft,
        searchFill: const Color(0x0F2A2A2A),
      ),
    );
  }
}
