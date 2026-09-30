part of 'flip_book.dart';

// ── Scaffold ──────────────────────────────────────────────────────────────────

class _FlipBookScaffold extends StatelessWidget {
  const _FlipBookScaffold({
    required this.content,
    required this.footer,
    required this.rtl,
    this.header,
    this.read,
    this.marker,
    this.bookmarks,
    this.isBookmarked = false,
    this.isSaved = false,
    this.onBookmark,
    this.onToggleSaved,
    required this.isMuted,
    required this.hasIndex,
    required this.readPhase,
    required this.canPauseReading,
    required this.fullBleed,
    this.showHeader = true,
    this.showFooter = true,
    this.headerVisible = true,
    this.onHeaderInteraction,
    this.readSpeed = FlipBookReadSpeed.normal,
    this.onReadSpeedChanged,
    this.marking = false,
    this.onToggleMarking,
    this.onClearMarks,
    this.pageNumber,
    this.headerAction,
    this.onClose,
    this.onNext,
    this.onPrev,
    this.onMuteToggle,
    this.onReadPlay,
    this.onReadPlayAll,
    this.onReadPause,
    this.onReadStop,
    this.onToggleIndex,
    this.chromeVisible = true,
    this.onFooterInteraction,
    this.controlLabel,
    this.onControlUsed,
  });

  /// Reading direction, taken from the book rather than from an ambient
  /// [Directionality], so an explicit `pages.textDirection` still wins.
  final bool rtl;

  final Widget content;

  /// The bar and its controls. Never null here: the scaffold is only built
  /// when a footer exists, or with defaults for a chrome-free book.
  final FlipBookFooter footer;

  /// The top strip, when the book has one.
  final FlipBookHeader? header;

  /// Read-aloud, when the book can speak — its labels and control content.
  final FlipBookReadAloud? read;

  /// Reader marking, when it is switched on.
  final FlipBookMarker? marker;

  /// The bookmark and save-page controls, when the book has them.
  final FlipBookBookmarks? bookmarks;

  /// Whether the page on screen is the one to carry on from.
  final bool isBookmarked;

  /// Whether the page on screen is in the reader's saved set.
  final bool isSaved;

  /// Keeps this page as the place to carry on from. Null hides the button.
  final VoidCallback? onBookmark;

  /// Adds or removes this page from the saved set. Null hides the button.
  final VoidCallback? onToggleSaved;
  final bool isMuted;
  final bool hasIndex;
  final _ReadPhase readPhase;
  final bool canPauseReading;
  final bool fullBleed;
  final String? pageNumber;
  final Widget? headerAction;
  final VoidCallback? onClose;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onReadPlay;
  final VoidCallback? onReadPlayAll;
  final VoidCallback? onReadPause;
  final VoidCallback? onReadStop;
  final VoidCallback? onToggleIndex;

  /// Whether the header and the footer render at all — the structural
  /// switches, independent of the chrome visibility animation below.
  final bool showHeader;
  final bool showFooter;

  /// Footer visibility — while false the footer fades out
  /// and stops accepting taps.
  final bool chromeVisible;

  /// Header visibility (FlipBook.headerChrome) — same animation as the
  /// footer, hiding upward instead of sinking.
  final bool headerVisible;

  /// Fired on any pointer-down inside the footer / header so the auto-hide
  /// clock restarts; null outside autoHide mode.
  final VoidCallback? onFooterInteraction;
  final VoidCallback? onHeaderInteraction;

  /// The chosen reading speed, and the seam that reports a change. A null
  /// callback hides the control.
  final FlipBookReadSpeed readSpeed;
  final ValueChanged<FlipBookReadSpeed>? onReadSpeedChanged;

  /// Reader marking: whether the pencil is currently on, whether a dragged
  /// passage is waiting to be kept, and the four actions. A null
  /// [onToggleMarking] hides the pencil; a null [onClearMarks] hides the
  /// trash, which is how it appears only once something is saved.
  final bool marking;
  final VoidCallback? onToggleMarking;
  final VoidCallback? onClearMarks;

  /// The control name to show above the footer right now, or null.
  final String? controlLabel;

  /// Reports the name of a control the reader just tapped.
  final ValueChanged<String>? onControlUsed;

  @override
  Widget build(BuildContext context) {
    if (!showHeader && !showFooter) {
      // Chrome-free book: pure pages, driven by a FlipBookController.
      return content;
    }
    // EVERY page paints edge to edge and the chrome floats above it — so
    // dark pages are fully dark to the physical screen edge, and in
    // autoHide mode a hidden footer leaves no dead band. Body-only pages
    // own the whole surface (and their own safe insets, like the example's
    // magazine cover); the built-in structured layout is kept inside
    // SafeArea, clearing notches before `pagePadding` clears the bars.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (fullBleed) content else SafeArea(child: content),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                _chromeWrap(
                  _header(),
                  visible: headerVisible,
                  onInteraction: onHeaderInteraction,
                  hiddenOffset: const Offset(0, -0.25),
                ),
              const Spacer(),
              if (showFooter)
                _chromeWrap(
                  _footer(),
                  visible: chromeVisible,
                  onInteraction: onFooterInteraction,
                  hiddenOffset: const Offset(0, 0.25),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Chrome auto-hide: fade + slight travel while hidden, untappable, and
  /// out of the semantics tree — a screen reader must not focus invisible
  /// buttons. Interactions inside visible chrome restart the clock.
  Widget _chromeWrap(
    Widget child, {
    required bool visible,
    required VoidCallback? onInteraction,
    required Offset hiddenOffset,
  }) {
    return Listener(
      onPointerDown: onInteraction == null ? null : (_) => onInteraction(),
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: AnimatedSlide(
              offset: visible ? Offset.zero : hiddenOffset,
              duration: const Duration(milliseconds: 220),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return _FlipBookHeader(
      closeIcon: (header?.closeIcon ?? Icons.close),
      closeIconColor: (header?.closeColor ?? Colors.black54),
      closeLabel: (header?.closeLabel ?? 'Close'),
      onClose: onClose,
      headerAction: headerAction,
      closeAtEnd: header?.closeAtEnd ?? false,
    );
  }

  Widget _footer() {
    // Two rows, because one row of nine icons on a phone is a scrum.
    // Line 1 is the BOOK: where you are and how you move. Line 2 is the
    // VOICE: everything that makes a sound. A reader looking for "next
    // page" never has to scan past a play button to find it.
    final voice = _voiceRow();
    final bar = Column(
      key: FlipBookKeys.footerBar,
      mainAxisSize: MainAxisSize.min,
      children: [
        _footerButtons(),
        if (voice != null) ...[const SizedBox(height: 2), voice],
      ],
    );
    // A surface behind the controls: over a photo or dark paper a bare icon
    // row is unreadable. Transparent restores the floating look the book had
    // before 0.2.0.
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: footer.color,
        borderRadius: BorderRadius.circular(footer.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: bar,
      ),
    );
    final inset = footer.horizontalInset;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset ?? 12, 0, inset ?? 12, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The tapped control names itself for a moment. Icons cannot
          // explain themselves, and a tooltip needs a long-press nobody
          // performs on a phone — so the book simply says the word.
          _controlLabel(),
          // With an inset the bar takes the full remaining width, so its
          // edges sit exactly where the page's text does; the Wrap inside
          // spreads the controls across it. Without one, content-sized as
          // always.
          if (inset != null)
            SizedBox(width: double.infinity, child: surface)
          else
            surface,
        ],
      ),
    );
  }

  /// The transient label above the footer naming the control just tapped.
  /// Reserves its own height so the footer never jumps as it comes and goes.
  Widget _controlLabel() {
    return SizedBox(
      height: 30,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: controlLabel == null
              ? const SizedBox.shrink()
              : DecoratedBox(
                  key: ValueKey(controlLabel),
                  decoration: BoxDecoration(
                    color: footer.tapLabelColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(controlLabel!, style: footer.tapLabelStyle),
                  ),
                ),
        ),
      ),
    );
  }

  /// 0.5x · 1x · 1.5x — the reader's own pace. The package only reports the
  /// choice; the app applies it to its speech engine.
  /// Takes the settings rather than reaching for `read!.speed!`.
  ///
  /// The double bang was safe only because the single call site checked first
  /// — the invariant lived in the caller, not in the type, so any second call
  /// site would have crashed. A parameter carries the guarantee.
  Widget _speedControl(FlipBookSpeedControl speedSettings) {
    Widget option(FlipBookReadSpeed speed, String label) {
      final selected = speed == readSpeed;
      final fill = speedSettings.selectedColor ?? footer.iconColor;
      final text = Text(
        label,
        style: selected
            ? (speedSettings.selectedStyle ??
                footer.pageNumberStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  color: footer.color,
                ))
            : (speedSettings.style ?? footer.pageNumberStyle),
      );
      return _FooterControl(
        semanticLabel: '$label ${speedSettings.semantics}',
        onTap: () {
          // The tapped speed names itself like every other control:
          // a bolder weight alone is hard to spot.
          onControlUsed?.call('$label ${speedSettings.tapSuffix}');
          onReadSpeedChanged!(speed);
        },
        child: selected
            // A filled pill, not just a heavier weight.
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: text,
                ),
              )
            : text,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        label: speedSettings.semantics,
        container: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final speed in speedSettings.options) ...[
                if (speed != speedSettings.options.first)
                  const SizedBox(width: 14),
                option(speed, _speedLabel(speedSettings, speed)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The label of one speed, from the caller's wording.
  String _speedLabel(FlipBookSpeedControl settings, FlipBookReadSpeed speed) =>
      switch (speed) {
        FlipBookReadSpeed.slow => settings.slowLabel,
        FlipBookReadSpeed.normal => settings.normalLabel,
        FlipBookReadSpeed.fast => settings.fastLabel,
      };

  /// One footer control: the caller's widget when they gave one, otherwise
  /// the built-in icon. Tapping announces [label] through [onControlUsed].
  /// [label] is the short word flashed above the footer on a tap;
  /// [semanticLabel] is the fuller sentence a screen reader announces. They
  /// differ on purpose — "PLAY" is right on screen, "Read this page aloud"
  /// is right in the ear.
  Widget _control({
    required Widget? content,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return _FooterControl(
      semanticLabel: semanticLabel ?? label,
      onTap: () {
        onControlUsed?.call(label);
        onTap();
      },
      child: content ?? Icon(icon, size: footer.iconSize, color: color),
    );
  }

  /// The footer is three flexible zones — left, centre, right — and each
  /// zone scales its own contents down (FittedBox) when the screen is
  /// narrow or the font scale is large, so no control is ever clipped.
  Widget _footerButtons() {
    // One evenly spread row, not three weighted groups.
    //
    // The groups were `Expanded` with fixed flexes, and each was a
    // `FittedBox`: a group that could not fit SHRANK its icons — and their
    // tap targets with them — while its neighbours kept empty space. Five
    // controls in a two-sevenths slot came out at about half size and were
    // genuinely hard to hit.
    //
    // `Wrap` with `spaceEvenly` spreads every control across the whole bar
    // and, unlike a `Row`, drops to a second line instead of overflowing on
    // a narrow phone. Nothing is ever scaled down to make it fit.
    //
    // 🔴 EXCEPT in a stretched bar (FTR-02, found on device 2026-09-02): its
    // width is fixed, so when the trash joined the row after a first save,
    // the Wrap pushed NEXT onto a second centred line and the whole footer
    // grew mid-session. A fixed-width bar therefore gives every control an
    // EQUAL slot and lets each scale down a touch instead — all of them
    // together, uniformly, which is exactly what the old three-group layout
    // failed to do (it shrank one crowded group while its neighbours kept
    // empty space). Height stays constant; a control appearing just
    // redistributes the line.
    final controls = [
      if (hasIndex && onToggleIndex != null)
        _control(
          content: footer.index.child,
          icon: footer.index.icon,
          label: footer.index.label,
          color: footer.iconColor,
          onTap: onToggleIndex!,
        ),
      if (onBookmark != null)
        _control(
          content: isBookmarked
              ? bookmarks?.bookmarkedChild
              : bookmarks?.bookmarkChild,
          icon: isBookmarked
              ? (bookmarks?.bookmarkedIcon ?? Icons.bookmark)
              : (bookmarks?.bookmarkIcon ?? Icons.bookmark_border),
          label: isBookmarked
              ? (bookmarks?.bookmarkedLabel ?? '')
              : (bookmarks?.bookmarkLabel ?? ''),
          color: isBookmarked
              ? (bookmarks?.activeColor ?? bookmarks?.color ?? footer.iconColor)
              : (bookmarks?.color ?? footer.iconColor),
          onTap: onBookmark!,
        ),
      if (onToggleSaved != null)
        _control(
          content: isSaved ? bookmarks?.savedChild : bookmarks?.saveChild,
          icon: isSaved
              // A star reads as "favourite". These pages are the ones the
              // reader collects and exports, so the glyph says "add to my
              // set" and, once added, says it is in.
              ? (bookmarks?.savedIcon ?? Icons.library_add_check)
              : (bookmarks?.saveIcon ?? Icons.library_add),
          label: isSaved
              ? (bookmarks?.unsaveLabel ?? '')
              : (bookmarks?.saveLabel ?? ''),
          color: isSaved
              ? (bookmarks?.activeColor ?? bookmarks?.color ?? footer.iconColor)
              : (bookmarks?.color ?? footer.iconColor),
          onTap: onToggleSaved!,
        ),
      if (onToggleMarking != null)
        _control(
          content: marker?.pencil,
          icon: Icons.edit_outlined,
          label:
              marking ? (marker?.stopLabel ?? '') : (marker?.pencilLabel ?? ''),
          // The pencil stays lit while marking is on, so the
          // reader can see why swiping stopped turning pages.
          // activeColor first: the wash-made-opaque fallback vanishes the
          // moment wash and footer share a family (MRK-16).
          color: marking
              ? (marker?.activeColor ??
                  (marker?.color ?? const Color(0x338A8A8A))
                      .withValues(alpha: 1))
              : footer.iconColor,
          onTap: onToggleMarking!,
        ),
      if (onClearMarks != null)
        _control(
          content: marker?.clear,
          icon: Icons.delete_outline,
          label: (marker?.clearLabel ?? ''),
          color: footer.iconColor,
          onTap: onClearMarks!,
        ),
      if (pageNumber != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(pageNumber!, style: footer.pageNumberStyle),
        ),
      // A Row reverses its children under RTL, so "previous" lands on
      // the right — but the GLYPH is not mirrored with it, which showed an
      // Arabic reader "> <" where the arrows should read "< >". Swap the
      // default chevrons so each still points the way it travels. A caller
      // who supplied their own icon or child gets it untouched: mirroring
      // someone else's artwork would be a guess.
      if (onPrev != null)
        _navControl(
          content: footer.nav.previousChild,
          icon: _navIcon(footer.nav.previousIcon, back: true, rtl: rtl),
          label: footer.nav.previousLabel,
          onTap: onPrev!,
        ),
      if (onNext != null)
        _navControl(
          content: footer.nav.nextChild,
          icon: _navIcon(footer.nav.nextIcon, back: false, rtl: rtl),
          label: footer.nav.nextLabel,
          onTap: onNext!,
        ),
    ];
    if (footer.horizontalInset == null) {
      return Wrap(
        alignment: WrapAlignment.spaceEvenly,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 2,
        children: controls,
      );
    }
    return Row(
      children: [
        for (final control in controls)
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: control,
            ),
          ),
      ],
    );
  }

  /// Line 2 of the footer: everything that makes a sound — the flip-sound
  /// speaker, the voice transport, and the pace.
  ///
  /// Null when the book has neither a voice nor a mute button, and then the
  /// footer is a single row again — a silent book must not pay for an empty
  /// strip.
  Widget? _voiceRow() {
    final hasVoice = onReadPlay != null;
    final hasMute = onMuteToggle != null;
    if (!hasVoice && !hasMute) {
      return null;
    }
    // The pace shows only while the voice is actually speaking — paused or
    // idle, there is nothing to be fast or slow about.
    // Resolved to a value, not a boolean: the widget below then needs no
    // bang at all, and the "is it configured" question is answered once.
    final speed = read?.speed;
    final speedSettings = (onReadSpeedChanged != null &&
            speed != null &&
            speed.options.isNotEmpty &&
            readPhase == _ReadPhase.playing)
        ? speed
        : null;
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        if (hasMute)
          _control(
            content: isMuted ? footer.sound?.offChild : footer.sound?.onChild,
            icon: isMuted
                ? (footer.sound?.offIcon ?? Icons.volume_off)
                : (footer.sound?.onIcon ?? Icons.volume_up),
            label: isMuted
                ? (footer.sound?.unmuteLabel ?? '')
                : (footer.sound?.muteLabel ?? ''),
            color: (footer.sound?.color ?? footer.iconColor),
            onTap: onMuteToggle!,
          ),
        // Idle → play (+ play-all). Playing → pause (when supported) +
        // stop. Paused → resume + stop.
        if (hasVoice) ...[
          if (readPhase == _ReadPhase.idle) ...[
            _control(
              content: read?.play,
              icon: Icons.play_arrow_rounded,
              label: (read?.playLabel ?? ''),
              semanticLabel: (read?.readAloudSemantics ?? ''),
              color: footer.iconColor,
              onTap: onReadPlay!,
            ),
            if (onReadPlayAll != null)
              _control(
                content: read?.playAllControl,
                icon: Icons.playlist_play_rounded,
                label: (read?.playAllLabel ?? ''),
                semanticLabel: (read?.readAllSemantics ?? ''),
                color: footer.iconColor,
                onTap: onReadPlayAll!,
              ),
          ],
          if (readPhase == _ReadPhase.paused)
            _control(
              content: read?.resume,
              icon: Icons.play_arrow_rounded,
              label: (read?.resumeLabel ?? ''),
              semanticLabel: (read?.readAloudSemantics ?? ''),
              color: footer.iconColor,
              onTap: onReadPlay!,
            ),
          if (readPhase == _ReadPhase.playing && canPauseReading)
            _control(
              content: read?.pause,
              icon: Icons.pause_rounded,
              label: (read?.pauseLabel ?? ''),
              semanticLabel: (read?.pauseSemantics ?? ''),
              color: footer.iconColor,
              onTap: onReadPause!,
            ),
          if (readPhase != _ReadPhase.idle)
            _control(
              content: read?.stop,
              icon: Icons.stop_rounded,
              label: (read?.stopLabel ?? ''),
              semanticLabel: (read?.stopSemantics ?? ''),
              color: footer.iconColor,
              onTap: onReadStop!,
            ),
        ],
        if (speedSettings != null) _speedControl(speedSettings),
      ],
    );
  }

  /// PREV / NEXT: the same control, with the glyph mirrored under RTL so a
  /// custom arrow still points with the page travel.
  Widget _navControl({
    required Widget? content,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        Widget glyph = content ??
            Icon(icon,
                size: footer.iconSize,
                color: (footer.nav.color ?? footer.iconColor));
        if (isRtl) {
          glyph = Transform.flip(flipX: true, child: glyph);
        }
        return _FooterControl(
          semanticLabel: label,
          onTap: () {
            onControlUsed?.call(label);
            onTap();
          },
          child: glyph,
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _FlipBookHeader extends StatelessWidget {
  const _FlipBookHeader({
    required this.closeIcon,
    required this.closeIconColor,
    required this.closeLabel,
    this.onClose,
    this.headerAction,
    this.closeAtEnd = false,
  });

  final IconData closeIcon;
  final Color closeIconColor;
  final String closeLabel;
  final VoidCallback? onClose;
  final Widget? headerAction;
  final bool closeAtEnd;

  @override
  Widget build(BuildContext context) {
    final close = IconButton(
      onPressed: onClose,
      // The explicit semanticLabel is what screen readers announce;
      // the tooltip alone only fills the tooltip attribute (ACC-01).
      icon: Icon(
        closeIcon,
        key: FlipBookKeys.closeIcon,
        size: 20,
        semanticLabel: closeLabel,
      ),
      color: closeIconColor,
      tooltip: closeLabel,
    );
    // Leading edge by default; closeAtEnd swaps the × with the action. The
    // Row follows the ambient text direction, so "end" mirrors under RTL by
    // itself — no direction arithmetic here.
    // 🔴 The default keeps the PHYSICAL padding it has had since 0.1.0 —
    // the RTL chrome golden is byte-exact on it, and a "same look" promise
    // is measured in pixels. Only the swapped layout is directional.
    return Padding(
      padding: closeAtEnd
          ? const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 0)
          : const EdgeInsets.fromLTRB(4, 8, 12, 0),
      child: Row(
        children: [
          if (!closeAtEnd) close,
          if (closeAtEnd && headerAction != null) headerAction!,
          const Spacer(),
          if (closeAtEnd) close,
          if (!closeAtEnd && headerAction != null) headerAction!,
        ],
      ),
    );
  }
}

// ── Footer control ───────────────────────────────────────────────────────────

/// One footer control: the caller's widget (or the built-in icon) inside a
/// generous, opaque tap area.
///
/// The padding is invisible touch target — icons sit close together
/// visually while fingers still land reliably, which is what a row of small
/// glyphs on a phone needs.
class _FooterControl extends StatelessWidget {
  const _FooterControl({
    required this.child,
    required this.semanticLabel,
    required this.onTap,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // A floor on the touchable area, not just on the glyph. An icon
        // drawn at 24 with 8 of padding is a 40-point target; anything
        // smaller is a button people miss.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}
