import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_flip/page_curl_flip.dart';

/// A footer control, matched by its screen-reader label.
Finder ctl(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
      description: 'control "$label"',
    );

/// Completes a flip started by a tap or a controller call.
Future<void> _finishFlip(
  WidgetTester tester, {
  FlipSpeed speed = FlipSpeed.medium,
}) async {
  await tester.pump();
  await tester.pump(speed.duration + const Duration(milliseconds: 100));
  await tester.pump();
}

const _threePages = [
  FlipBookPage(title: 'One', body: Text('page one')),
  FlipBookPage(title: 'Two', body: Text('page two')),
  FlipBookPage(title: 'Three', body: Text('page three')),
];

double _opacityAbove(WidgetTester tester, Finder child) => tester
    .widget<AnimatedOpacity>(
        find.ancestor(of: child, matching: find.byType(AnimatedOpacity)).first)
    .opacity;

void main() {
  group('FlipBookController', () {
    testWidgets(
        'isMuted reads the book; toggleMute mutes and unmutes the flip '
        'sound, forward and backward', (tester) async {
      final c = FlipBookController();
      expect(c.isMuted, isFalse, reason: 'detached reads as unmuted');

      var flips = 0;
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          controller: c,
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          footer: FlipBookFooter(
            sound: FlipBookSound(onFlip: () async => flips++),
          ),
          pages: const FlipBookPages(items: _threePages),
        ),
      ));
      expect(c.isMuted, isFalse);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      c.toggleMute();
      await tester.pump();
      expect(c.isMuted, isTrue);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);

      unawaited(c.nextPage());
      await _finishFlip(tester);
      expect(c.page, 1);
      expect(flips, 0, reason: 'a muted flip plays no sound');

      c.toggleMute();
      await tester.pump();
      expect(c.isMuted, isFalse);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      unawaited(c.previousPage());
      await tester.pump();
      await _finishFlip(tester);
      expect(c.page, 0);
      expect(flips, 1, reason: 'an unmuted backward flip plays the sound');
    });

    testWidgets(
        'a rebuilt book hands itself from the old controller to the new',
        (tester) async {
      final first = FlipBookController();
      final second = FlipBookController();
      Widget book(FlipBookController c) => MaterialApp(
            home: FlipBook(
              controller: c,
              onClose: () {},
              swipe: const FlipBookSwipe(hint: null),
              pages: const FlipBookPages(items: _threePages),
            ),
          );

      await tester.pumpWidget(book(first));
      expect(first.isAttached, isTrue);
      expect(second.isAttached, isFalse);

      await tester.pumpWidget(book(second));
      expect(first.isAttached, isFalse);
      expect(second.isAttached, isTrue);

      second.jumpToPage(2);
      await tester.pump();
      expect(find.text('page three'), findsOneWidget);
      expect(second.page, 2);
      expect(first.page, 0, reason: 'the old controller no longer drives it');
    });

    testWidgets(
        'nextPage on the last page and previousPage on the first do nothing',
        (tester) async {
      final c = FlipBookController();
      final changes = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          controller: c,
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          pages: FlipBookPages(items: _threePages, onChanged: changes.add),
        ),
      ));

      unawaited(c.previousPage());
      await _finishFlip(tester);
      expect(c.page, 0);
      expect(find.text('page one'), findsOneWidget);

      c.jumpToPage(2);
      await tester.pump();
      changes.clear();
      unawaited(c.nextPage());
      await _finishFlip(tester);
      expect(c.page, 2);
      expect(find.text('page three'), findsOneWidget);
      expect(changes, isEmpty);
    });

    testWidgets(
        'under RTL previousPage runs the forward curl: the destination shows '
        'through at once', (tester) async {
      final c = FlipBookController();
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          controller: c,
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          pages: const FlipBookPages(
            textDirection: TextDirection.rtl,
            items: _threePages,
          ),
        ),
      ));
      c.jumpToPage(1);
      await tester.pump();
      expect(find.text('page two'), findsOneWidget);

      unawaited(c.previousPage());
      await tester.pump();
      // The forward curl lays the destination underneath and peels a
      // bitmap of the current page; a backward curl would still show it.
      expect(find.text('page one'), findsOneWidget);
      expect(find.text('page two'), findsNothing);

      await _finishFlip(tester);
      expect(c.page, 0);
      expect(find.text('page one'), findsOneWidget);
    });
  });

  group('Chrome', () {
    testWidgets('a second tap hides an auto-hiding header', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          header: const FlipBookHeader(autoHide: true),
          swipe: const FlipBookSwipe(hint: null),
          pages: const FlipBookPages(items: _threePages),
        ),
      ));
      final close = find.byIcon(Icons.close);
      expect(_opacityAbove(tester, close), 0);

      await tester.tap(find.text('page one'));
      await tester.pump();
      expect(_opacityAbove(tester, close), 1);

      await tester.tap(find.text('page one'));
      await tester.pump();
      expect(_opacityAbove(tester, close), 0);
      // The always-on footer never moved.
      expect(_opacityAbove(tester, find.byIcon(Icons.chevron_right)), 1);
    });

    testWidgets('a mouse entering the bottom edge reveals a hidden footer',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          footer: const FlipBookFooter(
            autoHide: true,
            revealFor: Duration(seconds: 1),
          ),
          swipe: const FlipBookSwipe(hint: null),
          pages: const FlipBookPages(items: _threePages),
        ),
      ));
      final next = find.byIcon(Icons.chevron_right);
      expect(_opacityAbove(tester, next), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(400, 300));
      await tester.pump();
      expect(_opacityAbove(tester, next), 0, reason: 'mid-page hover: hidden');

      await mouse.moveTo(const Offset(400, 590));
      await tester.pump();
      expect(_opacityAbove(tester, next), 1);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(_opacityAbove(tester, next), 0, reason: 'the clock retires it');
    });

    testWidgets('a mouse entering the top edge reveals a hidden header',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          header: const FlipBookHeader(autoHide: true),
          swipe: const FlipBookSwipe(hint: null),
          pages: const FlipBookPages(items: _threePages),
        ),
      ));
      final close = find.byIcon(Icons.close);
      expect(_opacityAbove(tester, close), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(400, 300));
      await tester.pump();
      await mouse.moveTo(const Offset(400, 10));
      await tester.pump();
      expect(_opacityAbove(tester, close), 1);

      await tester.pump(const Duration(seconds: 4));
      expect(_opacityAbove(tester, close), 0);
    });
  });

  group('Page layout', () {
    testWidgets(
        'a custom read-marker builder draws every block and receives the '
        'unit being read', (tester) async {
      final seen = <String>[];
      final pending = <Completer<void>>[];
      Widget draw(BuildContext context, ReadMarkerText d) {
        final m = d.marked;
        final label =
            m == null ? '[${d.text}]' : '[${d.text}]<${m.start}-${m.end}>';
        seen.add(label);
        return Text(label, style: d.style);
      }

      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          readAloud: FlipBookReadAloud(
            onRead: (_) {
              final c = Completer<void>();
              pending.add(c);
              return c.future;
            },
            highlight: FlipBookHighlight(builder: draw),
          ),
          pages: const FlipBookPages(items: [
            FlipBookPage(title: 'Cover', bodyText: 'First one. Second one.'),
          ]),
        ),
      ));
      expect(find.text('[Cover]'), findsOneWidget);
      expect(find.text('[First one. Second one.]'), findsOneWidget);

      await tester.tap(ctl('Read this page aloud'));
      await tester.pump();
      expect(find.text('[Cover]<0-5>'), findsOneWidget);
      expect(find.text('[First one. Second one.]'), findsOneWidget);

      pending.removeAt(0).complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('[Cover]'), findsOneWidget);
      expect(find.text('[First one. Second one.]<0-10>'), findsOneWidget);

      while (pending.isNotEmpty) {
        pending.removeAt(0).complete();
        await tester.pump();
        await tester.pump();
      }
      expect(find.text('[First one. Second one.]'), findsOneWidget);
      expect(seen, isNotEmpty);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'a text page with a background fills behind the words and insets '
        'only the words', (tester) async {
      const bgKey = ValueKey('bg');
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          pages: const FlipBookPages(items: [
            FlipBookPage(
              title: 'Art',
              bodyText: 'over the art',
              background: ColoredBox(key: bgKey, color: Color(0xFF223344)),
            ),
          ]),
        ),
      ));
      final bg = find.byKey(bgKey);
      final words = find.text('over the art', findRichText: true);
      expect(bg, findsOneWidget);
      expect(words, findsOneWidget);
      expect(
        find.ancestor(of: bg, matching: find.byType(SingleChildScrollView)),
        findsOneWidget,
      );
      final scroll = tester.widget<SingleChildScrollView>(
          find.ancestor(of: bg, matching: find.byType(SingleChildScrollView)));
      expect(scroll.padding, isNull, reason: 'the background is not inset');
      expect(
          tester.getTopLeft(words).dx, greaterThan(tester.getTopLeft(bg).dx));
      expect(
          tester.getTopLeft(words).dy, greaterThan(tester.getTopLeft(bg).dy));
    });

    testWidgets(
        'bodyWidgets sit before their segment index, and one past the end '
        'appends', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          pages: const FlipBookPages(items: [
            FlipBookPage(
              title: 'W',
              bodySegments: ['Seg A.', 'Seg B.'],
              bodyWidgets: {
                0: Text('W0'),
                1: Text('W1'),
                2: Text('TAIL'),
              },
            ),
          ]),
        ),
      ));
      double y(String text) =>
          tester.getTopLeft(find.text(text, findRichText: true)).dy;
      final order = ['W0', 'Seg A.', 'W1', 'Seg B.', 'TAIL'];
      for (final t in order) {
        expect(find.text(t, findRichText: true), findsOneWidget, reason: t);
      }
      for (var i = 1; i < order.length; i++) {
        expect(y(order[i]), greaterThan(y(order[i - 1])),
            reason: '${order[i]} below ${order[i - 1]}');
      }
    });
  });

  group('Read-aloud sentence split', () {
    testWidgets(
        'CJK terminators and newlines end a unit unconditionally, closing '
        'quotes stay with their sentence', (tester) async {
      final units = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          readAloud: FlipBookReadAloud(onRead: (u) async => units.add(u)),
          pages: const FlipBookPages(items: [
            FlipBookPage(bodyText: 'One。”Two！\nWow!” Yes.'),
          ]),
        ),
      ));
      await tester.tap(ctl('Read this page aloud'));
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(units, ['One。”', 'Two！', 'Wow!”', 'Yes.']);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Bookmarks and export', () {
    testWidgets(
        'the bookmarked page shows the bookmarked glyph, label and active '
        'colour, or the caller child', (tester) async {
      const active = Color(0xFF00AA00);
      Widget book({Widget? child}) => MaterialApp(
            home: FlipBook(
              onClose: () {},
              swipe: const FlipBookSwipe(hint: null),
              bookmarks: FlipBookBookmarks(
                bookmarkedPage: 0,
                onBookmark: (_) {},
                activeColor: active,
                bookmarkedChild: child,
              ),
              pages: const FlipBookPages(items: _threePages),
            ),
          );

      await tester.pumpWidget(book());
      expect(ctl('This is where you carry on'), findsOneWidget);
      expect(ctl('Carry on from here'), findsNothing);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(Icons.bookmark)).color, active);

      await tester.pumpWidget(book(child: const Text('HERE')));
      expect(find.text('HERE'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNothing);
    });

    testWidgets(
        'export derives empty-text marks from the page text, sorted in '
        'reading order, and handles bodyText and body-less pages',
        (tester) async {
      FlipBookExportKind? kind;
      List<FlipBookExportEntry>? got;
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          marker: const FlipBookMarker(marks: [
            ReaderMark(pageId: 'p1', segment: 0, start: 6, end: 10),
            ReaderMark(pageId: 'p1', segment: 0, start: 0, end: 5),
            ReaderMark(pageId: 'p2', segment: 1, start: 0, end: 5),
            ReaderMark(pageId: 'p2', segment: 0, start: 4, end: 99),
            ReaderMark(pageId: 'p2', segment: 7, start: 0, end: 3),
            ReaderMark(pageId: 'p3', segment: 0, start: 0, end: 3),
          ]),
          contents: FlipBookContents(
            export: FlipBookExport(onExport: (k, e) {
              kind = k;
              got = e;
            }),
          ),
          pages: const FlipBookPages(items: [
            FlipBookPage(id: 'p1', title: 'P1', bodyText: 'Alpha beta gamma.'),
            FlipBookPage(
              id: 'p2',
              title: 'P2',
              bodySegments: ['One two.', 'Three four.'],
            ),
            FlipBookPage(id: 'p3', title: 'P3'),
          ]),
        ),
      ));
      await tester.tap(ctl('INDEX'));
      await tester.pumpAndSettle();

      await tester.tap(ctl('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passages I marked'));
      await tester.pumpAndSettle();
      expect(kind, FlipBookExportKind.markedText);
      expect(got!.map((e) => e.number), [1, 2]);
      expect(got![0].marks, ['Alpha', 'beta']);
      expect(got![1].marks, ['two.', 'Three']);

      await tester.tap(ctl('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The whole book'));
      await tester.pumpAndSettle();
      expect(kind, FlipBookExportKind.wholeBook);
      expect(got![0].body, ['Alpha beta gamma.']);
      expect(got![1].body, ['One two.', 'Three four.']);
      expect(got![2].body, isEmpty);
      expect(got![2].marks, isEmpty);
    });

    testWidgets('Cancel closes the export sheet without exporting',
        (tester) async {
      var exports = 0;
      await tester.pumpWidget(MaterialApp(
        home: FlipBook(
          onClose: () {},
          swipe: const FlipBookSwipe(hint: null),
          contents: FlipBookContents(
            export: FlipBookExport(onExport: (_, __) => exports++),
          ),
          pages: const FlipBookPages(items: _threePages),
        ),
      ));
      await tester.tap(ctl('INDEX'));
      await tester.pumpAndSettle();
      await tester.tap(ctl('Export'));
      await tester.pumpAndSettle();
      expect(find.text('What would you like to export?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('What would you like to export?'), findsNothing);
      expect(exports, 0);
    });
  });
}
