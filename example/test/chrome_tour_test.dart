import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_flip/page_curl_flip.dart';
import 'package:page_curl_flip_example/chrome_tour.dart';

void main() {
  testWidgets('KEY-01 KEY-02: the tour finds the footer bar and the × by key', (
    tester,
  ) async {
    late BuildContext root;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            root = context;
            return FlipBook(
              onClose: () {},
              pages: const FlipBookPages(
                items: [FlipBookPage(title: 'One', body: Text('page one'))],
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final rects = bookChromeRects(root);

    expect(rects, [
      tester.getRect(find.byKey(FlipBookKeys.footerBar)),
      tester.getRect(find.byKey(FlipBookKeys.closeIcon)),
    ]);
  });

  testWidgets('a tap anywhere closes the tour', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const SizedBox.expand(),
            ChromeTour(
              holes: const [Rect.fromLTWH(10, 10, 50, 20)],
              onDone: () => done++,
            ),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(200, 300));

    expect(done, 1);
  });
}
