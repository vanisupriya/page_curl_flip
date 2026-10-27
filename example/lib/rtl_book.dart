// The Arabic edition — the same book mirrored, plus a voice-settings page.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:page_curl_flip/page_curl_flip.dart';

import 'export_dialog.dart';
import 'flip_sound.dart';
import 'reader.dart';
import 'phone_sound.dart';
import 'shared_pages.dart';
import 'stores.dart';

class RtlBook extends StatefulWidget {
  const RtlBook({super.key});

  @override
  State<RtlBook> createState() => _RtlBookState();
}

class _RtlBookState extends State<RtlBook> with PhoneSoundWatch {
  final _reader = Reader();

  // Its own player, because a sound is an app asset and every consumer
  // supplies one.
  final _sound = FlipSound();

  List<ReaderMark> _marks = MarkStore.load(rtl: true);
  FlipBookReadSpeed _speed = FlipBookReadSpeed.normal;

  // The last page of the book. The read-aloud dialog points a reader here
  // when their device has no Arabic voice.
  static const _settingsBody =
      'إذا لم تستطع سماع صوت هذه الصفحة، فعّل خدمة تحويل النص إلى كلام '
      'من إعدادات الجهاز:\n\n'
      'أندرويد:\n'
      '١. افتح الإعدادات ← الإدارة العامة (أو النظام).\n'
      '٢. اختر «تحويل النص إلى كلام».\n'
      '٣. اختر «خدمات Google للنطق» محرّكًا — ثبّته من متجر بلاي إن لم '
      'يكن موجودًا.\n'
      '٤. افتح ⚙ ← «تثبيت بيانات الصوت» واختر لغتك.\n'
      '٥. عد إلى الكتاب واضغط زر التشغيل.\n\n'
      'آيفون:\n'
      '١. الإعدادات ← تسهيلات الاستخدام ← المحتوى المنطوق.\n'
      '٢. «الأصوات» ← اختر اللغة ونزّل صوتًا.\n'
      '٣. عد إلى الكتاب واضغط زر التشغيل.\n\n'
      '(English: if you cannot hear this page, enable text-to-speech in '
      'your device settings and download a voice for your language.)';

  /// The speech language of each page — one entry per page, indexed by page
  /// number. Add a page, add an entry: this list is read with the shown
  /// page's index, so a short list is a range error the moment a reader
  /// flips onto the page it forgot.
  static const _pageLanguages = ['ar', 'ar', 'ar', 'ar'];

  // The Arabic twin, page for page. Same text on every page, same three
  // dressings; only the words and the direction change.
  static final _pages = <FlipBookPage>[
    FlipBookPage(
      id: 'rtl-0',
      title: kTitle1Ar,
      tagline: kStand1Ar,
      background: const MagazinePaper(quote: kQuote1Ar),
      style: magazineStyle,
      bodySegments: kPage1Ar,
      bodyWidgets: {
        2: const CircleCut(
          caption:
              'البناء نفسه يعمل على المنصتين. لا يختلف سوى الصوت وخطوط '
              'النظام، وكلاهما اختيار التطبيق.',
        ),
        4: const PullQuote(text: kQuote1Ar),
      },
    ),
    FlipBookPage(
      id: 'rtl-1',
      title: kTitle2Ar,
      tagline: kStand2Ar,
      background: const MagazinePaper(quote: kQuote2Ar, variant: 1),
      style: magazineStyle,
      bodySegments: kPage2Ar,
      bodyWidgets: {
        3: const PullQuote(text: kQuote2Ar, color: kTeal),
        5: const CircleCut(
          doodle: Doodle.android,
          logoOnEnd: false,
          caption:
              'لا يصدر الكتاب صوتاً بنفسه. يملك الزر والحالة والتسمية، '
              'ويترك لك الاختيار.',
        ),
      },
    ),
    FlipBookPage(
      id: 'rtl-2',
      title: kTitle3Ar,
      tagline: kStand3Ar,
      background: const MagazinePaper(quote: kQuote3Ar, variant: 2),
      style: magazineStyle,
      bodySegments: kPage3Ar,
      bodyWidgets: {
        2: const CircleCut(
          doodle: Doodle.apple,
          caption:
              'تخرج العلامات والإشارات والصفحات المحفوظة عبر callbacks '
              'وتعود عبر الحقول. المكان اختيارك أنت لا اختيار الكتاب.',
        ),
        4: const PullQuote(text: kQuote3Ar),
      },
    ),
    // The Arabic book's extra page. Deliberately last and deliberately plain:
    // the read-aloud dialog sends a reader here when the device has no Arabic
    // voice, so it must be legible when speech is exactly what is missing.
    FlipBookPage(
      id: 'rtl-3',
      title: 'إعدادات الصوت',
      tagline: 'إن لم تسمع شيئاً، فالإعداد في جهازك لا في الكتاب.',
      // Dressed like every other page, so it does not read as a different
      // app. Variant 1 puts the quote circle where this page's longer
      // instructions will not collide with it.
      background: const MagazinePaper(
        quote: 'إن لم تسمع شيئاً، فالإعداد في جهازك',
        variant: 1,
      ),
      style: magazineStyle,
      bodyText: _settingsBody,
    ),
  ];

  /// The page currently shown — the sentence callback carries no page, so
  /// the app remembers which page (and therefore which voice language) is
  /// open. Fed by onChanged below.
  ///
  /// Seeded from the same place the book opens at. Starting it at 0 while
  /// the book opened at page 3 meant the first PLAY looked up the wrong
  /// page's language.
  int _shownPage = PlaceStore.rtl.openAt;

  /// Reads one sentence in the shown page's language; if the device has no
  /// voice for it, a dialog points to the settings screen at the end of
  /// the book.
  Future<void> _readAloud(String sentence) async {
    final language = _pageLanguages[_shownPage];
    if (!await _reader.isAvailable(language)) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('لا يوجد صوت — no voice'),
            content: const Text(
              'لا يوجد صوت لهذه اللغة على هذا الجهاز — الخطوات كاملة في '
              'صفحة «إعدادات الصوت» آخر الكتاب.\n\n'
              'No voice for this language is installed — full steps are on '
              "the book's last page.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    await _reader.read(sentence, language, _speed);
  }

  void _saveMarks(List<ReaderMark> marks) {
    setState(() => _marks = marks);
    MarkStore.save(marks, rtl: true);
  }

  @override
  @override
  void initState() {
    super.initState();
    startPhoneSoundWatch();
  }

  @override
  void dispose() {
    stopPhoneSoundWatch();
    _reader.dispose();
    _sound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The counterpart of `LtrBook`: mostly package defaults, mirrored
    // automatically by `textDirection`.
    //
    // Words are the one exception, and they are not decoration. The
    // package's default labels are English, so an Arabic book that passed
    // NOTHING would read "CONTENTS" and "Search by title" to an Arabic
    // reader. Language is a correctness requirement; colour is a taste. So
    // this book overrides every user-visible string, which is also the
    // honest demonstration: **every label is translatable**.
    // A Scaffold only so the phone-sound notes can show as snack bars.
    return Scaffold(
      backgroundColor: kStock,
      resizeToAvoidBottomInset: false,
      body: _book(context),
    );
  }

  Widget _book(BuildContext context) {
    return FlipBook(
      // Coated stock catches light as it bends — the sheen on the curling
      // page, turned up from the default for the magazine look.
      shine: 0.55,
      onClose: () => Navigator.of(context).pop(),

      // RTL: layout, arrows, flips, and swipes all mirror from this alone.
      pages: FlipBookPages(
        items: _pages,
        textDirection: TextDirection.rtl,
        // Both books show their position; this is per book, not global.
        showNumber: true,
        initialPage: PlaceStore.rtl.openAt,
        // Two jobs on one callback: the voice needs to know which page (and
        // therefore which language) is open, and the resume position moves
        // with every turn so closing the book never loses the reader's place.
        onChanged: (page) {
          _shownPage = page;
          PlaceStore.rtl.resume = page;
          Persist.save();
        },
      ),

      header: const FlipBookHeader(closeLabel: 'إغلاق', autoHide: true),

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
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: kOnColour,
        ),
        pageNumberStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kOnColour.withValues(alpha: 0.75),
        ),
        index: const FlipBookIndexButton(label: 'الفهرس'),
        nav: const FlipBookNavButtons(
          previousLabel: 'السابق',
          nextLabel: 'التالي',
        ),
        sound: FlipBookSound(
          onFlip: _sound.play,
          muteLabel: 'كتم',
          unmuteLabel: 'تشغيل الصوت',
          silenced: phone.silent,
          silencedLabel: 'الهاتف في الوضع الصامت',
          onSilencedTap: () => showPhoneNote(
            'هاتفك في الوضع الصامت. أوقف الوضع الصامت لتسمع صوت تقليب الصفحة.',
          ),
        ),
      ),

      // The table of contents in Arabic, with the same export seam: the RTL
      // book proves every label travels, including the export ones.
      contents: FlipBookContents(
        heading: 'جدول المحتويات',
        searchHint: 'ابحث بالعنوان',
        headingStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: kPink,
        ),
        titleStyle: const TextStyle(fontSize: 15, color: kInk, height: 1.6),
        currentStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: kPink,
          height: 1.6,
        ),
        currentIcon: Icons.bookmark_rounded,
        currentIconColor: kPink,
        numberStyle: const TextStyle(fontSize: 11, color: kInkSoft),
        searchStyle: const TextStyle(fontSize: 14, color: kInk),
        searchHintStyle: const TextStyle(fontSize: 14, color: kInkSoft),
        searchIcon: Icons.search_rounded,
        searchIconColor: kInkSoft,
        searchFill: const Color(0x0F2A2A2A),
        searchFocusBorder: kTeal,
        dividerColor: const Color(0x1F2A2A2A),
        splashColor: kPink.withValues(alpha: 0.12),
        export: FlipBookExport(
          onExport: (kind, entries) =>
              showExport(context, kind, entries, rtl: true),
          label: 'تصدير',
          heading: 'ما الذي تريد تصديره؟',
          savedLabel: 'الصفحات التي حفظتها',
          markedLabel: 'المقاطع التي علّمتها',
          wholeLabel: 'الكتاب كاملاً',
          cancelLabel: 'إلغاء',
          emptyLabel: 'لا يوجد شيء محفوظ بعد',
        ),
      ),

      bookmarks: FlipBookBookmarks(
        bookmarkedPage: PlaceStore.rtl.bookmark,
        onBookmark: (page) => setState(() {
          final store = PlaceStore.rtl;
          store.bookmark = store.bookmark == page ? null : page;
          Persist.save();
        }),
        saved: PlaceStore.rtl.saved,
        onSavedChanged: (ids) => setState(() {
          PlaceStore.rtl.saved = ids;
          Persist.save();
        }),
        bookmarkLabel: 'تابع من هنا',
        bookmarkedLabel: 'أزل الإشارة',
        saveLabel: 'احفظ هذه الصفحة',
        unsaveLabel: 'أزل هذه الصفحة',
      ),

      // The voice is not decoration: the package ships no speech engine, so
      // these callbacks are the minimum a talking book needs.
      readAloud: FlipBookReadAloud(
        onRead: (sentence) {
          noteVolumeOnce('مستوى صوت هاتفك 0%. ارفعه لتسمع القراءة.');
          return _readAloud(sentence);
        },
        onStop: _reader.stop,
        onPause: _reader.pause,
        onResume: _reader.resume,
        // The playback terms Arabic media apps actually use — not literal
        // translations: تشغيل (play), استئناف (resume-playback).
        playLabel: 'تشغيل',
        // Switches the control on. Its label alone would not: without this
        // the button never appears.
        playAll: true,
        playAllLabel: 'تشغيل الكل',
        pauseLabel: 'إيقاف مؤقت',
        resumeLabel: 'استئناف',
        stopLabel: 'إيقاف',
        readAloudSemantics: 'اقرأ هذه الصفحة بصوت عالٍ',
        readAllSemantics: 'اقرأ الكتاب كاملاً بصوت عالٍ',
        pauseSemantics: 'إيقاف مؤقت',
        stopSemantics: 'إيقاف القراءة',
        // No `options` — so all three speeds appear, unlike the LTR book.
        speed: FlipBookSpeedControl(
          initial: _speed,
          semantics: 'سرعة القراءة',
          // Both halves matter. setState redraws the pill; setSpeed
          // reaches the engine, and that is what makes the change land at
          // the NEXT WORD instead of the next paragraph.
          onChanged: (speed) {
            setState(() => _speed = speed);
            unawaited(_reader.setSpeed(speed));
          },
        ),
      ),

      // Marks belong to the reader, so storing them is the app's job.
      marker: FlipBookMarker(
        marks: _marks,
        onChanged: _saveMarks,
        // Same pink as the LTR book — the lit pencil and the marks it makes
        // must be the same colour, or marking mode looks switched off.
        color: kPink.withValues(alpha: 0.32),
        pencilLabel: 'علّم مقطعًا',
        stopLabel: 'إيقاف التعليم',
        clearLabel: 'امسح كل العلامات',
        saveLabel: 'حفظ',
        cancelLabel: 'إلغاء',
      ),

      // The learned-gesture memory is app-wide: retiring the hint in one
      // book retires it in both.
      swipe: FlipBookSwipe(
        hint: SwipeMemory.learned
            ? null
            : FlipBookSwipeHint(
                // The same bar as the LTR book, so both editions look like
                // one demo. The package draws plain text with chevrons;
                // anything richer is the app's business, via `child`.
                text: 'اسحب',
                onRetired: SwipeMemory.retire,
                showFor: const Duration(seconds: 4),
                child: const HintBar(child: Text('اسحب')),
              ),
      ),
    );
  }
}
