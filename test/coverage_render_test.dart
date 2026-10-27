import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_flip/page_curl_flip.dart';
// Internal API: the capture helper and the read marker's renderer are not
// exported, and these tests pin their render-level behaviour directly.
import 'package:page_curl_flip/src/capture.dart';
import 'package:page_curl_flip/src/marked_text.dart';

/// A solid-colour bitmap built synchronously, for texturing the curl.
ui.Image _solidImage(Color color, {int width = 40, int height = 40}) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  return image;
}

/// The first [CustomPaint] whose painter is the read marker's band painter.
CustomPaint _bandPaint(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .firstWhere((p) => '${p.painter.runtimeType}' == '_MarkerBandPainter');

/// The bands the band painter was handed, read through its public field.
List<Object> _bandsOf(CustomPaint paint) =>
    // The painter class is private; its `bands` field is not.
    // ignore: avoid_dynamic_calls
    ((paint.painter as dynamic).bands as List<dynamic>).cast<Object>();

/// The current curl progress of the single [CurlOverlay] on screen.
double _curlProgress(WidgetTester tester) =>
    tester.widget<CurlOverlay>(find.byType(CurlOverlay)).progress;

/// A home screen whose button pushes a [PageCurlRoute] with a cover.
Widget _routeApp(GlobalKey<NavigatorState> navKey) => MaterialApp(
      navigatorKey: navKey,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            PageCurlRoute<void>(
              coverChild: const ColoredBox(
                color: Colors.white,
                child: Center(child: Text('cover')),
              ),
              builder: (_) => const Text('destination'),
            ),
          ),
          child: const Text('go'),
        ),
      ),
    );

void main() {
  group('CurlOverlay backgroundImage', () {
    testWidgets('the background texture is drawn into the curl strips',
        (tester) async {
      final background = _solidImage(const Color(0xFF336699));
      addTearDown(background.dispose);

      await tester.pumpWidget(MaterialApp(
        home: CurlOverlay(progress: 0.25, backgroundImage: background),
      ));

      final overlay = tester.renderObject(find.byType(CurlOverlay));
      expect(overlay, paints..drawImageRect(image: background));
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a background no image is drawn', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CurlOverlay(progress: 0.25)),
      );

      final overlay = tester.renderObject(find.byType(CurlOverlay));
      expect(overlay, isNot(paints..drawImageRect()));
    });
  });

  group('PageCurlRoute with a cover', () {
    testWidgets('popping after the curl reverses it so the cover folds back',
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_routeApp(navKey));

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(_curlProgress(tester), 1.0);

      navKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final midReverse = _curlProgress(tester);
      expect(midReverse, greaterThan(0.0));
      expect(midReverse, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
      expect(find.text('destination'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('popping before the capture keeps the cover and never curls',
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_routeApp(navKey));

      final route = PageCurlRoute<void>(
        coverChild: const ColoredBox(
          color: Colors.white,
          child: Center(child: Text('cover')),
        ),
        builder: (_) => const Text('destination'),
      );
      unawaited(navKey.currentState!.push(route));
      await tester.pump(); // first frame: the route animation sits at 0

      // Pop on the next tick, inside the frame whose post-frame callback
      // captures the cover: the capture then finds the route reversing.
      // Popping at 0 would dismiss the route outright instead.
      final animation = route.animation!;
      void popOnFirstTick() {
        if (animation.value > 0) {
          animation.removeListener(popOnFirstTick);
          navKey.currentState!.pop();
        }
      }

      animation.addListener(popOnFirstTick);
      await tester.pump(const Duration(milliseconds: 100));
      expect(animation.status, AnimationStatus.reverse);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('cover'), findsOneWidget);
      expect(find.byType(CurlOverlay), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('capturePage', () {
    testWidgets('a failing capture is reported and returns null',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: const ColoredBox(color: Colors.white),
      ));

      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      final ui.Image? image;
      try {
        // A zero pixel ratio asks for a 0×0 bitmap, which the engine refuses.
        image = capturePage(key, pixelRatio: 0);
      } finally {
        FlutterError.onError = previous;
      }

      expect(image, isNull);
      expect(reported, hasLength(1));
      expect(reported.single.library, 'page_curl_flip');
      expect(
        reported.single.context.toString(),
        'while capturing a page bitmap',
      );
    });

    testWidgets('a healthy capture returns a bitmap of the boundary',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(Center(
        child: RepaintBoundary(
          key: key,
          child: const SizedBox(
            width: 30,
            height: 20,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ));

      final image = capturePage(key, pixelRatio: 2);
      addTearDown(() => image?.dispose());
      expect(image, isNotNull);
      expect(image!.width, 60);
      expect(image.height, 40);
    });
  });

  group('MarkedText rendering', () {
    const style = TextStyle(fontSize: 10, color: Color(0xFF000000));
    const markerColor = Color(0x5500FF00);

    Widget host(Widget child) => MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, child: child),
            ),
          ),
        );

    testWidgets('highlight style paints one band in the marker colour',
        (tester) async {
      await tester.pumpWidget(host(const MarkedText(
        text: 'Hello world again',
        style: style,
        marked: TextRange(start: 6, end: 11),
        markerColor: markerColor,
      )));

      final band = tester.renderObject(
        find.byWidget(_bandPaint(tester)),
      );
      expect(band, paints..rrect(color: markerColor));
      expect(_bandsOf(_bandPaint(tester)), hasLength(1));
    });

    testWidgets('a collapsed marked range paints no band', (tester) async {
      await tester.pumpWidget(host(const MarkedText(
        text: 'Hello world again',
        style: style,
        marked: TextRange(start: 6, end: 6),
        markerColor: markerColor,
      )));

      // No bands and no marking: the block is a plain Text.
      expect(
        find.byWidgetPredicate((w) =>
            w is CustomPaint &&
            '${w.painter.runtimeType}' == '_MarkerBandPainter'),
        findsNothing,
      );
    });

    testWidgets('runs that share a line merge into a single band',
        (tester) async {
      // Mixed directions break one line into several text runs.
      const text = 'abc אבג def דה ghi';
      await tester.pumpWidget(host(MarkedText(
        text: text,
        style: style,
        marked: const TextRange(start: 0, end: text.length),
        markerColor: markerColor,
      )));

      final band = tester.renderObject(find.byWidget(_bandPaint(tester)));
      expect(
        band,
        paints
          ..rrect(color: markerColor)
          ..everything((method, arguments) => method != #drawRRect),
      );
    });

    testWidgets('equal bands are equal and hash alike; colour tells them apart',
        (tester) async {
      Future<List<Object>> bandsFor(Color color) async {
        await tester.pumpWidget(host(MarkedText(
          key: ValueKey<Color>(color),
          text: 'Hello world again',
          style: style,
          marked: const TextRange(start: 0, end: 5),
          markerColor: color,
        )));
        return _bandsOf(_bandPaint(tester));
      }

      final first = await bandsFor(markerColor);
      final again = await bandsFor(markerColor);
      final other = await bandsFor(const Color(0x55FF0000));

      expect(identical(first.single, again.single), isFalse);
      expect(first.single, again.single);
      expect(first.single.hashCode, again.single.hashCode);
      expect(first.single, isNot(other.single));
    });

    testWidgets('autoFollow scrolls a marked sentence below the fold into view',
        (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final text = List<String>.generate(60, (i) => 'line$i').join('\n');
      final lastLine = text.lastIndexOf('line59');

      Widget page(TextRange? marked) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  controller: controller,
                  child: MarkedText(
                    text: text,
                    style: style,
                    marked: marked,
                    autoFollow: true,
                  ),
                ),
              ),
            ),
          );

      await tester.pumpWidget(page(null));
      expect(controller.offset, 0);

      await tester.pumpWidget(
        page(TextRange(start: lastLine, end: lastLine + 6)),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
      expect(controller.offset, controller.position.maxScrollExtent);
    });
  });
}
