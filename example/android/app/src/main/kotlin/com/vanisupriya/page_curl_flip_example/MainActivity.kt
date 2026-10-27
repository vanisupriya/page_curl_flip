package com.vanisupriya.page_curl_flip_example

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The example's host; also answers "read" on the phone-sound channel: silent or vibrate mode, and a zero media
 *  volume. The package reads nothing from the phone; this is the app's job. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val audio = getSystemService(AUDIO_SERVICE) as? AudioManager
            result.success(
                mapOf(
                    "silent" to (audio?.ringerMode?.let { it != AudioManager.RINGER_MODE_NORMAL } ?: false),
                    "volumeOff" to (audio?.getStreamVolume(AudioManager.STREAM_MUSIC) == 0),
                )
            )
        }
    }

    private companion object {
        const val CHANNEL = "page_curl_flip_example/phone_sound"
    }
}
