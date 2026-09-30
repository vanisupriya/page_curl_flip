// The app's voice: the device text-to-speech engine, shaped for FlipBook's
// callbacks.

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:page_curl_flip/page_curl_flip.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'read_loop.dart';

/// A small wrapper around the device's text-to-speech engine, shaped for
/// FlipBook's callbacks: read() completes when speech ends, pause()/resume()
/// continue from the interrupted word, stop() halts immediately.
/// `flutter_tts` narrowed to the four calls [ReadLoop] needs.
class TtsEngine implements SpeechEngine {
  TtsEngine(this._reader);

  final Reader _reader;

  @override
  int get wordEnd => _reader._utteranceEnd;

  @override
  Future<void> setRate(double rate) => _reader._tts.setSpeechRate(rate);

  @override
  Future<void> speak(String text) {
    _reader._utteranceEnd = 0;
    return _reader._tts.speak(text);
  }

  @override
  Future<void> stop() => _reader._tts.stop();
}

class Reader with WidgetsBindingObserver {
  Reader() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _tts = FlutterTts();
  late final _loop = ReadLoop(TtsEngine(this));
  bool _configured = false;
  String _text = '';
  String _language = 'en-US';
  int _position = 0;
  int _base = 0;
  int _utteranceEnd = 0;
  double _rate = 0.5;

  // iOS and Android do not share a speech-rate scale. flutter_tts passes the
  // number straight to AVSpeechSynthesizer on iOS and to Android's
  // TextToSpeech engine, and the same value lands in a different place on
  // each — so the pace the reader picked has to be mapped per platform, by
  // ear, against the labels on the pill.
  static const double _iosFast = 0.63;

  /// The absolute rate to hand the engine for a chosen speed.
  static double _rateFor(FlipBookReadSpeed speed) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      // Android's scale already matches the labels, so it is left alone.
      return 0.5 * speed.rateFactor;
    }
    return switch (speed) {
      // 0.40 was inaudibly close to 0.50 — the reader heard no difference
      // at all. AVSpeechSynthesizer bunches its
      // useful range near the middle, so a slow step has to travel further.
      FlipBookReadSpeed.slow => 0.30,
      FlipBookReadSpeed.normal => 0.50,
      FlipBookReadSpeed.fast => _iosFast,
    };
  }

  /// The engine's speak future also completes when pause/stop kill it —
  /// only the session that finishes NATURALLY may release the wakelock,
  /// otherwise a pause would drop the lock mid-listen.
  int _session = 0;

  Future<void> _configure() async {
    if (_configured) {
      return;
    }
    await _tts.awaitSpeakCompletion(true);
    // Remember how far the voice has come, for pause/resume.
    _tts.setProgressHandler((text, start, end, word) {
      // Two offsets, deliberately: `_position` is absolute in the unit and
      // survives a pause; `_utteranceEnd` is relative to what was last
      // handed to speak(), which is what the loop needs to go on from the
      // next word after a speed change.
      _utteranceEnd = end;
      _position = _base + start;
      // Re-assert the screen wakelock on every word — self-healing if a
      // platform quietly dropped it (seen on iOS mid-play-all).
      _screenAwake(true);
    });
    _configured = true;
  }

  Future<bool> isAvailable(String language) async =>
      await _tts.isLanguageAvailable(language) == true;

  /// Read-aloud is a deliberate listen — like any audio player it must
  /// sound even with the iPhone silent switch on, so it asserts the
  /// `playback` category before every speak. (The flip sound asserts
  /// `ambient` before every play for the opposite reason: the iOS audio
  /// session is one shared object, and whoever spoke last set its mode.)
  Future<void> _assertAudioCategory() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,
    ]);
  }

  /// Best-effort screen wakelock: a long listen (play-all) must not die to
  /// the screen timeout — reading stops on background by design, so the
  /// screen staying on is what keeps the voice alive. Failures are
  /// swallowed; the lock must never break reading.
  void _screenAwake(bool on) {
    unawaited(
      (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {}),
    );
  }

  /// One sentence per call — the book chains them back-to-back. No
  /// _tts.stop() here: a stop() fired between two chained sentences races
  /// the engine right after a completion and can drop the next utterance —
  /// whose future then never completes, freezing the chain. The book
  /// guarantees the previous sentence is done before it calls again, and
  /// user-initiated stops arrive through stop()/pause() below.
  Future<void> read(
    String text,
    String language,
    FlipBookReadSpeed speed,
  ) async {
    await _configure();
    await _assertAudioCategory();
    // The package reports the reader's choice; applying it to the engine is
    // the app's job. 0.5 is flutter_tts's own "normal" on both platforms.
    _rate = _rateFor(speed);
    final session = ++_session;
    _text = text;
    _language = language;
    _base = 0;
    _position = 0;
    _screenAwake(true);
    await _tts.setLanguage(language);
    // Through the loop, not straight at the engine. A speed change while
    // this unit is speaking stops it and resumes at the last word — and the
    // future below still does not complete until the whole unit is done, so
    // the book sees one continuous unit and the read marker never moves.
    await _loop.read(text, rate: _rate);
    if (session == _session) {
      _screenAwake(false);
    }
  }

  /// The reader picked a new pace. Applies at the next word when the voice
  /// is mid-unit; otherwise it simply waits for the next unit.
  Future<void> setSpeed(FlipBookReadSpeed speed) {
    _rate = _rateFor(speed);
    return _loop.setRate(_rate);
  }

  /// Android's engine has no native pause — stopping while remembering the
  /// word works on every platform.
  Future<void> pause() async {
    _session++; // The dying speak future must not release the lock early.
    _screenAwake(false);
    // abort() rather than a bare stop: the loop must know this was the
    // reader's doing, or it would treat the silence as a speed change and
    // carry on speaking.
    await _loop.abort();
    await _tts.stop();
  }

  Future<void> resume() async {
    await _assertAudioCategory();
    final session = ++_session;
    _screenAwake(true);
    _base = _position;
    await _tts.setLanguage(_language);
    await _loop.read(
      _text.substring(_position.clamp(0, _text.length)),
      rate: _rate,
    );
    if (session == _session) {
      _screenAwake(false);
    }
  }

  Future<void> stop() async {
    _session++;
    _screenAwake(false);
    await _loop.abort();
    await _tts.stop();
  }

  /// Android keeps the TTS engine speaking after the app is backgrounded
  /// (iOS suspends it with the app). A book has no business reading to a
  /// closed cover — stop the voice when the app leaves the foreground.
  /// The speak future completes on stop, so the book's ▶ control resets
  /// by its normal completion path.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      stop(); // Bumps the session too — no stale "done" reports.
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session++;
    _screenAwake(false);
    _tts.stop();
  }
}
