## 0.2.4

* **Added: `FlipBookKeys`.** Two stable keys on the book's chrome —
  `FlipBookKeys.footerBar` (the whole footer bar) and
  `FlipBookKeys.closeIcon` (the header's × icon) — so an app can find them in
  its widget tree, for example to spotlight them in a coach mark. Unlike a
  search by `runtimeType.toString()`, a key survives
  `flutter build --obfuscate`. No visual change (goldens unchanged).
* **Example: a speed change mid-sentence works on iOS.** flutter_tts never
  completes a stopped utterance on iOS, so the example's read loop waited
  forever and the new speed only applied after stop and play. The loop now
  ends that wait itself, and goes on from the NEXT word instead of repeating
  the one being spoken — the same code on Android and iOS. (SPD-11..13)
* **Example: a "?" tour** in the LTR book outlines the footer bar and the ×,
  found with `FlipBookKeys`.
* **Example: builds on current Flutter** — Android Gradle 8.14, AGP 8.11.1,
  Kotlin 2.2.20; the iOS project migrated by Flutter (UIScene, Swift Package
  Manager, iOS 15 minimum). The package itself is unchanged by these.

## 0.2.3

* **Fixed: a stretched footer never wraps.** With `horizontalInset` set the
  bar's width is fixed, so a control joining the row mid-session — the trash
  appearing after a first saved mark — pushed the last control onto a second
  centred line and grew the footer. A stretched bar now gives every control an
  equal slot and scales them down together instead; height stays constant.
  The default content-sized bar keeps its wrap-on-narrow behaviour exactly
  (goldens unchanged). (FTR-02)
* README: examples for the four 0.2.2 parameters.

## 0.2.2

Bug-fix release.

* **Fixed: a failing read-aloud engine no longer flips the whole book.** In
  play-all, a page whose `onRead` threw was treated exactly like a page that
  finished, so the chain advanced — and when every unit failed instantly (an
  engine offline), the book flipped itself end to end at animation speed with
  no quiet frame in which to press stop. An engine failure now ends the whole
  reading session: the marker clears, the chain dies, the reader is back in
  control. (TTS-18)
* **Fixed: a failed `onResume` chained the same way.** Same rule now — a
  resume the engine cannot honour ends the reading, never advances it.
  (TTS-19)
* **Added: `FlipBookFooter.horizontalInset`.** Stretches the bar to the page
  width minus the inset on each side, so its edges line up with the page's
  text column; the controls spread evenly across it. Null — the default —
  keeps the content-sized bar exactly as before. (FTR-01)
* **Added: `FlipBook.onFlipPastEnd`.** Fired when the reader swipes forward
  on the last page — the one flip the book cannot honour. Null (the default)
  keeps the long-standing behaviour: the gesture is eaten. The classic use is
  closing the book from its back cover. Fired only by a real gesture, never
  by the controller or the play-all chain. (END-01, END-02)
* **Fixed: a rebuild no longer costs the reader their scroll place.** Each
  page's scroll view was keyed by object identity, so a caller that rebuilds
  its page list — any state-management emit, such as saving a mark — was
  handed a "different" page and thrown back to the top. A page with an `id`
  is now keyed by it; a flip still opens the next page at its own top, and
  id-less pages behave exactly as before. (SCR-01)
* **Added: `FlipBookMarker.activeColor`.** The lit pencil's own colour. It
  used to borrow the mark wash made opaque — and the moment the wash and the
  footer bar share a colour family, the pencil vanishes into the bar the
  instant marking switches on (found on a device). Null keeps the old
  fallback. The same parameter bookmarks have carried since 0.2.0. (MRK-16)
* **Added: `FlipBookHeader.closeAtEnd`.** Puts the x at the trailing edge,
  swapping places with the header action; mirrors under RTL by itself.
  Default false — the x leads, pixel-identical to before. (HDR-01)
* **Internal: the state was split into behaviour clusters** — reading aloud
  and reader-marks each live in their own file now, joined to the shared
  core by an explicit cross-cluster contract. No public API or behaviour
  change; the six golden baselines pass byte-identical, which is the proof.
* **Changed: the listing now declares `android` and `ios` only.** These are
  the platforms the package is actually tested on. Nothing was removed — it
  is pure Flutter with zero dependencies and very likely renders elsewhere —
  but a platform badge is a promise, and these two are the ones we keep.

# Changelog

## 0.2.1

- `PageCurlRoute`'s RTL mirror now builds its flip with
  `Matrix4.diagonal3Values(-1, 1, 1)` instead of `Matrix4.identity()..scale(...)`.
  Identical math, no behaviour change — `Matrix4.scale` is deprecated in the
  `vector_math` that ships with the newest Flutter, and pub.dev's analysis
  flagged it. Nothing else changed.

## 0.2.0

**Every feature is now an object you pass, and it exists only if you pass
it.** `FlipBook()` with nothing but pages gives a plain book with no voice
controls, no pencil, and no settings for things it does not do. Ask for a
feature and everything about it — behaviour, icons, colours, words — lives
inside that one object, so nothing is scattered and nothing is dead config.

### Migrating from 0.1.x

| Was | Now |
|---|---|
| `theme:`, `strings:`, `icons:`, `voiceChips:` | **gone** — each feature carries its own look and words |
| `onReadAloud:`, `onReadAloudStop/Pause/Resume:`, `readAloudAdvances:` | `readAloud: FlipBookReadAloud(onRead:, onStop:, onPause:, onResume:, playAll:)` |
| `onPageFlip:`, `enableSound:`, `showMuteButton:` | `footer: FlipBookFooter(sound: FlipBookSound(onFlip:, showMute:))` — **no sound object means a silent book** |
| `chrome: FlipBookChrome.autoHide` | `footer: FlipBookFooter(autoHide: true)` |
| `headerChrome:` | `header: FlipBookHeader(autoHide: true)` |
| `showHeader: false` / `showFooter: false` / `showControls: false` | `header: null` / `footer: null` / both |
| `showNavButtons: false` | `footer: FlipBookFooter(nav: FlipBookNavButtons(show: false))` |
| `swipeToFlip:`, `showSwipeHint:`, `swipeHintDuration:`, `swipeHintMaxShows:`, `swipeHint:`, `onSwipeHintRetired:` | `swipe: FlipBookSwipe(enabled:, hint: FlipBookSwipeHint(showFor:, maxShows:, child:, onRetired:))` — `hint: null` removes it |
| `marking:`, `marks:`, `onMarksChanged:` | `marker: FlipBookMarker(marks:, onChanged:)` — `null` means no pencil |
| `showReadSpeed:`, `readSpeed:`, `onReadSpeedChanged:` | `readAloud: FlipBookReadAloud(speed: FlipBookSpeedControl(initial:, onChanged:))` |
| `pages: [...]`, `pageColor:`, `initialPage:`, `onPageChanged:`, `showPageNumber:`, `textDirection:` | `pages: FlipBookPages(items:, paperColor:, style:, initialPage:, onChanged:, showNumber:, textDirection:)` |
| `theme.pageTitleStyle` etc. | `pages: FlipBookPages(style: FlipBookPageStyle(titleStyle:, taglineStyle:, bodyStyle:, padding:))` |
| `theme.toc*`, `strings.tableOfContents`, `strings.searchHint` | `contents: FlipBookContents(...)` |
| `strings.index` / `.previous` / `.next` | `footer: FlipBookFooter(index: FlipBookIndexButton(label:), nav: FlipBookNavButtons(previousLabel:, nextLabel:))` |

Every field inside every object defaults, so you only name what you change.

---

A book is not an audio player. The player-style progress bar is gone, and a
read MARKER took its place — the unit being spoken is marked on the page,
like a hand following the text — plus marks the reader makes themselves.

**Breaking:**

- `onReadAloud` is now `readAloud.onRead`, a
  `Future<void> Function(String unit)`. The book
  reads unit by unit and calls you once per unit (`(s) => tts.speak(s)` is a
  complete wiring); each future completes when the engine finishes that
  unit. Completions are what drive the marker — no engine timing events —
  so it behaves identically on every platform and cannot drift.
  `readAloud.onResume`'s future now completes when the interrupted unit ends.
- REMOVED: the read-aloud progress bar — `showReadAloudProgress`,
  `readAloudProgress`, `readAloudProgressLabel`, and the three
  `readAloudProgress*` theme fields.
- REMOVED: `swipeHintDelay`, and `swipeHintMaxSwipes` became
  `swipeHintMaxShows`. The hint no longer returns every 20 seconds while a
  reader stays on a page — it greets a page, fades, and retires after 3
  appearances. A hint that keeps coming back nags.

**New:**

- **Reading units you control.** `FlipBookPage.bodySegments` — one entry,
  one unit: marked, spoken in one call, never parsed or reformatted. Works
  in every script, RTL included, because the book never inspects the
  characters. A single `bodyText` still works and is split on full stops,
  `readAloud.unitsPerMark` at a time; those rules keep `pub.dev`, `$23.54` and
  `a@b.com` whole, but abbreviations like `Dr.` are exactly why segments
  exist.
- **The read marker** — `readAloud: FlipBookReadAloud(highlight:
  FlipBookHighlight(style:, color:, radius:, dimOpacity:, builder:))`.
  `FlipBookMarkerStyle.highlight` paints a band behind the unit;
  `FlipBookMarkerStyle.focus` keeps the unit in full ink and dims the rest.
  Pause freezes it in place; stop, a flip, or the app leaving the foreground
  clears it. The page auto-scrolls to keep the marked unit in view. A
  `builder` replaces the rendering entirely with your own.
- **Reader marking** — `marker: FlipBookMarker(marks:, onChanged:)`; `null`
  means no pencil, and it is independent of `readAloud`, because a reader
  marks passages whether or not the book can speak. A pencil in the footer, a
  drag across the words — snapped to whole words — then SAVE or CANCEL, and
  a trash button that appears only on a page that has marks and clears that
  page alone. CANCEL drops the draft and exits marking mode. The package
  stores nothing: `onChanged` reports the list and `marks` takes it back, so `ReaderMark` (plain `toMap` / `fromMap`) persists in whatever
  your app already uses. Marks hang on the new `FlipBookPage.id`, never on
  page numbers, so inserting a chapter cannot move them onto the wrong text.
- **Reading speed for the reader**: `readAloud: FlipBookReadAloud(speed:
  FlipBookSpeedControl(initial:, onChanged:, options:))` draws `0.5x · 1x ·
  1.5x` in the footer and reports the choice.
  The package makes no sound, so the app applies it; the marker follows
  automatically, since it moves on completions.
- **Text pages**: a `FlipBookPage` with body text and no `body` widget is
  rendered by the book itself — one scroll view, styled by
  `pages: FlipBookPages(style: FlipBookPageStyle(bodyStyle:))`, decorated by the new optional `background`
  widget, which scrolls with the text.
- **Independent header and footer**: `header: null` / `footer: null` remove
  either one, and `FlipBookHeader(autoHide: true)` lets the header hide like
  the footer — on a shared reveal-and-retire clock, with its own top hover
  strip on mouse platforms and one tap driving every auto-hiding element.
  Defaults unchanged: header always visible.
- **Everything about a page in one object**: `FlipBookPages` carries the
  list, the paper colour, the type, the reading direction, where the book
  opens and where it is.
- **The reader's keep / discard controls appear at the passage**, floated
  under the words just marked, instead of at the bottom of the screen. A
  reader who has dragged out a sentence is looking at that sentence.
- **`readTitle` / `readTagline` / `readBody`** choose what the voice reads —
  and therefore what dims, since a part outside the performance should stay
  at full ink.
- **`FlipBookSpeedControl.options`** picks which speeds appear, in your
  order; `[]` hides the row. The chosen one sits on a **filled pill** and
  names itself (`1.5x speed`) when tapped, with `slowLabel` / `normalLabel` /
  `fastLabel` for the wording, because a heavier weight alone
  was hard to spot.
- Fixed: a marked passage in Arabic drew as **a wall of bricks**.
  `getBoxesForSelection` returns a box per text RUN, and Arabic breaks into
  many; boxes sharing a line are now merged into one band, in every script.
- **Images and widgets between paragraphs**: `FlipBookPage.bodyWidgets` is
  a `{index: widget}` map dropped between the text units — a photo, a chart,
  a divider. The text around them stays markable and readable; the voice
  skips them, because a picture has nothing to say. Give each a finite
  height, and pause a video in `onPageChanged` when the reader flips away.
- **The footer is icons now**, not a row of words: a phone cannot fit
  INDEX · PLAY · PLAY ALL · PAUSE · STOP · PREV · NEXT as text beside a
  pencil and a trash. Because an icon cannot explain itself — and a tooltip
  needs a long press nobody performs on a phone — **a tapped control names
  itself above the footer** for `footer.tapLabelFor` (3 s; `Duration.zero`
  switches it off). Screen readers still hear the fuller sentence.
- **Every footer control takes any widget**, each one living on the feature
  it belongs to: `footer.index.child`, `footer.nav.previousIcon`,
  `footer.sound.onIcon`, `readAloud.play`, `marker.save`. Pass a `Text` for
  the controls you want as words, an icon or any widget for the rest — per
  control, not all-or-nothing. Default icon size grew 16 → 22.
- **The footer has a surface**: light grey by default (`footer.color`,
  `footer.radius`), because bare icons over a photo or dark paper are
  unreadable. `Colors.transparent` restores the floating look of 0.1.x.
- The swipe hint is bigger and bolder (17 px w700, 26 px chevrons).
- `swipe.hint.child` takes any widget — an animated GIF of the gesture, an
  illustration — replacing the built-in text and chevrons, wrapped in a
  `Semantics` label so it still announces itself.
- Fixed: switching a chrome mode to `always` at runtime now shows the
  element instead of leaving it permanently hidden.
- **Keeping your place**: `bookmarks: FlipBookBookmarks(...)` puts two
  buttons on the footer's first line, and they are deliberately not one
  control. The **bookmark** holds ONE page — "carry on from here next
  time" — and reports it through `onBookmark`. **Save** holds MANY page ids
  and reports the whole set through `onSavedChanged`. Neither interrupts
  anything: tapping the bookmark mid-sentence does not stop the voice, drop
  a mark, or turn a page. As with marks, the package stores nothing; re-open
  at the stored page with `FlipBookPages.initialPage`. A page with no `id`
  offers no save button, because there would be nothing to remember it by.
- **Export**: `contents: FlipBookContents(export: FlipBookExport(...))` adds
  an Export button to the table of contents — the one screen that already
  shows the whole book. It offers three choices (the pages you saved, the
  passages you marked, the whole book) and hands the app
  `List<FlipBookExportEntry>`: 1-based page number, id, title, tagline, text
  and marked passages, in reading order, as plain strings. A choice with
  nothing behind it is disabled rather than exporting an empty file. **The
  package builds no file** — a PDF needs a document library and embedded
  fonts, and this package has zero dependencies. The example shows the other
  half: `example/lib/export_pdf.dart` builds a compressed, font-subset PDF
  on a background isolate behind a dialog the reader cannot dismiss, and
  hands it to the share sheet. Measured at **61 KB for 100 pages**.
- **The footer is two rows now.** Line 1 is the BOOK — contents, pencil,
  trash, the page number, prev and next. Line 2 is the VOICE — the flip-sound
  speaker, play / play-all / pause / stop, and the pace. Nine icons in one
  row is a scrum on a phone, and a reader hunting for "next page" should
  never have to scan past a play button. A book with no voice and no mute
  keeps a single row: the second one is not built at all.
- **The pace shows only while the voice is actually speaking.** Idle or
  paused, there is nothing to be fast or slow about, so the row stays short.
  The example goes one step further and applies a new pace **at the next
  word** rather than the next paragraph — neither Android nor iOS can change
  the rate of an utterance already speaking, so it stops and speaks on from
  the last word boundary. The package needs no change for this: the same
  `onRead` future stays open, so the book sees one unit and the read marker
  never moves.
- Fixed: marks landed on the wrong words on a real device. The `TextPainter`
  that maps a finger to a character never merged the ambient
  `DefaultTextStyle`, so it laid the text out in different type from the
  screen — measured at a 30-character error. It also mis-placed the marker
  band and made auto-scroll follow the wrong line. Invisible in tests,
  where every font resolves to the same fixed-width face.
- The floating SAVE / CANCEL bar is **translucent** by default
  (`marker.actionBarColor`, `marker.actionBarOpacity`) so the line it covers
  stays readable, while the words themselves keep full strength.
- Fixed: `footer: null` used to remove the header as well.
- Fixed: the reader's SAVE / CANCEL row covered the very words just marked,
  and under RTL could run off the screen. It is now drawn at page level,
  pinned to the mark by a `LayerLink` and centred on it within the block's
  width — it never hides the passage, and it cannot be cropped or sit where
  Flutter will not hit-test it.
- Fixed: a part excluded with `readTitle: false` was skipped by the voice but
  still faded. A part now dims only when it is both read **and** faded, and
  the new `fadeTitle` / `fadeTagline` / `fadeBody` make "read but never fade"
  expressible on its own — a page title should not flicker.

**Proven on hardware** (Android 13 and iOS 26, plus a 375 × 667 and a
384 × 640 screen):

- Fixed: a vertical swipe could turn the page. The guard now reads raw
  pointer travel from a `Listener` beneath the recogniser, so only a
  horizontal fling flips and a vertical one scrolls. No widget test can make
  the recogniser win the gesture arena, so this one is device-verified only.
- Fixed: the trash cleared the **whole book**. It clears the shown page
  only, shows only on a page that has marks, and no longer flickers during
  a flip — the gate follows the arriving page.
- Fixed: cancelling a draft and then marking the same words again never
  brought the SAVE / CANCEL row back.
- Fixed: marking mode survived a page turn. A flip drops the draft and the
  lit pencil, so the reader never lands on a page they cannot swipe.
- Fixed: the default nav chevrons read `> <` under RTL; they mirror with
  the book.
- Fixed: a decorated text page was inset on all four sides. The padding now
  sits on the text, so `background` reaches the edges.
- Fixed: `_MarkerBandPainter` cached a `TextPainter`, and a `CustomPainter`
  has no `dispose` — one native paragraph leaked per rebuild, worst while
  read-aloud repaints. The painter is built and disposed per paint.
- **`FlipBookPage.style`** — a per-page `FlipBookPageStyle` that overrides
  the book's.
- **`PageCurlRoute.mirror`** — forces the peel direction. `null` follows
  `Directionality`, which is wrong when an LTR screen opens an RTL book: the
  route runs before the book is built and cannot see its direction, so the
  caller says.
- **`copyWith`** on `FlipBookPage`, `FlipBookPages`, `FlipBookPageStyle`,
  `FlipBookFooter`, `FlipBookMarker`, `FlipBookReadAloud`, `FlipBookHeader`
  and `FlipBookSwipe`.
- Default save icons `star` → `library_add` / `library_add_check`.
- The example is now the visual contract for the whole API: the **LTR book
  overrides every icon, word and colour**, and the **RTL book passes nothing
  at all** beyond `textDirection` and the callbacks a talking book needs. Run
  it side by side to see exactly which pixels are yours and which are the
  package's.

## 0.1.1

- Replaced the deprecated `Matrix4.translate` call in the curl transform with
  `Matrix4.translationValues` + `multiplied`. Identical math, no behaviour
  change, and no minimum-SDK bump — the replacement API exists in every
  supported Flutter version.
- Shortened the `pubspec.yaml` description to pub.dev's 60–180 character
  guideline.

## 0.1.0

Initial release.

- `FlipBook` — multi-page book widget with cylindrical page-curl
  transitions, searchable table of contents, and full RTL support. Zero
  dependencies: the flip sound is a callback (`onPageFlip`) you wire to any
  audio player — the example shows an `audioplayers` setup.
- `FlipBookPage` — every field optional: `title` (named in the table of
  contents and printed on the page — `showTitleOnPage: false` keeps it off
  the page), `tagline`, and `body` (any widget).
- Automatic right-to-left support under RTL locales, plus a `textDirection`
  override on `FlipBook`.
- `FlipSpeed` — `slow` / `medium` / `fast` presets or
  `FlipSpeed.custom(Duration)`.
- `CurlOverlay` — the raw curl animation driven by a single `progress` value;
  works with a pre-captured bitmap or auto-captures a child widget.
- `PageCurlRoute` — a `PageRoute` that peels the previous screen away like a
  page, with an optional cover widget and configurable durations.
- `FlipBookTheme` — fully optional styling with sensible defaults and
  `copyWith`; `FlipBookIcons` — every icon the book draws is replaceable.
  The package is a skeleton: decoration belongs to the app.
- Read-aloud: a centred ▶ play control that reads the shown page through any
  speech engine (`onReadAloud`), with ⏸ pause / resume (`onReadAloudPause` /
  `onReadAloudResume`) and ⏹ stop (`onReadAloudStop`); reading stops
  automatically on navigation. The controls are text chips (PLAY, PLAY
  ALL, PAUSE, RESUME, STOP — localizable via `FlipBookStrings`, styled via
  `FlipBookTheme.voiceChip*`); any chip's content is replaceable with any
  widget through `FlipBookVoiceChips`. Every page paints edge to edge
  behind the floating chrome (structured pages clear it via the default
  `pagePadding`). Opt-in extras, all default off:
  `readAloudAdvances` (a PLAY ALL chip beside PLAY reads the whole book —
  the package flips and chains through the same callbacks; stop, pause,
  manual flips, and the app leaving the foreground all stop it; plain ▶
  stays page-only) and a player strip — `showReadAloudProgress` + app-fed
  `readAloudProgress` 0..1 and free-form `readAloudProgressLabel` (engines
  report no duration; the example feeds elapsed time), themable via
  `FlipBookTheme.readAloudProgress*`.
- Immersive reading: `chrome: FlipBookChrome.autoHide` opens the book as a
  pure page — a tap reveals the footer, which fades away after
  `chromeRevealFor` (bottom-edge hover reveals it on mouse platforms); the
  × close button stays visible in every mode. Default is
  `FlipBookChrome.always`, today's behaviour.
- `FlipBookStrings` — every built-in label and semantic label overridable for
  localization.
- `FlipBookController` + `showControls: false` — hide every built-in button
  and drive the book with your own UI (`nextPage`, `previousPage`,
  `jumpToPage`, `openIndex`, `closeIndex`, `toggleMute`); `showMuteButton:
  false` hides just the speaker while the sound stays on.
- Paper-aware lighting: the curl's sheen scales with the page colour, so
  dark themes flip without glare; `shine` and `shadow` (0–1) expose both
  layers on `FlipBook`, `CurlOverlay`, and `PageCurlRoute`.
- `FlipBookPage.speechText()` reads what the page shows: titles hidden via
  `showTitleOnPage: false` are skipped unless explicitly requested.
- Swipe to flip: a horizontal fling turns the page (mirrored under RTL).
  `swipeToFlip` (on by default) and `showNavButtons` (hide PREV/NEXT for a
  gesture-only book).
- Swipe hint (on by default): a background-free line — the text between
  broad chevrons fading toward the words — greets every page the moment it
  opens, stays for `swipeHintDuration` (3 s), returns every
  `swipeHintDelay` (20 s) while the reader stays on the page, and retires
  after `swipeHintMaxSwipes` (3) page-turning swipes in any mix of
  directions — the gesture counts as learned; flings at the edge of the
  book turn nothing and count nothing.
  Customizable via `showSwipeHint`,
  `FlipBookStrings.swipeHint`, `FlipBookTheme.swipeHintStyle`, and
  `FlipBookTheme.swipeHintArrowSize`. The package persists nothing between
  opens — `onSwipeHintRetired` fires exactly once when the gesture counts
  as learned, so the app can remember and pass `showSwipeHint: false` next
  time.
- `initialPage`, `onPageChanged` (also fired when a shrinking page list
  clamps the current page), and an opt-in `showPageNumber` "3 / 12"
  indicator styled by `FlipBookTheme.pageNumberStyle`.
