import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_flip/page_curl_flip.dart';

Widget _app({
  FlipBookHeader? header = const FlipBookHeader(),
  TextDirection direction = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: FlipBook(
          header: header,
          onClose: () {},
          pages: const FlipBookPages(items: [
            FlipBookPage(title: 'One', body: Text('page one')),
            FlipBookPage(title: 'Two', body: Text('page two')),
          ]),
        ),
      ),
    );

void main() {
  testWidgets(
      'KEY-01: footerBar marks the one bar that holds every footer control',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final bar = find.byKey(FlipBookKeys.footerBar);
    expect(bar, findsOneWidget);
    final controls = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.button == true),
    );
    expect(controls, findsWidgets);
    final barRect = tester.getRect(bar);
    for (final element in controls.evaluate()) {
      final box = element.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      expect(barRect.contains(rect.center), isTrue,
          reason: 'every control sits inside the bar');
    }
  });

  final closeCases = <String, Widget Function()>{
    'default': _app,
    'closeAtEnd': () => _app(header: const FlipBookHeader(closeAtEnd: true)),
    'RTL': () => _app(direction: TextDirection.rtl),
  };
  for (final entry in closeCases.entries) {
    testWidgets('KEY-02: closeIcon marks the header × icon (${entry.key})',
        (tester) async {
      await tester.pumpWidget(entry.value());
      await tester.pump();

      final close = find.byKey(FlipBookKeys.closeIcon);
      expect(close, findsOneWidget);
      expect(tester.widget<Icon>(close).icon, Icons.close);
    });
  }

  testWidgets('KEY-02: with header: null there is no × and no closeIcon key',
      (tester) async {
    await tester.pumpWidget(_app(header: null));
    await tester.pump();

    expect(find.byKey(FlipBookKeys.closeIcon), findsNothing);
    expect(find.byKey(FlipBookKeys.footerBar), findsOneWidget,
        reason: 'the footer is untouched (CHR-05)');
  });
}
