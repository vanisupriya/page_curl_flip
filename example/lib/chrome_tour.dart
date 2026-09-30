// A one-screen tour of the book's chrome — the footer bar and the × — found
// through FlipBookKeys. A coach mark, an onboarding hint and an integration
// test all need the same thing: where is that control right now?
//
// Find it by KEY, never by class name. `flutter build --obfuscate` renames
// every class, so a search by `runtimeType.toString()` works in debug and
// finds nothing in the store build. A key survives.

import 'package:flutter/material.dart';
import 'package:page_curl_flip/page_curl_flip.dart';

import 'shared_pages.dart';

/// The on-screen rect of the first rendered widget carrying [key] below
/// [context], or null when nothing with that key is on screen.
Rect? rectOfKey(BuildContext context, Key key) {
  Rect? found;
  void visit(Element element) {
    if (found != null) return;
    final box = element.renderObject;
    if (element.widget.key == key &&
        box is RenderBox &&
        box.hasSize &&
        box.attached) {
      found = box.localToGlobal(Offset.zero) & box.size;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  return found;
}

/// The footer bar and the × of every book below [context], in that order;
/// a control that is not on screen is simply left out.
List<Rect> bookChromeRects(BuildContext context) => [
  for (final key in const [FlipBookKeys.footerBar, FlipBookKeys.closeIcon])
    if (rectOfKey(context, key) case final rect?) rect,
];

/// Dims the book and outlines each of [holes]; any tap dismisses it.
class ChromeTour extends StatelessWidget {
  const ChromeTour({super.key, required this.holes, required this.onDone});

  final List<Rect> holes;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDone,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0x99000000))),
            for (final hole in holes)
              Positioned.fromRect(
                rect: hole.inflate(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: kPink, width: 3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Found with FlipBookKeys — still found in an obfuscated '
                  'release build.\n\nTap anywhere to close.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kOnColour,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
