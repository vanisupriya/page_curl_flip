import 'package:flutter/material.dart';

/// The bar at the bottom of the book, and everything on it.
///
/// Every control is an **icon**: a phone cannot fit contents, play,
/// play-all, pause, stop, prev, next, a pencil and a trash as words. An
/// icon cannot explain itself, and a tooltip needs a long press nobody
/// performs on a phone — so a tapped control **names itself** just above
/// the bar for [tapLabelFor]. Prefer a word for one of them? Pass a `Text`
/// as that control's `child`.
///
/// `footer: null` removes the bar entirely; drive the book with a
/// `FlipBookController` instead.
@immutable
class FlipBookFooter {
  /// Every field defaults; `const FlipBookFooter()` is the standard bar.
  const FlipBookFooter({
    this.color = const Color(0xF0EEEEEE),
    this.radius = 18,
    this.autoHide = false,
    this.revealFor = const Duration(seconds: 3),
    this.tapLabelFor = const Duration(seconds: 3),
    this.tapLabelStyle = _tapLabel,
    this.tapLabelColor = const Color(0xE6202020),
    this.horizontalInset,
    this.iconSize = 26,
    this.iconColor = Colors.black54,
    this.pageNumberStyle = _footerLabel,
    this.index = const FlipBookIndexButton(),
    this.nav = const FlipBookNavButtons(),
    this.sound,
  });

  static const TextStyle _tapLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: Color(0xFFFFFFFF),
  );
  static const TextStyle _footerLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: Colors.black54,
  );

  /// Background of the bar. Bare icons over a photo or dark paper are
  /// unreadable; `Colors.transparent` floats them anyway.
  final Color color;

  /// Corner radius of the bar.
  final double radius;

  /// Opens the book as a pure page — a tap reveals the bar, which fades
  /// again after [revealFor]. On mouse platforms, hovering the bottom edge
  /// reveals it too.
  final bool autoHide;

  /// How long a revealed bar stays before fading. Any interaction with it
  /// restarts the clock.
  final Duration revealFor;

  /// How long the word naming a tapped control stays on screen.
  /// [Duration.zero] switches the naming off.
  final Duration tapLabelFor;

  /// Style of that word.
  final TextStyle tapLabelStyle;

  /// Background behind it.
  final Color tapLabelColor;

  /// Stretches the bar to the page's width, minus this much on each side.
  ///
  /// Null — the default — keeps the bar content-sized, hugging its icons.
  /// Pass the same value as the page's horizontal text padding and the bar's
  /// edges line up with the text column, which is the look a book wants: the
  /// controls belong to the page, not to a floating pill. The controls spread
  /// evenly across whatever width they are given.
  final double? horizontalInset;

  /// Size of every footer icon.
  final double iconSize;

  /// Default colour of the footer icons; individual controls may override.
  final Color iconColor;

  /// Style of the optional "3 / 12" indicator (`FlipBook.showPageNumber`).
  final TextStyle pageNumberStyle;

  /// The table-of-contents button.
  final FlipBookIndexButton index;

  /// The previous / next buttons.
  final FlipBookNavButtons nav;

  /// The flip sound and its mute button; `null` means a silent book with no
  /// speaker.
  final FlipBookSound? sound;

  /// This object with some fields replaced.
  ///
  /// A null argument means "leave it alone", so a field that is already
  /// nullable cannot be cleared this way — construct a new one for that.
  FlipBookFooter copyWith({
    Color? color,
    double? radius,
    bool? autoHide,
    Duration? revealFor,
    Duration? tapLabelFor,
    TextStyle? tapLabelStyle,
    Color? tapLabelColor,
    double? horizontalInset,
    double? iconSize,
    Color? iconColor,
    TextStyle? pageNumberStyle,
    FlipBookIndexButton? index,
    FlipBookNavButtons? nav,
    FlipBookSound? sound,
  }) {
    return FlipBookFooter(
      color: color ?? this.color,
      radius: radius ?? this.radius,
      autoHide: autoHide ?? this.autoHide,
      revealFor: revealFor ?? this.revealFor,
      tapLabelFor: tapLabelFor ?? this.tapLabelFor,
      tapLabelStyle: tapLabelStyle ?? this.tapLabelStyle,
      tapLabelColor: tapLabelColor ?? this.tapLabelColor,
      horizontalInset: horizontalInset ?? this.horizontalInset,
      iconSize: iconSize ?? this.iconSize,
      iconColor: iconColor ?? this.iconColor,
      pageNumberStyle: pageNumberStyle ?? this.pageNumberStyle,
      index: index ?? this.index,
      nav: nav ?? this.nav,
      sound: sound ?? this.sound,
    );
  }
}

/// The button that opens the table of contents.
///
/// It appears only when at least one page carries a `title` — there has to
/// be something to list.
@immutable
class FlipBookIndexButton {
  /// Every field defaults.
  const FlipBookIndexButton({
    this.icon = Icons.list,
    this.child,
    this.label = 'INDEX',
    this.color,
  });

  /// Glyph of the button.
  final IconData icon;

  /// Replaces the glyph with any widget — pass a `Text` for a word.
  final Widget? child;

  /// The word flashed on tap, and what a screen reader announces.
  final String label;

  /// Colour of the glyph; null uses the footer's.
  final Color? color;
}

/// The previous / next buttons.
///
/// Both glyphs mirror under RTL, so a custom arrow still points the way the
/// page travels.
@immutable
class FlipBookNavButtons {
  /// Every field defaults.
  const FlipBookNavButtons({
    this.show = true,
    this.previousIcon = Icons.chevron_left,
    this.nextIcon = Icons.chevron_right,
    this.previousChild,
    this.nextChild,
    this.previousLabel = 'PREV',
    this.nextLabel = 'NEXT',
    this.color,
  });

  /// Whether they render at all. `false` gives a swipe-only book; swiping
  /// and the controller keep working.
  final bool show;

  /// Glyph of the previous button.
  final IconData previousIcon;

  /// Glyph of the next button.
  final IconData nextIcon;

  /// Replaces the previous glyph with any widget.
  final Widget? previousChild;

  /// Replaces the next glyph with any widget.
  final Widget? nextChild;

  /// Word flashed on tap for previous, and its screen-reader name.
  final String previousLabel;

  /// Word flashed on tap for next, and its screen-reader name.
  final String nextLabel;

  /// Colour of the glyphs; null uses the footer's.
  final Color? color;
}

/// The flip sound.
///
/// The package ships **no audio**: [onFlip] is called at the start of every
/// flip and you play whatever you like, with any plugin. Passing this
/// object is what makes the book audible and reveals the speaker button.
@immutable
class FlipBookSound {
  /// [onFlip] is required — a sound object with nothing to play is a
  /// contradiction.
  const FlipBookSound({
    required this.onFlip,
    this.showMute = true,
    this.onIcon = Icons.volume_up,
    this.offIcon = Icons.volume_off,
    this.onChild,
    this.offChild,
    this.muteLabel = 'Mute flip sound',
    this.unmuteLabel = 'Unmute flip sound',
    this.color,
    this.silenced = false,
    this.onSilencedTap,
    this.silencedLabel = 'Sound is off on this device',
  });

  /// Plays your sound. Failures are swallowed — a broken sound must never
  /// interrupt a page turn.
  final Future<void> Function() onFlip;

  /// Whether the speaker button shows. `false` keeps the sound and hides
  /// the button.
  final bool showMute;

  /// Glyph while the sound is on.
  final IconData onIcon;

  /// Glyph while it is muted.
  final IconData offIcon;

  /// Replaces the unmuted glyph with any widget.
  final Widget? onChild;

  /// Replaces the muted glyph with any widget.
  final Widget? offChild;

  /// What a screen reader announces while the sound is on.
  final String muteLabel;

  /// What it announces while muted.
  final String unmuteLabel;

  /// Colour of the glyph; null uses the footer's.
  final Color? color;

  /// The sound is off outside the book (for example the phone's silent mode):
  /// the speaker shows muted, flips play nothing, and the book's own mute is kept.
  final bool silenced;

  /// Called for a tap on the speaker while [silenced]; the book's mute does not change.
  final VoidCallback? onSilencedTap;

  /// What a screen reader announces while [silenced].
  final String silencedLabel;
}
