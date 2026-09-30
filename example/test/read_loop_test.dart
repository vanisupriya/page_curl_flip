import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_flip_example/read_loop.dart';

/// A stand-in engine that records what it was asked to say.
///
/// Every assertion below is about behaviour you cannot see without a phone
/// in your hand and a stopwatch, which is exactly why it is faked here.
class _FakeEngine implements SpeechEngine {
  final spoken = <String>[];
  final rates = <double>[];

  /// Word boundaries the engine will report, one per utterance.
  final List<int> boundaries;

  /// Where each reported word ENDS, one per utterance; defaults to
  /// [boundaries] when a test does not care about the difference.
  final List<int>? ends;

  /// Whether [stop] completes the utterance in flight. Android's engine does;
  /// iOS's (flutter_tts 4.2.5, `didCancel`) never completes a stopped speak.
  final bool stopCompletesSpeak;

  /// Whether [stop] returns only after a turn of the event loop, as a real
  /// platform call does — long enough for the loop to start the next speak.
  final bool slowStop;

  _FakeEngine({
    this.boundaries = const [],
    this.ends,
    this.stopCompletesSpeak = true,
    this.slowStop = false,
  });

  int _utterance = 0;
  Completer<void>? _current;

  @override
  int get wordEnd {
    final list = ends ?? boundaries;
    return _utterance - 1 < list.length && _utterance > 0
        ? list[_utterance - 1]
        : 0;
  }

  @override
  Future<void> setRate(double rate) async => rates.add(rate);

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    _utterance++;
    return (_current = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    if (stopCompletesSpeak) {
      finish();
    } else {
      _current = null;
    }
    if (slowStop) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Completes the utterance in flight, as a real engine does when it
  /// reaches the end or is stopped.
  void finish() {
    final c = _current;
    _current = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }
}

void main() {
  const unit = 'The quick brown fox jumps over the lazy dog and keeps going.';

  test(
    'SPD-06: with no speed change, the unit is spoken once, whole',
    () async {
      final engine = _FakeEngine();
      final loop = ReadLoop(engine);

      final done = loop.read(unit, rate: 1);
      await Future<void>.delayed(Duration.zero);
      engine.finish();
      await done;

      expect(engine.spoken, [unit]);
      expect(engine.rates, [1.0]);
      expect(loop.speaking, isFalse);
    },
  );

  test('SPD-07: a speed change carries on from the next WORD, not from the '
      'start of the paragraph', () async {
    // The engine reports it had reached character 20 — inside the unit.
    final engine = _FakeEngine(boundaries: [20]);
    final loop = ReadLoop(engine);

    final done = loop.read(unit, rate: 1);
    await Future<void>.delayed(Duration.zero);

    // The reader taps a faster speed mid-paragraph.
    await loop.setRate(1.5);
    await Future<void>.delayed(Duration.zero);
    engine.finish();
    await done;

    expect(engine.spoken.length, 2, reason: 'stopped and spoke again');
    expect(engine.spoken.first, unit);
    // The whole point: the remainder, not the paragraph over again.
    expect(engine.spoken[1], unit.substring(20));
    expect(engine.rates, [1.0, 1.5], reason: 'the new rate was applied');
    // And the book sees ONE unit: the future only completes at the end.
    expect(loop.speaking, isFalse);
  });

  test('SPD-08: an engine that reports no word progress repeats the '
      'remainder instead of hanging', () async {
    // boundaries empty → wordEnd is always 0, the Samsung case.
    final engine = _FakeEngine();
    final loop = ReadLoop(engine);

    final done = loop.read(unit, rate: 1);
    await Future<void>.delayed(Duration.zero);
    await loop.setRate(0.5);
    await Future<void>.delayed(Duration.zero);
    engine.finish();
    await done;

    expect(engine.spoken, [
      unit,
      unit,
    ], reason: 'no progress to resume from, so the unit repeats');
    expect(engine.rates, [1.0, 0.5]);
  });

  test('SPD-09: pause or a page flip abandons the unit without speaking '
      'again', () async {
    final engine = _FakeEngine(boundaries: [20]);
    final loop = ReadLoop(engine);

    final done = loop.read(unit, rate: 1);
    await Future<void>.delayed(Duration.zero);
    await loop.abort();
    await done;

    expect(engine.spoken, [unit], reason: 'nothing more was spoken');
    expect(loop.speaking, isFalse);
  });

  test(
    'SPD-10: changing speed while nothing is being read just sets it',
    () async {
      final engine = _FakeEngine();
      final loop = ReadLoop(engine);

      await loop.setRate(1.5);
      expect(engine.spoken, isEmpty, reason: 'nothing to interrupt');

      final done = loop.read(unit, rate: 1.5);
      await Future<void>.delayed(Duration.zero);
      engine.finish();
      await done;
      expect(engine.rates, [1.5]);
    },
  );

  test('SPD-11: on iOS, where a stopped speak never completes, a speed '
      'change still carries on at the new rate', () async {
    final engine = _FakeEngine(boundaries: [20], stopCompletesSpeak: false);
    final loop = ReadLoop(engine);

    final done = loop.read(unit, rate: 1);
    await Future<void>.delayed(Duration.zero);

    await loop.setRate(1.5);
    await Future<void>.delayed(Duration.zero);

    expect(engine.spoken, [
      unit,
      unit.substring(20),
    ], reason: 'spoke on without waiting for the stopped utterance');
    expect(engine.rates, [1.0, 1.5]);

    engine.finish();
    await done;
    expect(loop.speaking, isFalse);
  });

  test('SPD-12: on iOS, pause or stop still ends the unit', () async {
    final engine = _FakeEngine(stopCompletesSpeak: false);
    final loop = ReadLoop(engine);

    final done = loop.read(unit, rate: 1);
    await Future<void>.delayed(Duration.zero);
    await loop.abort();

    await expectLater(done.timeout(const Duration(seconds: 1)), completes);
    expect(engine.spoken, [unit]);
    expect(loop.speaking, isFalse);
  });

  test('an Android engine that completes on stop is not cut short on the '
      'next utterance', () async {
    final engine = _FakeEngine(boundaries: [20], slowStop: true);
    final loop = ReadLoop(engine);

    final done = loop.read(unit, rate: 1);
    await Future<void>.delayed(Duration.zero);
    await loop.setRate(1.5);
    await Future<void>.delayed(Duration.zero);

    var finished = false;
    unawaited(done.then((_) => finished = true));
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse, reason: 'the second utterance is still speaking');

    engine.finish();
    await done;
    expect(engine.spoken, [unit, unit.substring(20)]);
  });

  test('SPD-13: a speed change goes on from the NEXT word — the word being '
      'spoken is not said again', () async {
    // "fox" was being spoken: it starts at 16 and ends at 19.
    final engine = _FakeEngine(boundaries: [16], ends: [19]);
    final loop = ReadLoop(engine);

    final done = loop.read(unit, rate: 1);
    await Future<void>.delayed(Duration.zero);
    await loop.setRate(1.5);
    await Future<void>.delayed(Duration.zero);
    engine.finish();
    await done;

    expect(engine.spoken[1], unit.substring(19));
    expect(
      engine.spoken[1].trimLeft(),
      startsWith('jumps'),
      reason: '"fox" is not repeated',
    );
  });
}
