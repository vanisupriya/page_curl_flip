import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_flip/page_curl_flip.dart';

Future<void> _flipA() async {}
Future<void> _flipB() async {}
Future<void> _readA(String _) async {}
void _marksA(List<ReaderMark> _) {}
void _marksB(List<ReaderMark> _) {}
void _pageA(int _) {}
void _pageB(int _) {}

/// Builds a [ReadMarkerText] at run time, so the constructor itself runs.
ReadMarkerText _details(String text, TextStyle style, TextRange? marked) =>
    ReadMarkerText(
      text: text,
      style: style,
      marked: marked,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );

void main() {
  _footerContract();
  _headerContract();
  _markerContract();
  _pagesContract();
  _swipeContract();
  _readSpeedContract();
  _flipSpeedContract();
  _readMarkerTextContract();
  _readerMarkContract();
  _exportEntryContract();
  _pageAndReadAloudContract();
}

void _footerContract() {
  group('FlipBookFooter.copyWith', () {
    const indexA = FlipBookIndexButton(label: 'A');
    const indexB = FlipBookIndexButton(label: 'B');
    const navA = FlipBookNavButtons(previousLabel: 'A');
    const navB = FlipBookNavButtons(previousLabel: 'B');
    const soundA = FlipBookSound(onFlip: _flipA);
    const soundB = FlipBookSound(onFlip: _flipB);
    const original = FlipBookFooter(
      color: Color(0xFF000001),
      radius: 1,
      autoHide: true,
      revealFor: Duration(seconds: 1),
      tapLabelFor: Duration(seconds: 2),
      tapLabelStyle: TextStyle(fontSize: 1),
      tapLabelColor: Color(0xFF000002),
      horizontalInset: 3,
      iconSize: 4,
      iconColor: Color(0xFF000003),
      pageNumberStyle: TextStyle(fontSize: 2),
      index: indexA,
      nav: navA,
      sound: soundA,
    );

    test('no arguments keeps every field', () {
      final copy = original.copyWith();
      expect(copy.color, const Color(0xFF000001));
      expect(copy.radius, 1);
      expect(copy.autoHide, isTrue);
      expect(copy.revealFor, const Duration(seconds: 1));
      expect(copy.tapLabelFor, const Duration(seconds: 2));
      expect(copy.tapLabelStyle.fontSize, 1);
      expect(copy.tapLabelColor, const Color(0xFF000002));
      expect(copy.horizontalInset, 3);
      expect(copy.iconSize, 4);
      expect(copy.iconColor, const Color(0xFF000003));
      expect(copy.pageNumberStyle.fontSize, 2);
      expect(copy.index, same(indexA));
      expect(copy.nav, same(navA));
      expect(copy.sound, same(soundA));
    });

    test('every argument overrides its field', () {
      final copy = original.copyWith(
        color: const Color(0xFF00000A),
        radius: 10,
        autoHide: false,
        revealFor: const Duration(seconds: 10),
        tapLabelFor: const Duration(seconds: 20),
        tapLabelStyle: const TextStyle(fontSize: 10),
        tapLabelColor: const Color(0xFF00000B),
        horizontalInset: 30,
        iconSize: 40,
        iconColor: const Color(0xFF00000C),
        pageNumberStyle: const TextStyle(fontSize: 20),
        index: indexB,
        nav: navB,
        sound: soundB,
      );
      expect(copy.color, const Color(0xFF00000A));
      expect(copy.radius, 10);
      expect(copy.autoHide, isFalse);
      expect(copy.revealFor, const Duration(seconds: 10));
      expect(copy.tapLabelFor, const Duration(seconds: 20));
      expect(copy.tapLabelStyle.fontSize, 10);
      expect(copy.tapLabelColor, const Color(0xFF00000B));
      expect(copy.horizontalInset, 30);
      expect(copy.iconSize, 40);
      expect(copy.iconColor, const Color(0xFF00000C));
      expect(copy.pageNumberStyle.fontSize, 20);
      expect(copy.index, same(indexB));
      expect(copy.nav, same(navB));
      expect(copy.sound, same(soundB));
      expect(original.radius, 1, reason: 'the original is not mutated');
    });

    test('a null nullable field stays null', () {
      final copy = const FlipBookFooter().copyWith(radius: 5);
      expect(copy.horizontalInset, isNull);
      expect(copy.sound, isNull);
      expect(copy.radius, 5);
    });
  });
}

void _headerContract() {
  group('FlipBookHeader.copyWith', () {
    const actionA = Text('a');
    const actionB = Text('b');
    const original = FlipBookHeader(
      closeIcon: Icons.arrow_back,
      closeColor: Color(0xFF000001),
      closeLabel: 'Back',
      action: actionA,
      autoHide: true,
      closeAtEnd: true,
    );

    test('no arguments keeps every field', () {
      final copy = original.copyWith();
      expect(copy.closeIcon, Icons.arrow_back);
      expect(copy.closeColor, const Color(0xFF000001));
      expect(copy.closeLabel, 'Back');
      expect(copy.action, same(actionA));
      expect(copy.autoHide, isTrue);
      expect(copy.closeAtEnd, isTrue);
    });

    test('every argument overrides its field', () {
      final copy = original.copyWith(
        closeIcon: Icons.close,
        closeColor: const Color(0xFF000002),
        closeLabel: 'Close',
        action: actionB,
        autoHide: false,
        closeAtEnd: false,
      );
      expect(copy.closeIcon, Icons.close);
      expect(copy.closeColor, const Color(0xFF000002));
      expect(copy.closeLabel, 'Close');
      expect(copy.action, same(actionB));
      expect(copy.autoHide, isFalse);
      expect(copy.closeAtEnd, isFalse);
    });
  });
}

void _markerContract() {
  group('FlipBookMarker.copyWith', () {
    const markA = ReaderMark(pageId: 'a', segment: 0, start: 0, end: 1);
    const markB = ReaderMark(pageId: 'b', segment: 0, start: 0, end: 1);
    const pencilA = Text('pa');
    const clearA = Text('ca');
    const saveA = Text('sa');
    const cancelA = Text('xa');
    const pencilB = Text('pb');
    const clearB = Text('cb');
    const saveB = Text('sb');
    const cancelB = Text('xb');
    const original = FlipBookMarker(
      marks: [markA],
      onChanged: _marksA,
      actionBarColor: Color(0xFF000001),
      actionBarOpacity: 0.1,
      color: Color(0xFF000002),
      pencil: pencilA,
      clear: clearA,
      save: saveA,
      cancel: cancelA,
      pencilLabel: 'p1',
      stopLabel: 's1',
      clearLabel: 'c1',
      saveLabel: 'v1',
      cancelLabel: 'x1',
      actionStyle: TextStyle(fontSize: 1),
      activeColor: Color(0xFF000003),
      iconColor: Color(0xFF000004),
    );

    test('no arguments keeps every field', () {
      final copy = original.copyWith();
      expect(copy.marks, [markA]);
      expect(copy.onChanged, same(_marksA));
      expect(copy.actionBarColor, const Color(0xFF000001));
      expect(copy.actionBarOpacity, 0.1);
      expect(copy.color, const Color(0xFF000002));
      expect(copy.pencil, same(pencilA));
      expect(copy.clear, same(clearA));
      expect(copy.save, same(saveA));
      expect(copy.cancel, same(cancelA));
      expect(copy.pencilLabel, 'p1');
      expect(copy.stopLabel, 's1');
      expect(copy.clearLabel, 'c1');
      expect(copy.saveLabel, 'v1');
      expect(copy.cancelLabel, 'x1');
      expect(copy.actionStyle?.fontSize, 1);
      expect(copy.activeColor, const Color(0xFF000003));
      expect(copy.iconColor, const Color(0xFF000004));
    });

    test('every argument overrides its field', () {
      final copy = original.copyWith(
        marks: [markB],
        onChanged: _marksB,
        actionBarColor: const Color(0xFF00000A),
        actionBarOpacity: 0.9,
        color: const Color(0xFF00000B),
        pencil: pencilB,
        clear: clearB,
        save: saveB,
        cancel: cancelB,
        pencilLabel: 'p2',
        stopLabel: 's2',
        clearLabel: 'c2',
        saveLabel: 'v2',
        cancelLabel: 'x2',
        actionStyle: const TextStyle(fontSize: 2),
        activeColor: const Color(0xFF00000C),
        iconColor: const Color(0xFF00000D),
      );
      expect(copy.marks, [markB]);
      expect(copy.onChanged, same(_marksB));
      expect(copy.actionBarColor, const Color(0xFF00000A));
      expect(copy.actionBarOpacity, 0.9);
      expect(copy.color, const Color(0xFF00000B));
      expect(copy.pencil, same(pencilB));
      expect(copy.clear, same(clearB));
      expect(copy.save, same(saveB));
      expect(copy.cancel, same(cancelB));
      expect(copy.pencilLabel, 'p2');
      expect(copy.stopLabel, 's2');
      expect(copy.clearLabel, 'c2');
      expect(copy.saveLabel, 'v2');
      expect(copy.cancelLabel, 'x2');
      expect(copy.actionStyle?.fontSize, 2);
      expect(copy.activeColor, const Color(0xFF00000C));
      expect(copy.iconColor, const Color(0xFF00000D));
    });
  });
}

void _pagesContract() {
  group('FlipBookPages.copyWith', () {
    const pageA = FlipBookPage(title: 'A');
    const pageB = FlipBookPage(title: 'B');
    const original = FlipBookPages(
      items: [pageA],
      paperColor: Color(0xFF000001),
      style: FlipBookPageStyle(titleStyle: TextStyle(fontSize: 1)),
      textDirection: TextDirection.rtl,
      initialPage: 2,
      onChanged: _pageA,
      showNumber: true,
    );

    test('no arguments keeps every field', () {
      final copy = original.copyWith();
      expect(copy.items.single, same(pageA));
      expect(copy.paperColor, const Color(0xFF000001));
      expect(copy.style.titleStyle.fontSize, 1);
      expect(copy.textDirection, TextDirection.rtl);
      expect(copy.initialPage, 2);
      expect(copy.onChanged, same(_pageA));
      expect(copy.showNumber, isTrue);
    });

    test('every argument overrides its field', () {
      final copy = original.copyWith(
        items: [pageB],
        paperColor: const Color(0xFF000002),
        style: const FlipBookPageStyle(titleStyle: TextStyle(fontSize: 2)),
        textDirection: TextDirection.ltr,
        initialPage: 5,
        onChanged: _pageB,
        showNumber: false,
      );
      expect(copy.items.single, same(pageB));
      expect(copy.paperColor, const Color(0xFF000002));
      expect(copy.style.titleStyle.fontSize, 2);
      expect(copy.textDirection, TextDirection.ltr);
      expect(copy.initialPage, 5);
      expect(copy.onChanged, same(_pageB));
      expect(copy.showNumber, isFalse);
    });
  });
}

void _swipeContract() {
  group('FlipBookSwipe.copyWith', () {
    const hintA = FlipBookSwipeHint(text: 'a');
    const hintB = FlipBookSwipeHint(text: 'b');
    const original = FlipBookSwipe(enabled: false, hint: hintA);

    test('no arguments keeps every field', () {
      final copy = original.copyWith();
      expect(copy.enabled, isFalse);
      expect(copy.hint, same(hintA));
    });

    test('every argument overrides its field', () {
      final copy = original.copyWith(enabled: true, hint: hintB);
      expect(copy.enabled, isTrue);
      expect(copy.hint, same(hintB));
    });
  });
}

void _readSpeedContract() {
  group('FlipBookReadSpeed.rateFactor', () {
    test('each speed maps to its documented multiplier', () {
      expect(FlipBookReadSpeed.slow.rateFactor, 0.5);
      expect(FlipBookReadSpeed.normal.rateFactor, 1.0);
      expect(FlipBookReadSpeed.fast.rateFactor, 1.5);
    });
  });
}

void _flipSpeedContract() {
  group('FlipSpeed.hashCode', () {
    test('equal speeds hash alike, so they collapse in a set', () {
      final speeds = <FlipSpeed>{FlipSpeed.medium, FlipSpeed.fast}
        ..add(const FlipSpeed.custom(Duration(milliseconds: 1200)));
      expect(speeds, hasLength(2));
      expect(
        const FlipSpeed.custom(Duration(milliseconds: 750)).hashCode,
        FlipSpeed.fast.hashCode,
      );
    });
  });
}

void _readMarkerTextContract() {
  group('ReadMarkerText', () {
    test('carries every field it is given', () {
      const style = TextStyle(fontSize: 13);
      const range = TextRange(start: 2, end: 5);
      final details = _details('hello world', style, range);
      expect(details.text, 'hello world');
      expect(details.style, same(style));
      expect(details.marked, range);
      expect(details.maxLines, 3);
      expect(details.overflow, TextOverflow.ellipsis);
    });

    test('marked is null while the block is idle', () {
      final details = _details('idle', const TextStyle(), null);
      expect(details.marked, isNull);
    });
  });
}

void _readerMarkContract() {
  group('ReaderMark', () {
    const mark = ReaderMark(
      pageId: 'p1',
      segment: 2,
      start: 4,
      end: 9,
      text: 'words',
    );

    test('toMap → fromMap round-trips every field', () {
      final map = mark.toMap();
      expect(map, {
        'pageId': 'p1',
        'segment': 2,
        'start': 4,
        'end': 9,
        'text': 'words',
      });
      final back = ReaderMark.fromMap(map);
      expect(back, mark);
      expect(back.text, 'words');
    });

    test('fromMap defaults a missing segment to 0 and text to empty', () {
      final back = ReaderMark.fromMap(
        <String, dynamic>{'pageId': 'p', 'start': 1, 'end': 2},
      );
      expect(back.segment, 0);
      expect(back.text, '');
      expect(back.start, 1);
      expect(back.end, 2);
    });

    test('copyWith keeps or overrides each field', () {
      final kept = mark.copyWith();
      expect(kept.pageId, 'p1');
      expect(kept.segment, 2);
      expect(kept.start, 4);
      expect(kept.end, 9);
      expect(kept.text, 'words');
      final changed = mark.copyWith(
        pageId: 'p2',
        segment: ReaderMark.titleSegment,
        start: 0,
        end: 1,
        text: 'other',
      );
      expect(changed.pageId, 'p2');
      expect(changed.segment, -1);
      expect(changed.start, 0);
      expect(changed.end, 1);
      expect(changed.text, 'other');
    });

    test('equality ignores text but every placing field counts', () {
      expect(mark, mark.copyWith(text: 'edited'));
      expect(mark.hashCode, mark.copyWith(text: 'edited').hashCode);
      expect(mark, isNot(mark.copyWith(pageId: 'x')));
      expect(mark, isNot(mark.copyWith(segment: 3)));
      expect(mark, isNot(mark.copyWith(start: 5)));
      expect(mark, isNot(mark.copyWith(end: 10)));
      // ignore: unrelated_type_equality_checks
      expect(mark == 'p1', isFalse);
      expect(mark == mark, isTrue);
    });

    test('toString shows the text only when there is some', () {
      expect(mark.toString(), 'ReaderMark(p1 seg:2 4-9 "words")');
      expect(mark.copyWith(text: '').toString(), 'ReaderMark(p1 seg:2 4-9 )');
    });
  });
}

void _exportEntryContract() {
  group('FlipBookExportEntry', () {
    test('toMap includes every field that is set', () {
      const entry = FlipBookExportEntry(
        number: 3,
        id: 'j3',
        title: 'Three',
        tagline: 'tag',
        body: ['a', 'b'],
        marks: ['m'],
      );
      expect(entry.toMap(), {
        'number': 3,
        'id': 'j3',
        'title': 'Three',
        'tagline': 'tag',
        'body': ['a', 'b'],
        'marks': ['m'],
      });
    });

    test('toMap omits every unset field', () {
      const entry = FlipBookExportEntry(number: 1);
      expect(entry.toMap(), {'number': 1});
    });

    test('toString summarises number, title and counts', () {
      const full = FlipBookExportEntry(
        number: 2,
        title: 'Two',
        body: ['a', 'b', 'c'],
        marks: ['m'],
      );
      expect(full.toString(), 'FlipBookExportEntry(2, Two, 3 units, 1 marks)');
      expect(
        const FlipBookExportEntry(number: 7).toString(),
        'FlipBookExportEntry(7, -, 0 units, 0 marks)',
      );
    });
  });
}

void _pageAndReadAloudContract() {
  group('copyWith with no arguments keeps the remaining fields', () {
    test('FlipBookPage keeps its title', () {
      const page = FlipBookPage(id: 'a', title: 'Kept');
      final copy = page.copyWith(id: 'b');
      expect(copy.title, 'Kept');
      expect(copy.id, 'b');
    });

    test('FlipBookReadAloud keeps playAll', () {
      const aloud = FlipBookReadAloud(onRead: _readA, playAll: true);
      final copy = aloud.copyWith(readTitle: false);
      expect(copy.playAll, isTrue);
      expect(copy.readTitle, isFalse);
      expect(copy.onRead, same(_readA));
    });
  });
}
