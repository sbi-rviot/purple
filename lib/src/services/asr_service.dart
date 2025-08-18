import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AsrResult {
  final String text;
  final bool isFinal;
  final List<String> lowConfidenceWords;
  final String? audioPath;
  final bool needsReview;
  AsrResult({
    required this.text,
    required this.isFinal,
    required this.lowConfidenceWords,
    required this.audioPath,
    required this.needsReview,
  });
}

abstract class AsrService {
  Stream<AsrResult> start();
  Future<void> stop();

  factory AsrService.impl() => _SpeechToTextService();
}

class _SpeechToTextService implements AsrService {
  final _stt = stt.SpeechToText();
  final _controller = StreamController<AsrResult>.broadcast();
  bool _listening = false;

  @override
  Stream<AsrResult> start() {
    _initAndListen();
    return _controller.stream;
  }

  Future<void> _initAndListen() async {
    final available = await _stt.initialize();
    if (!available) {
      _controller.add(AsrResult(
        text: '[Speech recognition not available]',
        isFinal: true,
        lowConfidenceWords: [],
        audioPath: null,
        needsReview: false,
      ));
      return;
    }

    _listening = true;
    _stt.listen(
      listenMode: stt.ListenMode.dictation,
      onResult: (res) {
        print('[ASR Raw] ${res.recognizedWords} '
              '(final: ${res.finalResult}, confidence: ${res.confidence})');
        if (!_listening) return;
        final words = res.recognizedWords.trim();
        final lowConf = <String>[];
        final conf = res.hasConfidenceRating ? res.confidence : null;
        if (conf != null && conf < 0.85) {
          lowConf.addAll(words.split(RegExp(r'\\s+')));
        }
        _controller.add(AsrResult(
          text: words,
          isFinal: res.finalResult,
          lowConfidenceWords: lowConf,
          audioPath: null,
          needsReview: true,
        ));
      },
      cancelOnError: true,
    );
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await _stt.stop();
    await _controller.close();
  }
}
