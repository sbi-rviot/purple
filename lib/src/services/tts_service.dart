import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    // Wait for speak() to finish
    await _tts.awaitSpeakCompletion(true);

    // Keep things simple & reliable on iOS: playback category + speaker.
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        <IosTextToSpeechAudioCategoryOptions>[
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        // Omit 'mode' param for plugin compatibility
      );
      print("[TTS] iOS audio category set to playback");
    } catch (_) {
      // Non-iOS or plugin doesn't expose this; safe to ignore
    }

    // Sensible defaults
    await _tts.setLanguage("en-US");
    // A common, reliable built-in voice on iOS simulators & devices
    try {
      await _tts.setVoice({"name": "Samantha", "locale": "en-US"});
      print("[TTS] Voice set to Samantha (en-US)");
    } catch (_) {
      // If not available, system default will be used
    }
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5); // slightly faster than before for audibility
    await _tts.setPitch(1.0);

    // Status hooks
    _tts.setStartHandler(() {
      _isSpeaking = true;
      print("[TTS] start");
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      print("[TTS] completion");
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
      print("[TTS] cancel");
    });
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      print("[TTS] error: $msg");
    });
  }

  Future<void> speak(String text) async {
    // Ensure no overlap
    await stop();

    // Small settle delay helps after category changes made elsewhere
    await Future<void>.delayed(const Duration(milliseconds: 100));

    _isSpeaking = true;
    print("[TTS] speak(len=${text.length})");
    await _tts.speak(text); // awaits due to awaitSpeakCompletion(true)
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      print("[TTS] stop (interrupt)");
    }
    _isSpeaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
