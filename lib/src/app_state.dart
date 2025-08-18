// lib/src/app_state.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'services/asr_service.dart';
import 'services/liquid_service.dart';
import 'services/tts_service.dart';
import 'storage/local_store.dart';
import 'assistant_profiles.dart';

enum Phase { listening, thinking, speaking }

// Minimal XP shim (if your repo lacks Xp)
class SimpleXp {
  int totalXp;
  SimpleXp([this.totalXp = 0]);
  Level get level {
    if (totalXp >= 120) return Level.mentor;
    if (totalXp >= 50) return Level.skilled;
    return Level.rookie;
  }
  void add(int x) => totalXp  = x;
}

class AppState extends ChangeNotifier {
  // --- Tunables -------------------------------------------------------------
  static const Duration silenceTimeout = Duration(seconds: 2);
  static const Duration kPostTtsIgnore = Duration(milliseconds: 1200);

  // --- Persona / profile ----------------------------------------------------
  final List<AssistantProfile> profiles = kAssistantProfiles;
  AssistantProfile profile = kAssistantProfiles.first;
  String get assistantName => profile.name;
  Color get themeSeedColor => profile.color;
  String get assistantDescription => profile.description;
  String get systemPrompt => profile.systemPrompt;

  void setProfile(AssistantProfile p) {
    if (profile.key == p.key) return;
    profile = p;
    notifyListeners();
  }

  // --- Persistence / UX -----------------------------------------------------
  final LocalStore _store = LocalStore();
  final ValueNotifier<bool> busy = ValueNotifier(false);

  final SimpleXp xp = SimpleXp();
  final List<String> glossary = [];
  final List<Utterance> utterances = [];

  // --- Services -------------------------------------------------------------
  late AsrService _asr;
  final TtsService _tts = TtsService();
  late final LiquidService _liquid;

  // --- Streaming / phases ---------------------------------------------------
  StreamSubscription<AsrResult>? _sub;
  Timer? _silenceTimer;
  String _currentTranscript = "";

  Phase _phase = Phase.listening;
  bool _isProcessing = false;

  // Echo gate
  bool _ttsActive = false;
  DateTime _ignoreAsrUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Hard freeze while speaking/post-TTS
  bool _listeningFrozen = false;

  // App on/off (Start/Stop)
  bool isUp = false;

  // Token to invalidate stale callbacks / timers / streams
  int _attachToken = 0;

   // --- ASR attach health tracking ------------------------------------------
   bool _sawAsrForToken = false;
   int _reattachAttemptsForToken = 0; // only one recovery try for dead streams
   DateTime _lastAttachAt = DateTime.fromMillisecondsSinceEpoch(0);
 
   void _rebuildAsrInstance() {
     _asr = AsrService.impl();
     print("[ASR] rebuilt instance ${_asr.hashCode}");
   }

  // Timers that may schedule listening
  Timer? _unfreezeTimer;   // after post-TTS gate
  Timer? _gateDelayTimer;  // if Start happens during gate

  // ---------- Lifecycle -----------------------------------------------------
  Future<void> init() async {
    await _store.init();
    xp.totalXp = await _store.loadXp();
    glossary.addAll(await _store.loadGlossary());
    utterances.addAll(await _store.loadUtterances());

    profile = profiles.firstWhere((p) => p.key == 'company', orElse: () => profiles.first);

    _rebuildAsrInstance();
    _liquid = LiquidService();  // default ctor in your repo
    await _tts.init();

    busy.value = false;
    print("[AppState] init complete. Ready.");
    notifyListeners();
  }

  void toggleUpDown() {
    final next = !isUp;
    isUp = next;
    if (next) {
      _enterListening();
    } else {
      _stopAll();
    }
    notifyListeners();
  }

  Phase get phase => _phase;
  String get currentTranscript => _currentTranscript;

  // ---------- Phase helpers -------------------------------------------------
  void _attachAsrIfNeeded({required int token}) {
    // Absolute guards — never attach when down, not listening, or frozen/gated.
    final now = DateTime.now();
    final gated = now.isBefore(_ignoreAsrUntil);
    if (!isUp || _phase != Phase.listening || _listeningFrozen || gated) {
      print("[ASR] attach skipped (isUp=$isUp phase=$_phase frozen=$_listeningFrozen gate=$gated)");
      return;
    }
    if (_sub != null) return;

    final myToken = token;
    print("[ASR] attach (enterListening) token=$myToken");

    // Reset health markers for this attachment
     _sawAsrForToken = false;
     _reattachAttemptsForToken = 0;
     _lastAttachAt = DateTime.now();
 
    void handleEndOrError({required bool fromError, Object? error}) {
       if (myToken != _attachToken) return; // stale callback
       _sub = null;
       final now = DateTime.now();
       final gatedNow = now.isBefore(_ignoreAsrUntil);
       final canListen = isUp && _phase == Phase.listening && !_listeningFrozen && !gatedNow;
 
       // "Dead stream" heuristic: ended instantly or produced no events.
       final attachedFor = now.difference(_lastAttachAt);
       final dead = !_sawAsrForToken || attachedFor < const Duration(milliseconds: 80);
 
       if (!canListen) {
         print("[ASR] on${fromError ? "Error" : "Done"} — detach (canListen=false)");
         return;
       }
 
        if (dead) {
          if (_reattachAttemptsForToken == 0) {
            _reattachAttemptsForToken  ;
           print("[ASR] on${fromError ? "Error" : "Done"} — dead stream; rebuilding ASR then one retry...");
           _rebuildAsrInstance(); // new open controller
           // Small delay to avoid instant reentrancy against plugin init
           Future.delayed(const Duration(milliseconds: 200), () {
             if (myToken == _attachToken) _attachAsrIfNeeded(token: _attachToken);
           });
         } else {
           print("[ASR] on${fromError ? "Error" : "Done"} — dead stream x2; giving up (no reattach).");
         }
         return;
       }
 
       // Normal end while still listening: single resilience reattach
       print("[ASR] on${fromError ? "Error" : "Done"} — detached; reattaching once.");
       scheduleMicrotask(() => _attachAsrIfNeeded(token: _attachToken));
     }
 
     _sub = _asr.start().listen(
       (evt) {
         _sawAsrForToken = true;
         _onAsrEvent(evt);
       },
       onError: (e, st) => handleEndOrError(fromError: true, error: e),
       onDone: () => handleEndOrError(fromError: false),
       cancelOnError: true,
     );
  }

  void _enterListening() {
    _phase = Phase.listening;
    _isProcessing = false;

    _silenceTimer?.cancel();
    _silenceTimer = null;
    _currentTranscript = "";

    final now = DateTime.now();
    final gated = now.isBefore(_ignoreAsrUntil);

    // If frozen or gated, don't attach now.
    if (_listeningFrozen || _ttsActive || gated) {
      final ms = gated ? _ignoreAsrUntil.difference(now).inMilliseconds : 0;
      print("[Phase] → LISTENING (frozen=$_listeningFrozen tts=$_ttsActive gateMs=$ms) — no ASR attach");

      // If Start happened during the gate and we aren't frozen, retry after gate.
      _gateDelayTimer?.cancel();
      if (isUp && !_listeningFrozen && gated) {
        final captured = _attachToken; // bind timer to token
        _gateDelayTimer = Timer(Duration(milliseconds: ms), () {
          if (!isUp || captured != _attachToken || _listeningFrozen) return;
          _enterListening(); // will call attach with the same (still valid) token
        });
      }
      return;
    }

    final captured = _attachToken;
    _attachAsrIfNeeded(token: captured);
    print("[Phase] → LISTENING (ASR on) — stream running");
  }

  Future<void> _enterThinking(String transcript, AsrResult asr) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _phase = Phase.thinking;

    _silenceTimer?.cancel();
    _silenceTimer = null;

    print("[Phase] → THINKING | text=\"${_truncate(transcript, 120)}\"");

    final conversationSummary = _summarizeConversation();
    final prompt = systemPrompt;

    try {
      final reply = await _liquid.generateReply(
        "$prompt\n\nContext summary:\n$conversationSummary",
        transcript,
      );

      utterances.insert(
        0,
        Utterance(
          id: const Uuid().v4(),
          createdAt: DateTime.now(),
          audioPath: asr.audioPath,
          rawText: transcript,
          improvedText: transcript,
          lowConfidence: asr.lowConfidenceWords,
          needsReview: asr.needsReview,
          responseText: reply,
        ),
      );
      await _store.saveUtterances(utterances);
      notifyListeners();

      await _enterSpeaking(reply);
    } catch (e, st) {
      print("[AppState] Liquid error: $e\n$st");
      _isProcessing = false;
      if (isUp) _enterListening();
    }
  }

  Future<void> _enterSpeaking(String reply) async {
    _phase = Phase.speaking;

    _silenceTimer?.cancel();
    _silenceTimer = null;

    // Freeze listening immediately so nothing can attach until unfreeze.
    _listeningFrozen = true;
    _ttsActive = true;

    print("[Phase] → SPEAKING | reply=${reply.length} chars");
    await _tts.speak(reply);

    // Start post-TTS ignore window and schedule token-bound unfreeze.
    _ignoreAsrUntil = DateTime.now().add(kPostTtsIgnore);
    _ttsActive = false;

    _isProcessing = false;
    _currentTranscript = "";

    _unfreezeTimer?.cancel();
    final captured = _attachToken; // bind timer to current session
    _unfreezeTimer = Timer(kPostTtsIgnore, () {
      if (!isUp || captured != _attachToken) return; // Stop/Start changed token
      _listeningFrozen = false; // unfreeze only if same session
      _enterListening();        // attach if allowed
    });

    print("[Phase] SPEAKING done — unfreeze after ${kPostTtsIgnore.inMilliseconds}ms");
  }

  Future<void> _stopAll() async {
    // Mark app down; nothing should attach after this.
    isUp = false;

    // Invalidate *before* cancelling to kill any already-queued callbacks.
    _attachToken    ;

    // Cancel timers (token-bound callbacks will also bail if they already queued).
    _unfreezeTimer?.cancel();   _unfreezeTimer = null;
    _gateDelayTimer?.cancel();  _gateDelayTimer = null;
    _silenceTimer?.cancel();    _silenceTimer = null;

    // Reset gates.
    _listeningFrozen = false;
    _ttsActive = false;
    _ignoreAsrUntil = DateTime.fromMillisecondsSinceEpoch(0);

    // Tear down ASR stream cleanly.
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
    await _asr.stop();
    _rebuildAsrInstance();

    // Stop TTS too.
    await _tts.stop();

    // Reset lightweight state.
    _phase = Phase.listening;
    _isProcessing = false;
    _currentTranscript = "";

    print("[Stop] hard refresh done (token=$_attachToken)");
  }

  // ---------- ASR handling --------------------------------------------------
  void _onAsrEvent(AsrResult asr) {
    final now = DateTime.now();

    // Swallow ALL ASR while speaking, frozen, or in post-TTS gate.
    if (!isUp ||
        _phase != Phase.listening ||
        _ttsActive ||
        _listeningFrozen ||
        now.isBefore(_ignoreAsrUntil)) {
      return; // no logs, no timers, no sends
    }

    _currentTranscript = asr.text;

    if (asr.isFinal) {
      _silenceTimer?.cancel();
      print("[ASR] FINAL '${_truncate(asr.text, 80)}' — schedule SEND now");
      _silenceTimer = Timer(Duration.zero, () {
        if (_phase != Phase.listening || _isProcessing) return;
        final toSend = _currentTranscript.trim();
        if (toSend.isEmpty) return;
        _ignoreAsrUntil = DateTime.fromMillisecondsSinceEpoch(0);
        print("[Timer] FINAL → send: \"${_truncate(toSend, 120)}\"");
        unawaited(_enterThinking(toSend, asr));
      });
      return;
    }

    // Non-final chunk: arm/reset silence timer
    _silenceTimer?.cancel();
    print("[ASR] '${_truncate(asr.text, 80)}' (final=${asr.isFinal}) — arm SilenceTimer=${silenceTimeout.inMilliseconds}ms");

    _silenceTimer = Timer(silenceTimeout, () {
      if (_phase != Phase.listening) return;
      if (_isProcessing) return;
      final toSend = _currentTranscript.trim();
      if (toSend.isEmpty) return;
      _ignoreAsrUntil = DateTime.fromMillisecondsSinceEpoch(0);
      print("[Timer] SilenceTimer FIRE → send: \"${_truncate(toSend, 120)}\"");
      unawaited(_enterThinking(toSend, asr));
    });
  }

  // ---------- Review actions ------------------------------------------------
  Future<void> approve(Utterance u) async {
    u.needsReview = false;
    xp.add(10);
    await _store.saveXp(xp.totalXp);
    await _store.saveUtterances(utterances);
    notifyListeners();
  }

  Future<void> editAndSave(Utterance u, String corrected) async {
    final before = u.improvedText;
    u.improvedText = corrected;
    u.needsReview = false;
    xp.add(15);
    await _store.addCorrection(CorrectionPair(before: before, after: corrected));
    await _store.saveXp(xp.totalXp);
    await _store.saveUtterances(utterances);
    notifyListeners();
  }

  Future<void> addToGlossary(String term) async {
    glossary.add(term);
    xp.add(5);
    await _store.saveGlossary(glossary.toSet()); // store expects a Set
    await _store.saveXp(xp.totalXp);
    notifyListeners();
  }

  Level get level => xp.level;

  // ---------- Summarization -------------------------------------------------
  String _summarizeConversation() {
    if (utterances.isEmpty) return "(none yet)";
    final buffer = StringBuffer();
    for (final u in utterances.take(5).toList().reversed) {
      buffer.writeln("User: ${u.improvedText}");
      buffer.writeln("Assistant: ${u.responseText}");
    }
    return buffer.toString();
  }

  // ---------- Utils ---------------------------------------------------------
   String _truncate(String s, int max) =>
       s.length <= max ? s : s.substring(0, max) + "…";
}

// Fire-and-forget helper
void unawaited(Future<void>? f) {}
