/// Speaking one reading unit, at a speed the reader may change halfway.
///
/// # Why this exists
///
/// **Neither Android TTS nor iOS can change the rate of an utterance that is
/// already being spoken.** `setSpeechRate` applies to the *next* thing you
/// speak. The book hands the engine one unit at a time, so "the next thing"
/// used to mean "the next paragraph" — and in a long paragraph a reader taps
/// a speed button and nothing happens for half a minute. Correct, and it
/// feels broken.
///
/// The only lever is to stop and speak again. This loop does that at the
/// **last word boundary the engine reported**, so the reader hears a short
/// seam and then the same sentence carrying on faster or slower, rather than
/// the paragraph starting over.
///
/// The book never sees any of it: one `onRead` call, one future, completed
/// when the unit is genuinely finished. The read marker does not move.
///
/// # The engine that never says it stopped
///
/// On iOS (flutter_tts 4.2.5) a stopped utterance never completes its speak
/// future — only a finished one does. So the loop does not wait for the
/// engine to confirm a stop: a speed change or an abort ends the wait itself.
///
/// # The engine that cannot keep up
///
/// Some engines report no word progress at all (certain Samsung builds).
/// There the boundary stays where the last restart put it, so a speed change
/// repeats from there — the same honest fallback pause/resume already has.
library;

import 'dart:async';

/// The bit of a speech engine this loop needs. Keeping it to these few calls is
/// what lets a test drive the loop without a real engine — the behaviour
/// below is otherwise unobservable until you are holding a phone.
abstract class SpeechEngine {
  /// Applies the rate to whatever is spoken next.
  Future<void> setRate(double rate);

  /// Speaks [text] and completes when the engine stops — whether it
  /// finished, or something called [stop].
  Future<void> speak(String text);

  /// Interrupts the current utterance.
  Future<void> stop();

  /// Where the last reported word ENDS, as an offset into the text handed to
  /// [speak]. Zero when the engine reports no progress.
  int get wordEnd;
}

/// Speaks one unit, restarting at the last word boundary whenever the rate
/// changes underneath it.
class ReadLoop {
  /// Drives [engine]; one loop per reader, reused for every unit.
  ReadLoop(this.engine);

  /// The engine being driven.
  final SpeechEngine engine;

  double _rate = 1;
  bool _speaking = false;
  bool _rateChanged = false;
  bool _aborted = false;

  /// Ends the wait for the utterance in flight, for engines whose stop never
  /// completes it. One per utterance.
  Completer<void>? _interrupt;

  /// Whether a unit is being spoken right now.
  bool get speaking => _speaking;

  /// Where the next utterance would start from — an offset into the current
  /// unit. Exposed for tests and for a reader that wants to show progress.
  int get offset => _base;
  int _base = 0;

  /// Speaks [text], and does not complete until the whole of it has been
  /// spoken — however many times the rate changed on the way.
  Future<void> read(String text, {required double rate}) async {
    _rate = rate;
    _base = 0;
    _aborted = false;
    _speaking = true;
    try {
      while (true) {
        await engine.setRate(_rate);
        _rateChanged = false;
        final interrupt = _interrupt = Completer<void>();
        await Future.any([
          engine.speak(text.substring(_base.clamp(0, text.length))),
          interrupt.future,
        ]);
        _interrupt = null;
        if (_aborted) {
          return;
        }
        if (!_rateChanged) {
          return; // Finished on its own.
        }
        // Carry on from the word AFTER the one being spoken — never from the
        // top, and never saying that word twice. `wordEnd` is relative to
        // what was last spoken, so it has to be added to where that started.
        final next = _base + engine.wordEnd;
        if (next <= _base || next >= text.length) {
          // No usable progress, or the boundary is at the very end. Either
          // way, repeating the remainder is the only honest option.
          if (next >= text.length) {
            return;
          }
        }
        _base = next.clamp(0, text.length);
      }
    } finally {
      _speaking = false;
    }
  }

  /// Applies a new rate. Takes effect at the **next word** when a unit is
  /// being spoken, and simply waits for the next unit when it is not.
  Future<void> setRate(double rate) async {
    _rate = rate;
    if (!_speaking) {
      return;
    }
    _rateChanged = true;
    await _stopUtterance();
  }

  /// Abandons the unit: the reader paused, stopped, or turned the page.
  /// The pending [read] completes without speaking anything more.
  Future<void> abort() async {
    if (!_speaking) {
      return;
    }
    _aborted = true;
    await _stopUtterance();
  }

  /// Stops the utterance in flight and ends the wait for it — whether or not
  /// the engine completes a stopped speak. Only that utterance's wait: the
  /// next one, already started by an engine that did complete, is left alone.
  Future<void> _stopUtterance() async {
    final interrupt = _interrupt;
    await engine.stop();
    if (interrupt != null && !interrupt.isCompleted) {
      interrupt.complete();
    }
  }
}
