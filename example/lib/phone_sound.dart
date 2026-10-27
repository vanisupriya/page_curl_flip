// The phone's silent mode and media volume, read by this example's own small
// platform code — the package itself reads nothing from the phone. Android
// reports both; iOS reports the volume only (it has no public API for the
// silent switch). The book is told through `FlipBookSound.silenced`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shared_pages.dart';

/// The channel the example's MainActivity.kt and AppDelegate.swift answer.
const kPhoneSoundChannel = MethodChannel('page_curl_flip_example/phone_sound');

/// One reading of the phone's sound state.
@immutable
class PhoneSound {
  const PhoneSound({this.silent = false, this.volumeOff = false});

  /// Silent or vibrate mode is on (Android only).
  final bool silent;

  /// The media volume is at zero.
  final bool volumeOff;

  @override
  bool operator ==(Object other) =>
      other is PhoneSound &&
      other.silent == silent &&
      other.volumeOff == volumeOff;

  @override
  int get hashCode => Object.hash(silent, volumeOff);
}

/// Reads [PhoneSound] from the platform; any failure reads as "sound on".
Future<PhoneSound> readPhoneSound() async {
  try {
    final answer = await kPhoneSoundChannel.invokeMapMethod<String, Object?>(
      'read',
    );
    return PhoneSound(
      silent: answer?['silent'] == true,
      volumeOff: answer?['volumeOff'] == true,
    );
  } on PlatformException {
    return const PhoneSound();
  } on MissingPluginException {
    return const PhoneSound();
  }
}

/// Keeps [phone] current while a book is open, and shows the notes an app
/// gives when the phone itself has the sound off.
mixin PhoneSoundWatch<T extends StatefulWidget> on State<T> {
  /// The latest reading; the book's speaker follows [PhoneSound.silent].
  PhoneSound phone = const PhoneSound();

  Timer? _poll;
  bool _volumeNoteShown = false;

  /// Reads now, then once a second, so the speaker follows the phone live.
  void startPhoneSoundWatch({Duration every = const Duration(seconds: 1)}) {
    unawaited(refreshPhoneSound());
    _poll = Timer.periodic(every, (_) => unawaited(refreshPhoneSound()));
  }

  /// Stops the reading; call it from `dispose`.
  void stopPhoneSoundWatch() => _poll?.cancel();

  /// Reads the phone once and redraws only when something changed.
  Future<void> refreshPhoneSound() async {
    final now = await readPhoneSound();
    if (mounted && now != phone) setState(() => phone = now);
  }

  /// Shows [text] in the book's own snack bar: pink on the teal footer, so
  /// it never blends into the bar.
  void showPhoneNote(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kPink,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          content: PhoneNote(text: text),
        ),
      );
  }

  /// Shows [text] once per open book, when the volume is at zero.
  void noteVolumeOnce(String text) {
    if (!phone.volumeOff || _volumeNoteShown) return;
    _volumeNoteShown = true;
    showPhoneNote(text);
  }
}

/// The words of a phone-sound note, beside a muted speaker, in the book's type.
class PhoneNote extends StatelessWidget {
  const PhoneNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.volume_off_rounded, color: kOnColour, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: kOnColour,
          ),
        ),
      ),
    ],
  );
}
