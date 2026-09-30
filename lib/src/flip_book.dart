import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'capture.dart';
import 'curl_overlay.dart';
import 'flip_book_bookmarks.dart';
import 'flip_book_contents.dart';
import 'flip_book_export.dart';
import 'flip_book_export_entry.dart';
import 'flip_book_export_kind.dart';
import 'flip_book_footer.dart';
import 'flip_book_header.dart';
import 'flip_book_keys.dart';
import 'flip_book_marker.dart';
import 'flip_book_page.dart';
import 'flip_book_page_style.dart';
import 'flip_book_pages.dart';
import 'flip_book_read_aloud.dart';
import 'flip_book_read_speed.dart';
import 'flip_book_swipe.dart';
import 'flip_speed.dart';
import 'marked_text.dart';
import 'read_marker_text.dart';
import 'reader_mark.dart';

part 'flip_book_read_types.dart';
part 'flip_book_scaffold.dart';
part 'flip_book_index_page.dart';
part 'flip_book_reading.dart';
part 'flip_book_marks.dart';

/// Drives a [FlipBook] from outside the widget — flip, jump, open the table
/// of contents, mute — so an app can remove the built-in chrome
/// (`header: null, footer: null`) and draw its own controls anywhere:
///
/// ```dart
/// final controller = FlipBookController();
///
/// FlipBook(
///   controller: controller,
///   header: null,
///   footer: null,
///   pages: FlipBookPages(items: const [...]),
///   onClose: () {},
/// );
///
/// // Your own button, any position, any style:
/// FloatingActionButton(onPressed: controller.nextPage);
/// ```
///
/// The controller shares this file with [FlipBook] — the same pattern Flutter
/// uses for `ExpansionTileController` — because it operates directly on the
/// widget's private state.
class FlipBookController {
  // Attach order, oldest first. The last entry is the book being driven;
  // when it is disposed the previous one automatically takes over (EDG-08).
  final List<_FlipBookStateBase> _attached = [];

  _FlipBookStateBase? get _state => _attached.isEmpty ? null : _attached.last;

  void _attach(_FlipBookStateBase state) {
    _attached
      ..remove(state)
      ..add(state);
  }

  void _detach(_FlipBookStateBase state) {
    _attached.remove(state);
  }

  /// Whether a [FlipBook] is currently attached to this controller.
  bool get isAttached => _state != null;

  /// Index of the page the book is showing; 0 while detached.
  int get page => _state?._pageIndex ?? 0;

  /// Whether the flip sound is currently muted.
  bool get isMuted => _state?._muted ?? false;

  /// Flips forward one page with the curl animation, honouring the book's
  /// reading direction. Does nothing on the last page or while detached.
  Future<void> nextPage() async => _state?._goNext();

  /// Flips back one page with the curl animation, honouring the book's
  /// reading direction. Does nothing on the first page or while detached.
  Future<void> previousPage() async => _state?._goPrev();

  /// Jumps straight to the page at [index] with no animation — the same move
  /// as tapping an entry in the table of contents. Out-of-range indices are
  /// ignored.
  void jumpToPage(int index) {
    final state = _state;
    if (state == null || index < 0 || index >= state._pageCount) {
      return;
    }
    state._jumpToPage(index);
  }

  /// Opens the table of contents. Needs at least one page with a title.
  /// Ignored while a flip is in progress (EDG-05) — the TOC opening over a
  /// half-finished animation would show inconsistent page state.
  void openIndex() {
    final state = _state;
    if (state == null ||
        !state._hasIndex ||
        state._showIndex ||
        state._flipPhase != _FlipPhase.idle) {
      return;
    }
    state._toggleIndex();
  }

  /// Closes the table of contents if it is open.
  void closeIndex() {
    final state = _state;
    if (state == null || !state._showIndex) {
      return;
    }
    state._toggleIndex();
  }

  /// Mutes or unmutes the flip sound.
  void toggleMute() => _state?._toggleMute();
}

/// A multi-page book widget with a cylindrical page-curl transition.
///
/// Supply [pages] and a way out, and you have a working book:
///
/// ```dart
/// FlipBook(
///   onClose: () => Navigator.of(context).pop(),
///   pages: const [
///     FlipBookPage(title: 'My Book', tagline: 'a cover page'),
///     FlipBookPage(title: 'Chapter 1', bodySegments: ['Once upon a time.']),
///   ],
/// )
/// ```
///
/// **A feature exists only if you pass its object.** No [readAloud] means no
/// voice control, no highlight, and nothing about reading to configure — so
/// a plain book carries no settings for things it does not do. Pass the
/// object and every field inside it defaults sensibly until you override
/// it. The same holds for [marker], [footer], [header], [swipe] and
/// [contents].
///
/// The flip direction follows the ambient [Directionality]: in RTL locales
/// "next" curls the opposite way, matching how a real book reads.
class FlipBook extends StatefulWidget {
  /// Creates a flip book. Only [pages] and [onClose] are required.
  const FlipBook({
    super.key,
    required this.pages,
    required this.onClose,
    this.header = const FlipBookHeader(),
    this.footer = const FlipBookFooter(),
    this.readAloud,
    this.marker,
    this.bookmarks,
    this.swipe = const FlipBookSwipe(),
    this.contents = const FlipBookContents(),
    this.flipSpeed = FlipSpeed.medium,
    this.controller,
    this.shine,
    this.shadow,
    this.onFlipPastEnd,
  });

  /// The book's contents and everything about how a page is presented —
  /// the list, the paper colour, the type, the reading direction, where it
  /// opens, and where it is. See [FlipBookPages].
  final FlipBookPages pages;

  /// Called when the × close button is tapped.
  final VoidCallback onClose;

  /// Called when the reader swipes FORWARD on the last page — a flip the
  /// book itself cannot honour, because there is no next page.
  ///
  /// Null — the default — keeps the long-standing behaviour: the gesture is
  /// simply eaten and nothing moves. Pass a callback to give the gesture a
  /// meaning of your own; the classic one is closing the book, so a reader
  /// can swipe straight off the back cover. The book never decides this
  /// itself: what lies past the end is the app's business, not the page's.
  final VoidCallback? onFlipPastEnd;

  /// The top strip: the × close button and anything beside it. `null`
  /// removes it — then give the reader another way out.
  final FlipBookHeader? header;

  /// The bottom bar and every control on it. `null` removes it; drive the
  /// book through a [FlipBookController] instead.
  final FlipBookFooter? footer;

  /// Gives the book a voice. `null` — the default — means a silent book
  /// with no voice controls and no reading highlight.
  final FlipBookReadAloud? readAloud;

  /// Lets the reader mark passages with a pencil. `null` — the default —
  /// means no pencil. Independent of [readAloud]: a reader marks whether or
  /// not the book can speak.
  final FlipBookMarker? marker;

  /// The reader's two ways of keeping a place — a bookmark to carry on
  /// from, and saved pages to come back to. Null means neither button.
  final FlipBookBookmarks? bookmarks;

  /// Turning pages by hand, and the hint that teaches it.
  final FlipBookSwipe swipe;

  /// The table of contents the INDEX button opens.
  final FlipBookContents contents;

  /// Duration preset of the flip animation.
  final FlipSpeed flipSpeed;

  /// Drives the book from outside the widget — see [FlipBookController].
  final FlipBookController? controller;

  /// Strength of the sheen on the curling paper, 0–1. `null` (default)
  /// adapts to [pageColor] — full sheen on white paper, a whisper on dark
  /// paper. `0` removes the light completely.
  final double? shine;

  /// Strength of the curl's depth shadow, 0–1. `null` (default) uses the
  /// standard shadow; `0` removes it.
  final double? shadow;

  @override
  State<FlipBook> createState() => _FlipBookState();
}

/// Fallback look of the swipe hint when the caller gives no style.
const TextStyle _defaultSwipeHintStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.4,
  color: Color(0xFF555555),
);

/// The shared state every cluster works on. One bag of fields on purpose —
/// splitting FIELDS across mixins would invite double ownership; splitting
/// BEHAVIOUR is the win. Abstract members below are the cross-cluster calls,
/// so a mixin can invoke a sibling's behaviour without seeing its code.
abstract class _FlipBookStateBase extends State<FlipBook>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Shorthands onto the feature objects. A null footer/header/readAloud/
  // marker means that feature does not exist, so every read of it goes
  // through one of these rather than repeating the null check.
  FlipBookFooter? get _footer => widget.footer;
  FlipBookHeader? get _header => widget.header;
  FlipBookReadAloud? get _read => widget.readAloud;
  FlipBookMarker? get _marker => widget.marker;
  FlipBookBookmarks? get _bookmarks => widget.bookmarks;
  FlipBookSwipe get _swipe => widget.swipe;
  FlipBookSwipeHint? get _hint => widget.swipe.hint;
  FlipBookPageStyle get _pageStyle => widget.pages.style;

  int _pageIndex = 0;
  int _nextIndex = 0;
  _FlipPhase _flipPhase = _FlipPhase.idle;
  bool _muted = false;
  bool _showIndex = false;

  _ReadPhase _readPhase = _ReadPhase.idle;
  int _readSession = 0;

  /// Whether the current read session belongs to the play-all chain
  /// ([FlipBookReadAloud.playAll]) — set per tap, so ▶ stays page-only.
  bool _readChains = false;

  /// The sentences of the page being read, and which one the voice is on —
  /// null between sessions. The pair IS the read marker's state: pause
  /// keeps it (the mark holds its place), stop and navigation clear it.
  List<_SentenceRef> _readSentences = const [];
  int? _markedSentence;

  /// Marking mode: the pencil is on, so a drag marks text instead of
  /// turning the page. [_draft] is the range under the finger, awaiting
  /// Save or Cancel.
  bool _marking = false;

  /// How far the current pointer has travelled on each axis, accumulated from
  /// raw events. See _onSwipe: the drag recogniser cannot report this.
  Offset _pointerTravel = Offset.zero;

  ReaderMark? _draft;

  /// Pins the keep / discard row to the marked words. The block holding the
  /// draft is the target; the row at page level is the follower, so it keeps
  /// its place while the page scrolls.
  final LayerLink _draftLink = LayerLink();

  /// Where the marked words sit inside their own block, as the block last
  /// measured them. Null until the block reports, which is one frame after
  /// the drag — the row appears with the mark, not before it.
  Rect? _draftRect;

  /// Width of the block holding the draft, so the row can be placed against
  /// the right edge of a mark under RTL.
  double _draftBlockWidth = 0;

  /// The control name shown above the footer for FlipBook.controlLabelFor
  /// after a tap; null while nothing was tapped recently.
  String? _controlLabel;
  Timer? _controlLabelTimer;

  /// The reading pace the footer shows as chosen. Seeded from the caller's
  /// initial value and updated when the reader picks another, so the
  /// control stays correct even if the app does not rebuild.
  FlipBookReadSpeed _readSpeed = FlipBookReadSpeed.normal;

  bool _swipeHintVisible = false;

  /// Appearances used so far, counted for the life of the book — not
  /// swipes. See [_showSwipeHint].
  int _swipeHintShowCount = 0;
  Timer? _swipeHintTimer;

  /// Footer visibility while `FlipBookFooter.autoHide` is on; permanently
  /// true when it is off. The header has its own flag so the two hide
  /// independently, on one shared retire clock.
  bool _chromeVisible = true;
  bool _headerVisible = true;
  Timer? _chromeTimer;

  ui.Image? _capturedImage;
  final _repaintKey = GlobalKey();
  final _prevCaptureKey = GlobalKey();

  late final AnimationController _ctrl;
  late final CurvedAnimation _curved;

  int get _pageCount => widget.pages.items.length;
  bool get _hasIndex =>
      widget.pages.items.any((p) => p.title?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.pages.items.isNotEmpty) {
      _pageIndex =
          widget.pages.initialPage.clamp(0, widget.pages.items.length - 1);
      _nextIndex = _pageIndex;
    }
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.flipSpeed.duration,
    );
    _curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    widget.controller?._attach(this);
    if (_swipeHintEligible) {
      _showSwipeHint();
    }
    // Immersive mode opens as a pure page; the first tap reveals the
    // hidden chrome. In `always` mode the element simply is.
    _chromeVisible = !(_footer?.autoHide ?? false);
    _readSpeed = _read?.speed?.initial ?? FlipBookReadSpeed.normal;
    _headerVisible = !(_header?.autoHide ?? false);
  }

  /// Leaving the foreground stops ALL reading operations — the voice and
  /// the play-all chain alike. Without this the engine's stopped future
  /// would complete in the background and the chain would keep flipping a
  /// book nobody is looking at.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopReading();
    }
  }

  /// Whether the hint may still greet a page: it is enabled, swiping is on,
  /// and it has not used up its [FlipBookSwipeHint.maxShows] appearances.
  bool get _swipeHintEligible =>
      (_hint != null) &&
      _swipe.enabled &&
      _swipeHintShowCount < (_hint?.maxShows ?? 0);

  /// Shows the hint once and counts the appearance.
  ///
  /// Once per page, never repeating on it — a hint that keeps coming back
  /// nags a reader who is trying to read. It greets a page, fades, and
  /// after [FlipBookSwipeHint.maxShows] appearances it is gone for the
  /// life of the book.
  void _showSwipeHint() {
    _swipeHintShowCount++;
    _swipeHintVisible = true;
    _armSwipeHintHide();
    // The signal fires exactly once: the count only ever grows, and only
    // here, so == can match a single time.
    if (_swipeHintShowCount == (_hint?.maxShows ?? 0)) {
      _hint?.onRetired?.call();
    }
  }

  /// Fades the hint out after [FlipBookSwipeHint.showFor]. It does not
  /// come back on this page.
  void _armSwipeHintHide() {
    _swipeHintTimer?.cancel();
    _swipeHintTimer = Timer((_hint?.showFor ?? Duration.zero), () {
      if (mounted && _swipeHintVisible) {
        setState(() => _swipeHintVisible = false);
      }
    });
  }

  /// A swipe dismisses the hint it was showing — the reader clearly does
  /// not need it any more on this page. The appearance still counts; it was
  /// shown.
  void _dismissSwipeHint() {
    _swipeHintTimer?.cancel();
    if (_swipeHintVisible) {
      setState(() => _swipeHintVisible = false);
    }
  }

  /// The hint line: `‹‹‹‹ Swipe ››››` — chevrons darkest at the outer ends,
  /// fading step by step toward the text for a fade-away look. The chevrons
  /// overlap into a tight, broad train. Text, colour, size, and font all
  /// come from [FlipBookSwipeHint.text] / [FlipBookSwipeHint.style] /
  /// [FlipBookSwipeHint.arrowSize].
  /// The whole hint, wrapped in a semantic label so a caller's image or
  /// animation still announces itself to a screen reader.
  Widget _buildSwipeHint() {
    return Semantics(
      label: _hint?.text ?? '',
      excludeSemantics: true,
      child: _hint?.child ?? _buildDefaultSwipeHint(),
    );
  }

  Widget _buildDefaultSwipeHint() {
    final hint = _hint!;
    final nav = _footer?.nav ?? const FlipBookNavButtons();
    final style = hint.style ?? _defaultSwipeHintStyle;
    final color = style.color ?? const Color(0xFF555555);
    // Outermost chevron (dark) → the one touching the text (lightest).
    const fades = [1.0, 0.7, 0.45, 0.2];
    Widget arrow(IconData glyph, double fade) => Align(
          widthFactor: 0.6, // overlap neighbours into a tight ‹‹‹‹ train
          child: Icon(
            glyph,
            size: hint.arrowSize,
            color: color.withValues(alpha: color.a * fade),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // Scale down rather than overflow when a long hint text meets a
      // narrow phone — the line always fits on one row.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Directionality(
          // Visual order is fixed: left-pointing chevrons sit left, in
          // every locale. RTL scripts inside the Text still render
          // correctly.
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final fade in fades) arrow(nav.previousIcon, fade),
              const SizedBox(width: 10),
              Text(hint.text, style: style),
              const SizedBox(width: 10),
              for (final fade in fades.reversed) arrow(nav.nextIcon, fade),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(FlipBook old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      old.controller?._detach(this);
      widget.controller?._attach(this);
    }
    // EDG-03: a rebuilt flipSpeed must take effect, not stay frozen at
    // whatever initState saw.
    if (widget.flipSpeed != old.flipSpeed) {
      _ctrl.duration = widget.flipSpeed.duration;
    }
    // A chrome mode rebuilt to `always` must show the element — visibility
    // is otherwise only decided in initState, and an app switching modes at
    // runtime would keep a permanently hidden "always" footer.
    if (widget.footer?.autoHide != old.footer?.autoHide &&
        !(_footer?.autoHide ?? false)) {
      _chromeVisible = true;
    }
    if (widget.header?.autoHide != old.header?.autoHide &&
        !(_header?.autoHide ?? false)) {
      _headerVisible = true;
    }
    // EDG-02: a shrunken pages list must never leave the shown index past
    // the new end.
    final maxIndex = _pageCount == 0 ? 0 : _pageCount - 1;
    if (_pageIndex > maxIndex) {
      _pageIndex = maxIndex;
      // The shown page really changed — the persistence seam must hear it,
      // or an app restoring via pages.onChanged keeps a stale index forever.
      widget.pages.onChanged?.call(_pageIndex);
    }
    if (_nextIndex > maxIndex) {
      _nextIndex = maxIndex;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._detach(this);
    _swipeHintTimer?.cancel();
    _controlLabelTimer?.cancel();
    _chromeTimer?.cancel();
    // Reverse order of creation: the curve listens to the controller, so it
    // must detach before the controller goes away.
    _curved.dispose();
    _ctrl.dispose();
    _capturedImage?.dispose();
    super.dispose();
  }

  /// Fires the caller's [FlipBookSound.onFlip] — the package ships no sound
  /// of its own. Best-effort: a failing sound must never interrupt the flip.
  Future<void> _playFlipSound() async {
    try {
      await _footer?.sound?.onFlip.call();
    } catch (_) {
      // Sound is decoration; the flip goes on.
    }
  }

  void _toggleMute() => setState(() => _muted = !_muted);
  void _toggleIndex() => setState(() => _showIndex = !_showIndex);

  /// EDG-04: an explicit jump is the user's latest intent, so it wins over
  /// any flip in flight — the animation is aborted, its bitmap released, and
  /// the pending flip continuation sees a changed phase and gives up.
  void _jumpToPage(int index) {
    _stopReading();
    if (_flipPhase == _FlipPhase.animatingForward ||
        _flipPhase == _FlipPhase.animatingBackward) {
      _ctrl.stop();
    }
    final abandoned = _capturedImage;
    final changed = _pageIndex != index;
    setState(() {
      _flipPhase = _FlipPhase.idle;
      _capturedImage = null;
      _pageIndex = index;
      _showIndex = false;
      _swipeHintVisible = false;
    });
    abandoned?.dispose();
    // The hint greets a new page — until its appearances run out.
    if (_swipeHintEligible) {
      setState(_showSwipeHint);
    }
    if (changed) {
      widget.pages.onChanged?.call(_pageIndex);
    }
  }

  // ── Chrome visibility ──────────────────────────────────────────────────────
  // `autoHide: false` keeps an element permanently on. `autoHide: true` is the
  // immersive mode: a tap on the page toggles every auto-hiding element at
  // once, and revealed chrome retires by itself after `revealFor` of no
  // interaction. Footer and header carry the flag separately and are
  // independent — only the elements with autoHide on ever move.

  bool get _footerAuto => (_footer?.autoHide ?? false);
  bool get _headerAuto => (_header?.autoHide ?? false);

  void _toggleChrome() {
    if (!_footerAuto && !_headerAuto) {
      return;
    }
    final anyHidden =
        (_footerAuto && !_chromeVisible) || (_headerAuto && !_headerVisible);
    if (anyHidden) {
      _revealChrome();
    } else {
      _chromeTimer?.cancel();
      setState(() {
        if (_footerAuto) {
          _chromeVisible = false;
        }
        if (_headerAuto) {
          _headerVisible = false;
        }
      });
    }
  }

  void _revealChrome() {
    if (!_footerAuto && !_headerAuto) {
      return;
    }
    if ((_footerAuto && !_chromeVisible) || (_headerAuto && !_headerVisible)) {
      setState(() {
        if (_footerAuto) {
          _chromeVisible = true;
        }
        if (_headerAuto) {
          _headerVisible = true;
        }
      });
    }
    _armChromeHide();
  }

  /// (Re)starts the retire clock — called on reveal and on every chrome
  /// interaction, so a control never vanishes mid-use.
  void _armChromeHide() {
    _chromeTimer?.cancel();
    _chromeTimer =
        Timer((_footer?.revealFor ?? const Duration(seconds: 3)), () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_footerAuto) {
          _chromeVisible = false;
        }
        if (_headerAuto) {
          _headerVisible = false;
        }
      });
    });
  }

  // ── Forward flip (NEXT) ────────────────────────────────────────────────────
  // Captures the current page, shows the target page underneath, then peels
  // the captured snapshot away left→right (progress 0→1).

  Future<void> _flipToNext(int target) async {
    if (_flipPhase != _FlipPhase.idle || target < 0 || target >= _pageCount) {
      return;
    }
    _stopReading();

    if ((_footer?.sound != null) && !_muted) {
      unawaited(_playFlipSound());
    }

    // Capture the current page as bitmap so it can curl away — synchronous,
    // so there is no gap between deciding to flip and starting to animate.
    final captured = capturePage(
      _repaintKey,
      pixelRatio: captureRatioOf(context),
    );

    setState(() {
      _nextIndex = target;
      _capturedImage = captured;
      _flipPhase = _FlipPhase.animatingForward;
    });

    await _animateCurl(forward: true);

    if (!mounted || _flipPhase != _FlipPhase.animatingForward) {
      // Disposed, or a jump aborted this flip and owns the state now.
      return;
    }

    _finishFlip();
  }

  // ── Backward flip (PREV) ───────────────────────────────────────────────────
  // Phase 1: renders the target page below the current page for one frame and
  // captures it as a bitmap (invisible to the user — current page covers it).
  // Phase 2: animates the captured bitmap descending onto the current page
  // (progress 1→0) so strips carry the prev-page texture as they settle flat.

  Future<void> _flipToPrev(int target) async {
    if (_flipPhase != _FlipPhase.idle || target < 0 || target >= _pageCount) {
      return;
    }
    _stopReading();

    if ((_footer?.sound != null) && !_muted) {
      unawaited(_playFlipSound());
    }

    // Phase 1: render target page hidden below current page for capture.
    setState(() {
      _nextIndex = target;
      _flipPhase = _FlipPhase.capturingPrev;
    });

    // Wait one frame so the capture target is laid out and painted.
    final frameDone = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => frameDone.complete());
    await frameDone.future;

    if (!mounted || _flipPhase != _FlipPhase.capturingPrev) {
      // Disposed, or a jump aborted this flip during the frame wait.
      return;
    }

    final captured = capturePage(
      _prevCaptureKey,
      pixelRatio: captureRatioOf(context),
    );

    // Phase 2: animate the captured bitmap descending (progress 1→0).
    setState(() {
      _capturedImage = captured;
      _flipPhase = _FlipPhase.animatingBackward;
    });

    await _animateCurl(forward: false);

    if (!mounted || _flipPhase != _FlipPhase.animatingBackward) {
      return;
    }

    _finishFlip();
  }

  /// Runs the curl animation. If the widget is disposed mid-flight the
  /// returned [TickerFuture] simply never completes and `dispose()` has
  /// already released the captured image — no cleanup is missed.
  Future<void> _animateCurl({required bool forward}) =>
      forward ? _ctrl.forward(from: 0) : _ctrl.reverse(from: 1.0);

  void _finishFlip() {
    final toDispose = _capturedImage;
    final changed = _pageIndex != _nextIndex;
    setState(() {
      _pageIndex = _nextIndex;
      _flipPhase = _FlipPhase.idle;
      _capturedImage = null;
      _swipeHintVisible = false;
      // Marking belongs to the page it was started on. Carrying it across a
      // flip would leave the pencil lit on a page the reader never chose to
      // mark, and would let an unsaved draft outlive the text it points at.
      if (changed) {
        _marking = false;
        _draft = null;
        _draftRect = null;
      }
    });
    toDispose?.dispose();
    // The hint greets a new page — until its appearances run out.
    if (_swipeHintEligible) {
      setState(_showSwipeHint);
    }
    if (changed) {
      widget.pages.onChanged?.call(_pageIndex);
    }
  }

  /// Lays out a page from its optional parts.
  ///
  /// Three shapes:
  /// * `body` widget without printed title or tagline → the widget fills
  ///   the paper edge-to-edge (full layout control stays with the caller).
  /// * `body` widget under a printed title/tagline → the fixed layout: the
  ///   header text stays put, the body gets the remaining space.
  /// * text without a `body` → a text page the book lays out itself,
  ///   everything in one scroll view — long text scrolls, and every part
  ///   is markable text the read marker can follow.
  ///
  /// [live] is true only for the page actually being shown — capture
  /// targets and flip destinations are rendered with the marker off.
  Widget _pageContent(FlipBookPage page, {required bool live}) {
    final style = page.style ?? _pageStyle;
    final highlight = _read?.highlight ?? const FlipBookHighlight();
    final marker = _marker;
    final printedTitle = page.showTitleOnPage ? page.title : null;
    final marked = live ? _currentSentence : null;

    Widget markable(
      String text,
      TextStyle style,
      _ReadPart part, {
      int segment = 0,
      bool follow = false,
      int? maxLines,
      TextOverflow? overflow,
    }) {
      final range =
          marked != null && marked.part == part && marked.segment == segment
              ? marked.range
              : null;
      // The caller's own renderer, when they gave one: whatever it
      // returns IS the block, marker and all.
      final custom = _read?.highlight.builder;
      if (custom is ReadMarkerTextBuilder) {
        return Builder(
          builder: (context) => custom(
            context,
            ReadMarkerText(
              text: text,
              style: style,
              marked: range,
              maxLines: maxLines,
              overflow: overflow,
            ),
          ),
        );
      }
      // A mark belongs to a block, and title/tagline are blocks of their
      // own — hence their reserved segment numbers.
      final markSegment = switch (part) {
        _ReadPart.title => ReaderMark.titleSegment,
        _ReadPart.tagline => ReaderMark.taglineSegment,
        _ReadPart.body => segment,
      };
      final draft = _draft;
      // A part recedes only when it is BOTH read and faded. Excluded from
      // reading, it is not in the performance and must keep full ink; and a
      // heading can be read yet never fade, so it stays the page's anchor
      // instead of flickering every time the body speaks.
      final partDims = switch (part) {
        _ReadPart.title =>
          (_read?.readTitle ?? true) && (_read?.fadeTitle ?? true),
        _ReadPart.tagline =>
          (_read?.readTagline ?? true) && (_read?.fadeTagline ?? true),
        _ReadPart.body =>
          (_read?.readBody ?? true) && (_read?.fadeBody ?? true),
      };
      return MarkedText(
        text: text,
        style: style,
        marked: range,
        // The dim belongs to the page: while any block holds the marker,
        // every other participating block recedes.
        dimmed: marked != null && range == null && partDims,
        markerStyle: highlight.style,
        markerColor: highlight.color,
        markerRadius: highlight.radius,
        dimOpacity: highlight.dimOpacity,
        autoFollow: follow,
        savedMarks: _marksFor(page, markSegment),
        savedMarkColor: (marker?.color ?? const Color(0x338A8A8A)),
        draftMark: draft != null && draft.segment == markSegment
            ? TextRange(start: draft.start, end: draft.end)
            : null,
        // The block anchors and measures; the page draws the row. See
        // _buildMarkActions.
        draftLink:
            draft != null && draft.segment == markSegment ? _draftLink : null,
        onDraftRect:
            draft != null && draft.segment == markSegment ? _onDraftRect : null,
        onDraftMark: live && _marking && _canMark
            ? (range) => _onDraftMark(markSegment, range, text)
            : null,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    if (page.body == null && (page.hasText || page.bodyWidgets.isNotEmpty)) {
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (printedTitle != null)
            markable(printedTitle, style.titleStyle, _ReadPart.title,
                follow: live),
          if (printedTitle != null && page.tagline != null)
            const SizedBox(height: 6),
          if (page.tagline != null)
            markable(page.tagline!, style.taglineStyle, _ReadPart.tagline,
                follow: live),
          if (printedTitle != null || page.tagline != null)
            const SizedBox(height: 20),
          ..._buildBodyBlocks(page, markable, live: live),
        ],
      );
      // Each page keeps its own scroll position, and a flip opens the next
      // page at its top instead of inheriting this one's. A page WITH an id
      // is keyed by it — stable across rebuilds, so a caller that recreates
      // equal config objects (a state-management rebuild) does not cost the
      // reader their place; ObjectKey did exactly that on 2026-09-02, because
      // it compares identity and a rebuilt page is a new object. Id-less
      // pages keep the identity key: with no name of their own, the object is
      // the only identity there is (and const page lists never change it).
      // The padding belongs to the TEXT, not to the page: on the scroll view
      // it would wrap the background too, and a decorated page could never
      // reach the screen edge. The background fills the page; only the words
      // are inset.
      return SingleChildScrollView(
        key: page.id != null ? ValueKey('page-${page.id}') : ObjectKey(page),
        padding: page.background == null ? style.padding : null,
        child: page.background == null
            ? column
            : Stack(
                children: [
                  Positioned.fill(child: page.background!),
                  Padding(padding: style.padding, child: column),
                ],
              ),
      );
    }

    if (printedTitle == null && page.tagline == null) {
      return page.body ?? const SizedBox.shrink();
    }
    return Padding(
      padding: style.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // maxLines bounds the printed title so a long one at large text
          // scale can never push the body into a RenderFlex overflow
          // (LAY-06).
          if (printedTitle != null)
            markable(printedTitle, style.titleStyle, _ReadPart.title,
                maxLines: 3, overflow: TextOverflow.ellipsis),
          if (printedTitle != null && page.tagline != null)
            const SizedBox(height: 6),
          if (page.tagline != null)
            markable(page.tagline!, style.taglineStyle, _ReadPart.tagline,
                maxLines: 3, overflow: TextOverflow.ellipsis),
          if (page.body != null) ...[
            const SizedBox(height: 20),
            Expanded(child: page.body!),
          ],
        ],
      ),
    );
  }

  /// The body of a text page: one block per `bodySegments` entry, or one
  /// block for a whole `bodyText`. Separate blocks are what let the marker
  /// address a single segment, and they carry the paragraph spacing.
  List<Widget> _buildBodyBlocks(
    FlipBookPage page,
    _MarkableBuilder markable, {
    required bool live,
  }) {
    final style = (page.style ?? _pageStyle).bodyStyle;
    final segments = page.bodySegments;
    if (segments == null) {
      final text = page.bodyText;
      if (text == null || text.isEmpty) {
        return const [];
      }
      return [markable(text, style, _ReadPart.body, follow: live)];
    }
    final blocks = <Widget>[];
    void gap() {
      if (blocks.isNotEmpty) {
        blocks.add(const SizedBox(height: 16));
      }
    }

    for (var i = 0; i < segments.length; i++) {
      // A widget keyed to this index sits BEFORE the segment.
      final widgetHere = page.bodyWidgets[i];
      if (widgetHere != null) {
        gap();
        blocks.add(widgetHere);
      }
      if (segments[i].trim().isEmpty) {
        continue;
      }
      gap();
      blocks.add(
        markable(segments[i], style, _ReadPart.body, segment: i, follow: live),
      );
    }
    // A key past the last segment appends.
    final trailing = page.bodyWidgets[segments.length];
    if (trailing != null) {
      gap();
      blocks.add(trailing);
    }
    return blocks;
  }

  TextDirection get _direction =>
      widget.pages.textDirection ?? Directionality.of(context);

  /// A horizontal fling turns the page — the same smooth animation the
  /// buttons trigger, direction-aware: in LTR a leftward swipe goes
  /// forward; in RTL a rightward swipe does.
  void _onSwipe(DragEndDetails details) {
    // Marking owns the drag: a reader dragging out a passage must not have
    // the page turn under their finger.
    if (!_swipe.enabled ||
        _marking ||
        _showIndex ||
        _flipPhase != _FlipPhase.idle) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 80) {
      return; // Too gentle to be a page turn.
    }
    // A vertical flick must never turn the page.
    //
    // details.velocity cannot answer this: a HorizontalDragGestureRecognizer
    // reports velocity constrained to its OWN axis, so dy is always zero.
    //
    // Raw pointer travel is the honest measure — a Listener sees every move
    // event whatever the gesture arena decides, so the vertical component
    // survives to be compared.
    if (_pointerTravel.dx.abs() <= _pointerTravel.dy.abs()) {
      return; // Predominantly vertical — a scroll, not a page turn.
    }
    final backward = _direction == TextDirection.rtl
        ? velocity < 0 // RTL: leftward swipe goes back.
        : velocity > 0; // LTR: rightward swipe goes back.
    // Only a swipe that actually turns a page counts toward "learned" —
    // a fling at the edge of the book flips nothing and proves nothing.
    final canFlip = backward ? _pageIndex > 0 : _pageIndex < _pageCount - 1;
    if (!canFlip) {
      // A forward swipe past the last page is the one impossible flip the
      // app may claim (onFlipPastEnd); a backward swipe on page one stays
      // meaningless. Fired only from a real gesture — controller jumps and
      // the play-all chain land in _goNext, which stays silent.
      if (!backward) {
        widget.onFlipPastEnd?.call();
      }
      return;
    }
    _dismissSwipeHint(); // The reader is swiping; the hint has done its job.
    unawaited(backward ? _goPrev() : _goNext());
  }

  /// Direction-aware navigation: in RTL the forward flip uses the backward
  /// animation so the page curls the way an RTL book actually turns.
  Future<void> _goNext() {
    final target = _pageIndex + 1;
    if (target >= _pageCount) {
      return Future<void>.value();
    }
    return _direction == TextDirection.rtl
        ? _flipToPrev(target)
        : _flipToNext(target);
  }

  Future<void> _goPrev() {
    final target = _pageIndex - 1;
    if (target < 0) {
      return Future<void>.value();
    }
    return _direction == TextDirection.rtl
        ? _flipToNext(target)
        : _flipToPrev(target);
  }

  Widget _buildPage(int index) {
    // EDG-01: an empty pages list renders blank paper, never a RangeError —
    // apps that build pages from async data show the book before the fetch.
    final page = _pageCount == 0
        ? const FlipBookPage()
        : widget.pages.items[index.clamp(0, _pageCount - 1)];
    // A page that prints nothing above its body owns the WHOLE screen —
    // the chrome floats on top instead of reserving paper-coloured strips
    // above and below, so a dark cover is dark to the screen edge.
    final fullBleed = (page.title == null || !page.showTitleOnPage) &&
        page.tagline == null &&
        page.body != null;
    return _FlipBookScaffold(
      rtl: _direction == TextDirection.rtl,
      fullBleed: fullBleed,
      content: _pageContent(page, live: index == _pageIndex),
      footer: _footer ?? const FlipBookFooter(),
      header: _header,
      read: _read,
      marker: _marker,
      bookmarks: _bookmarks,
      isBookmarked: _isBookmarked,
      isSaved: _isSaved,
      onBookmark: _bookmarks?.onBookmark != null ? _onBookmark : null,
      // A page with no id cannot be saved — there is nothing to remember it
      // by — so the button is absent rather than dead.
      onToggleSaved:
          _bookmarks?.onSavedChanged != null && _currentPageId != null
              ? _onToggleSaved
              : null,
      pageNumber: widget.pages.showNumber ? '${index + 1} / $_pageCount' : null,
      headerAction: _header?.action,
      hasIndex: _hasIndex,
      isMuted: _muted,
      showHeader: (_header != null),
      showFooter: (_footer != null),
      onClose: widget.onClose,
      onNext: (_footer?.nav.show ?? false) && index < _pageCount - 1
          ? _goNext
          : null,
      onPrev: (_footer?.nav.show ?? false) && index > 0 ? _goPrev : null,
      onMuteToggle: (_footer?.sound != null) &&
              (_footer?.sound?.showMute ?? false) &&
              _footer?.sound?.onFlip != null
          ? _toggleMute
          : null,
      readPhase: _readPhase,
      canPauseReading: _canPauseReading,
      onReadPlay: _read?.onRead != null
          ? () => _readPhase == _ReadPhase.paused
              ? _resumeReading()
              : _playReading(index)
          : null,
      onReadPlayAll: (_read?.playAll ?? false) && _read?.onRead != null
          ? () => _playReading(index, chain: true)
          : null,
      onReadPause: _pauseReading,
      onReadStop: _stopReading,
      onToggleIndex: _toggleIndex,
      readSpeed: _readSpeed,
      onReadSpeedChanged: _read?.speed == null
          ? null
          : (speed) {
              setState(() => _readSpeed = speed);
              _read!.speed!.onChanged?.call(speed);
            },
      marking: _marking,
      onToggleMarking: _canMark ? _toggleMarking : null,
      // The trash belongs to THIS page: a mark elsewhere in the book must not
      // put a live clear button on a page that has none.
      onClearMarks: _pageHasMarks ? _clearMarks : null,
      chromeVisible: _chromeVisible || _showIndex,
      headerVisible: _headerVisible || _showIndex,
      onFooterInteraction: _footerAuto ? _armChromeHide : null,
      onHeaderInteraction: _headerAuto ? _armChromeHide : null,
      controlLabel: _controlLabel,
      onControlUsed: _showControlLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = Scaffold(
      backgroundColor: widget.pages.paperColor,
      body: Listener(
        // Raw pointer travel, recorded before any recogniser claims the
        // gesture — this is what tells a swipe from a scroll.
        onPointerDown: (_) => _pointerTravel = Offset.zero,
        onPointerMove: (e) => _pointerTravel += e.delta,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _onSwipe,
          // Immersive mode: a tap on the page toggles every auto-hiding
          // element. Taps that land on buttons are consumed by them and
          // never reach this.
          onTap: _footerAuto || _headerAuto ? _toggleChrome : null,
          // No SafeArea here: pages paint to the physical screen edges (a
          // black cover is black to the last pixel). The chrome, the TOC,
          // and the built-in page layout carry their own SafeArea, so
          // buttons and text still clear notches and system bars.
          child: Stack(
            fit: StackFit.expand,
            children: [
              // PREV capture target — rendered below the current page so it is
              // painted (toImage works) but invisible to the user.
              // ColoredBox gives it a solid background so it can be captured
              // correctly (page content on pageColor, no transparency).
              if (_flipPhase == _FlipPhase.capturingPrev)
                RepaintBoundary(
                  key: _prevCaptureKey,
                  child: ColoredBox(
                    color: widget.pages.paperColor,
                    child: _buildPage(_nextIndex),
                  ),
                ),

              if (_showIndex && _hasIndex)
                SafeArea(
                  child: _IndexPage(
                    pages: widget.pages.items,
                    currentPage: _pageIndex,
                    headerAction: _header?.action,
                    contents: widget.contents,
                    footer: _footer ?? const FlipBookFooter(),
                    header: _header,
                    onSelect: _jumpToPage,
                    onClose: _toggleIndex,
                    onExport: widget.contents.export != null
                        ? () => _openExport(widget.contents.export!)
                        : null,
                  ),
                )
              else if (_flipPhase == _FlipPhase.animatingForward)
                // NEXT: destination page shows through as the current page peels
                // away. IgnorePointer keeps layout identical (buttons present)
                // so there is no footer shift when animation ends.
                IgnorePointer(
                  child: _buildPage(_nextIndex),
                )
              else
                // PREV (animating or idle): ColoredBox makes this page opaque so
                // it fully hides the capture target stacked below during
                // _capturingPrev. IgnorePointer blocks touches during animation
                // without changing the widget tree, so no layout shift occurs.
                IgnorePointer(
                  ignoring: _flipPhase == _FlipPhase.animatingBackward,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: ColoredBox(
                      color: widget.pages.paperColor,
                      child: _buildPage(_pageIndex),
                    ),
                  ),
                ),

              if ((_flipPhase == _FlipPhase.animatingForward ||
                      _flipPhase == _FlipPhase.animatingBackward) &&
                  !_showIndex)
                AnimatedBuilder(
                  animation: _curved,
                  builder: (_, __) => CurlOverlay(
                    progress: _curved.value,
                    pageImage: _capturedImage,
                    pageColor: widget.pages.paperColor,
                    shine: widget.shine,
                    shadow: widget.shadow,
                  ),
                ),

              // The reader's keep / discard row, pinned to the words they just
              // dragged out. It lives HERE, at page level, precisely so it is
              // never confined to the height of one paragraph — see
              // _buildMarkActionsOverlay.
              if (_draft != null && _draftRect != null && !_showIndex)
                _buildMarkActionsOverlay(),

              // Transient swipe hint — no pill, no background: by default
              // just the text with fading chevrons. It greets a page once,
              // fades, and retires after FlipBookSwipeHint.maxShows.
              if ((_hint != null) && _swipe.enabled && !_showIndex)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 96,
                  child: IgnorePointer(
                    child: Center(
                      // AnimatedSwitcher rather than AnimatedOpacity so the
                      // hint leaves the tree entirely while hidden — its
                      // chevrons must not pollute icon finders or semantics.
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        child: _swipeHintVisible
                            ? _buildSwipeHint()
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              // Immersive mode, mouse platforms: hovering over the book's
              // bottom (footer) or top (header) edge reveals the hidden
              // chrome — the desktop/web equivalent of the tap. Mouse-only;
              // touches pass through.
              if (_footerAuto)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 96,
                  child: MouseRegion(
                    opaque: false,
                    hitTestBehavior: HitTestBehavior.translucent,
                    onEnter: (_) => _revealChrome(),
                  ),
                ),
              if (_headerAuto)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 96,
                  child: MouseRegion(
                    opaque: false,
                    hitTestBehavior: HitTestBehavior.translucent,
                    onEnter: (_) => _revealChrome(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final dir = widget.pages.textDirection;
    return dir == null ? book : Directionality(textDirection: dir, child: book);
  }

  // ── The cross-cluster contract ─────────────────────────────────────────────
  // Everything below is implemented by a mixin and called from outside it.
  // This list IS the coupling between the clusters, made visible: a new
  // cross-call must be added here, where a reviewer sees the dependency —
  // that is the point of the 2026-09-02 split.

  // _ReadAloudMixin
  void _playReading(int page, {bool chain = false});
  void _pauseReading();
  void _resumeReading();
  void _stopReading();
  bool get _canPauseReading;
  _SentenceRef? get _currentSentence;

  // _MarksMixin
  bool get _canMark;
  bool get _pageHasMarks;
  bool get _isBookmarked;
  bool get _isSaved;
  String? get _currentPageId;
  void _toggleMarking();
  void _clearMarks();
  void _onBookmark();
  void _onToggleSaved();
  void _onDraftMark(int segment, TextRange range, String blockText);
  void _onDraftRect(Rect rect, double blockWidth);
  List<TextRange> _marksFor(FlipBookPage page, int segment);
  Widget _buildMarkActionsOverlay();
  Future<void> _openExport(FlipBookExport export);
  void _showControlLabel(String label);
}

/// The state [FlipBook] actually creates: the shared base plus the two
/// behaviour clusters. Deliberately empty — everything it is lives in the
/// pieces, which is the whole idea.
class _FlipBookState extends _FlipBookStateBase
    with _ReadAloudMixin, _MarksMixin {}
