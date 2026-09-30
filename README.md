# page_curl_flip

A realistic cylindrical page-curl animation for Flutter. Pages peel away like
real paper — perspective, diffuse shadow, and a specular sheen included.

**Zero dependencies.** The package is a skeleton you decorate: every colour,
label, and icon is replaceable, and sound, speech, and storage are callbacks
you plug anything into. RTL-aware. Tested on Android and iOS — the two platforms the listing promises; it is pure Flutter with zero dependencies, so it may well render elsewhere, but only what is tested is claimed.

![page_curl_flip demo — LTR and RTL books, swipes, buttons, and read-aloud](https://raw.githubusercontent.com/vanisupriyam/page_curl_flip/main/doc/demo.gif)

## Three entry points

| Widget | Use it for |
|---|---|
| `FlipBook` | A complete multi-page book: navigation, table of contents, read-aloud, reader marks, bookmarks, export |
| `PageCurlRoute` | A `Navigator` transition that peels the previous screen away |
| `CurlOverlay` | The raw curl, driven by any `progress` value you control |

## Quick start

```dart
FlipBook(
  onClose: () => Navigator.of(context).pop(),
  pages: FlipBookPages(
    items: const [
      FlipBookPage(
        title: 'A Tiny Book',                 // in the contents AND on the page
        tagline: 'a line under it',           // optional smaller line
        bodySegments: ['Hello.', 'Goodbye.'], // the text, unit by unit
      ),
      FlipBookPage(
        title: 'Images too',
        body: Center(child: FlutterLogo(size: 160)), // body is ANY widget
      ),
    ],
  ),
)
```

**Every feature is an object you pass, and it exists only if you pass it.**
A book with nothing but pages has no voice controls, no pencil, and no
settings for things it does not do. Pass `readAloud:`, `marker:`,
`bookmarks:`, or `contents.export:` and everything about that feature —
behaviour, icons, colours, words — lives inside that one object.

## Pages

Everything about presentation lives in `FlipBookPages`:

```dart
pages: FlipBookPages(
  items: [...],
  paperColor: const Color(0xFFFBFAF6),
  style: const FlipBookPageStyle(titleStyle: TextStyle(fontSize: 28)),
  textDirection: TextDirection.rtl,           // null follows the locale
  initialPage: prefs.getInt('lastPage') ?? 0,
  onChanged: (i) => prefs.setInt('lastPage', i),
  showNumber: true,
)
```

A page is built from optional parts:

- `title` / `tagline` — printed at the top and listed in the contents.
  `showTitleOnPage: false` keeps the title in the contents only.
- `bodySegments` — the text as a list of reading units. **The accurate way**:
  one entry is one unit, marked and spoken as-is, in every script.
- `bodyText` — one string the book splits on full stops. `pub.dev` and
  `$23.54` survive; `Dr. Smith` does not. Prefer `bodySegments`.
- `bodyWidgets` — widgets dropped between the units: `{1: Image.asset(...)}`
  inserts before segment 1. The text around them stays markable and readable.
- `background` — decoration behind a text page (ruled paper, parchment); it
  scrolls with the text.
- `body` — ANY widget as the whole page. Full layout control; the book can
  read its `bodyText` aloud but cannot mark or auto-scroll it.
- `style` — a per-page `FlipBookPageStyle`, overriding the book's.
- `id` — stable identity; required for reader marks and saved pages.

Text pages the book lays out itself scroll when they exceed the screen.

## Reading direction

LTR under English and other LTR locales; **automatically mirrored** under
Arabic and any RTL locale — buttons mirror, chevrons flip, and pages curl
the other way. Force it with `textDirection:` regardless of locale.

## Swipe

A horizontal fling turns the page; a vertical one scrolls it. On by default,
mirrored under RTL. A hint greets new pages and retires after `maxShows`
appearances — persist `onRetired` to stop greeting a reader who has learned:

```dart
swipe: FlipBookSwipe(
  hint: FlipBookSwipeHint(                    // null = no hint
    showFor: const Duration(seconds: 3),
    maxShows: 3,
    onRetired: () => prefs.setBool('swipeLearned', true),
    child: Image.asset('assets/swipe.gif'),   // or any widget of yours
  ),
)
```

## Flip speed and sound

```dart
FlipBook(flipSpeed: FlipSpeed.slow, ...)                          // preset
FlipBook(flipSpeed: const FlipSpeed.custom(Duration(seconds: 2))) // your own
```

The package ships no audio. Give the footer a sound object and a speaker
button appears; omit it and the book is silent:

```dart
footer: FlipBookFooter(sound: FlipBookSound(onFlip: _mySound.play)),
```

## Read aloud

Wire any speech engine; the book reads **unit by unit** and calls you once
per unit:

```dart
readAloud: FlipBookReadAloud(
  onRead: (unit) => tts.speak(unit), // future completes when the unit ends
  onStop: tts.stop,
  onPause: tts.pause,                // optional pair — enables pause
  onResume: tts.resume,
  playAll: true,                     // PLAY ALL: the whole book, audiobook-style
),
```

- **Read marker** — the unit being spoken is marked and the page
  auto-scrolls to it. It moves when the engine reports a unit done — never
  on a timer — so it cannot drift. Styles: `highlight` (a translucent band)
  or `focus` (the rest of the page dims). Configure via `FlipBookHighlight`,
  or take over rendering with its `builder`.
- **Speed** — pass `speed: FlipBookSpeedControl(...)` and a `0.5x · 1x · 1.5x`
  pill appears while reading. The package reports the choice; you apply it
  to your engine.
- **What is read** — title, tagline, body: each can be switched off
  (`readTitle:` …) and each can be excluded from the focus dim (`fadeTitle:` …).
- Play-all works in the foreground; backgrounding stops the voice and the
  chain. The example wires `flutter_tts` completely, including
  pause-by-word-position and a missing-voice dialog.

## Reader marks

A pencil in the footer; a drag marks whole words; SAVE / CANCEL float at the
marked passage itself:

```dart
marker: FlipBookMarker(
  marks: _marks,                       // loaded from YOUR storage
  onChanged: (marks) => save(marks),
),
```

- CANCEL drops the draft **and exits marking mode** — marking owns the
  horizontal drag, so staying in it would block page turns.
- A trash button appears **only on pages that have marks**, and clears that
  page only.
- Marks are stored against `FlipBookPage.id`, never the page number, so
  reordering pages cannot move them. No `id`, no pencil.
- The lit pencil defaults to the mark wash made opaque. If your wash and
  footer bar share a colour family the pencil disappears into the bar —
  give it its own voice: `FlipBookMarker(activeColor: Colors.deepPurple)`.
- **The package stores nothing.** `ReaderMark` is plain primitives
  (`toMap` / `fromMap`) — persist with whatever your app already uses.

## Bookmarks and saved pages

Two ways of keeping a place, both reported through callbacks and handed back
as values:

```dart
bookmarks: FlipBookBookmarks(
  bookmarkedPage: _bookmark,               // the page to carry on from
  onBookmark: (page) => keep(page),        // tap again to remove
  saved: _savedIds,                        // the reader's collection, by page id
  onSavedChanged: (ids) => keepAll(ids),
),
```

## Contents and export

Pages with a `title` appear in the table of contents (INDEX button), with
live search and direct jumps. Give it an export object and an export button
appears, offering the reader's saved pages, marked passages, or the whole
book as plain data — page numbers, titles, and strings — for you to turn
into a PDF, an email, anything:

```dart
contents: FlipBookContents(
  export: FlipBookExport(
    onExport: (kind, entries) => makePdf(kind, entries),
  ),
),
```

The example builds a real shareable PDF from it.

## Chrome: footer, header, tap labels, immersive mode

Controls are icons on a bar; **a tapped control names itself** above the
footer for a moment (`tapLabelFor`, `Duration.zero` turns it off). Any
control takes a custom icon or a word instead. With `autoHide: true` the
book opens as a pure page — a tap (or a mouse hover at the edge) reveals the
chrome, which retires again after `revealFor`:

```dart
header: const FlipBookHeader(autoHide: true),
footer: FlipBookFooter(
  autoHide: true,
  revealFor: const Duration(seconds: 3),
  color: Colors.teal,          // the bar; Colors.transparent floats the icons
),
```

`header: null` / `footer: null` removes an element entirely.

Three more knobs, each defaulting to the long-standing look:

```dart
// The bar stretches to the page width minus the inset, so its edges meet
// your text column; the controls spread evenly. Null keeps it content-sized.
footer: const FlipBookFooter(horizontalInset: 32),

// The x at the trailing edge, swapping places with the header action.
// Mirrors under RTL by itself.
header: const FlipBookHeader(closeAtEnd: true),

// A forward swipe on the LAST page is the one flip the book cannot honour.
// By default the gesture is simply eaten; give it a meaning of your own —
// the classic is closing the book from its back cover. Never fired by the
// controller or the read-aloud chain, only by a real gesture.
FlipBook(
  onFlipPastEnd: () => Navigator.of(context).pop(),
  // ...
)
```

## Your own buttons, anywhere

```dart
final controller = FlipBookController();

FlipBook(
  controller: controller,
  header: null,
  footer: null,
  pages: FlipBookPages(items: const [...]),
  onClose: () {},
);

FloatingActionButton(onPressed: controller.nextPage);
```

`nextPage()`, `previousPage()`, `jumpToPage(i)`, `openIndex()`,
`closeIndex()`, `toggleMute()`, and the current `page`.

## Styling and localization

There is no theme object and no strings object: **each feature carries its
own look and its own words**. Every field defaults, so you only name what
you change — and translating a book means filling in the labels:

```dart
FlipBook(
  header: const FlipBookHeader(closeLabel: 'إغلاق'),
  footer: const FlipBookFooter(
    index: FlipBookIndexButton(label: 'الفهرس'),
    nav: FlipBookNavButtons(previousLabel: 'السابق', nextLabel: 'التالي'),
  ),
  contents: const FlipBookContents(heading: 'جدول المحتويات'),
  ...
)
```

The example's Arabic book is a complete translation of every label.

## PageCurlRoute

```dart
Navigator.of(context).push(
  PageCurlRoute(
    coverChild: const CoverPage(), // shown, captured, then peeled away
    builder: (_) => const DetailScreen(),
  ),
);
```

Mirrors automatically under RTL; `mirror:` forces a direction. All four
durations (route and curl, forward and reverse) are parameters.

## CurlOverlay

Drive the curl yourself — from an `AnimationController`, a slider, a drag:

```dart
CurlOverlay(
  progress: controller.value, // 0.0 flat → 0.5 max curl → 1.0 gone
  child: MyPageContent(),     // captured automatically
)
```

Or capture the bitmap yourself and pass `pageImage` for exact control.

## Known limitations

- **Swipes fling, they don't drag** — the page does not follow your finger
  mid-drag.
- **A reader mark cannot cross paragraphs** — a `ReaderMark` lives inside
  one `bodySegments` entry.
- **`body:` widget pages do not scroll** — a widget body owns its layout;
  give it its own `SingleChildScrollView`. Text pages already scroll.
- **Flips show a snapshot** — an animating body (GIF, video) freezes during
  the curl and resumes after it.
- **Mute and reading state are not persisted** across rebuilds that recreate
  the book.

## Testing note

Golden baselines are macOS-rendered; regenerate them on macOS
(`flutter test --update-goldens test/goldens_test.dart`). In widget tests,
omit the sound/speech objects or pass no-ops — the callbacks are
fire-and-forget, so an audio failure can never break the animation.

## Finding the chrome from your app

To point at the footer or the × from outside the package — a coach mark, a
tour, an integration test — use the keys, never a class name (class names
are renamed by `--obfuscate`):

```dart
final footer = find.byKey(FlipBookKeys.footerBar);
final close = find.byKey(FlipBookKeys.closeIcon);
```

## How it works

Each flip captures the page as a bitmap at the device pixel ratio (capped at
2×), then draws it as 28 vertical slices projected onto a cylinder whose
radius shrinks and grows with `progress`. Slices are depth-sorted, shaded by
their angle to the light, and given a moving specular glint — which is what
makes the paper read as physically curling rather than just rotating.

## License

MIT
