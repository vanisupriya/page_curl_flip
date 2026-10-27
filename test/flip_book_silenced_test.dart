// The speaker while the sound is off outside the book (FlipBookSound.silenced).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_flip/page_curl_flip.dart';

Widget _book(
    {required bool silenced,
    required Future<void> Function() onFlip,
    VoidCallback? onSilencedTap}) {
  return MaterialApp(
    home: FlipBook(
      onClose: () {},
      swipe: const FlipBookSwipe(hint: null),
      footer: FlipBookFooter(
        sound: FlipBookSound(
          onFlip: onFlip,
          silenced: silenced,
          onSilencedTap: onSilencedTap,
          silencedLabel: 'Phone is silent',
        ),
      ),
      pages: FlipBookPages(items: const [
        FlipBookPage(title: 'One', body: Text('page one')),
        FlipBookPage(title: 'Two', body: Text('page two')),
        FlipBookPage(title: 'Three', body: Text('page three')),
      ]),
    ),
  );
}

Finder _control(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
      description: 'control "$label"',
    );

Future<void> _flipNext(WidgetTester tester) async {
  await tester.tap(_control('NEXT'));
  await tester.pump();
  await tester
      .pump(FlipSpeed.medium.duration + const Duration(milliseconds: 100));
  await tester.pump();
}

void main() {
  testWidgets(
      'SND-08: silenced: the speaker shows muted with its own label, and a flip plays nothing',
      (tester) async {
    var flips = 0;
    await tester.pumpWidget(_book(silenced: true, onFlip: () async => flips++));
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsNothing);
    expect(_control('Phone is silent'), findsOneWidget);
    await _flipNext(tester);
    expect(flips, 0);
  });

  testWidgets(
      'SND-09: silenced: a tap calls onSilencedTap and keeps the book\'s own mute',
      (tester) async {
    var taps = 0;
    var flips = 0;
    await tester.pumpWidget(_book(
        silenced: true,
        onFlip: () async => flips++,
        onSilencedTap: () => taps++));
    await tester.tap(_control('Phone is silent'));
    await tester.pump();
    expect(taps, 1);

    await tester.pumpWidget(_book(
        silenced: false,
        onFlip: () async => flips++,
        onSilencedTap: () => taps++));
    await tester.pump();
    expect(find.byIcon(Icons.volume_up), findsOneWidget,
        reason: 'the tap while silenced did not mute the book');
    await _flipNext(tester);
    expect(flips, 1);
  });

  testWidgets(
      'SND-09: silenced without onSilencedTap: a tap does nothing and throws nothing',
      (tester) async {
    await tester.pumpWidget(_book(silenced: true, onFlip: () async {}));
    await tester.tap(_control('Phone is silent'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
  });

  testWidgets(
      'SND-10: not silenced: unchanged — the speaker is on and a flip plays',
      (tester) async {
    var flips = 0;
    await tester
        .pumpWidget(_book(silenced: false, onFlip: () async => flips++));
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(_control('Mute flip sound'), findsOneWidget);
    await _flipNext(tester);
    expect(flips, 1);
  });
}
