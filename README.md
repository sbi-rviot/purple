# Founder Assistant — MVP (Flutter)

Playful, on-device-style assistant for a tech founder. **No actions — conversational reply only.**
Pipeline: **Whisper (ASR) → Liquid (cleanup) → Liquid (reply) → TTS**. Includes a fun review/XP loop where the assistant "evolves".

## Pages
- **Page 1 — Assistant**: Big name/Avatar, UP/DOWN toggle (start/stop listening), XP ring.
- **Page 2 — Review**: Voice vs. text, low-confidence underlines, Approve (+10 XP), Edit & Save (+15 XP), Add to Glossary (+5 XP).

> This MVP ships with **mock services** for Whisper & Liquid so you can run the UI immediately. See integration steps below to wire your real engines.

---

## Quick start

```bash
flutter pub get
flutter run
```

The mock ASR emits a final utterance every ~6 seconds while the assistant is **UP**. You can review them on Page 2 and see XP increase + avatar evolve.

---

## Integration Guide

### 1) Voice → Transcript (Whisper)
- Replace `AsrService.mock()` with a real implementation in `lib/src/services/asr_service.dart`.
- Options:
  - **whisper.cpp** via FFI/Platform Channels
  - **whisper.rn** or a native plugin
- Requirements:
  - Streaming or short-utterance decoding
  - Word timestamps + token logprobs (for low-confidence)
  - Local-only audio processing

**Suggested interface**

```dart
abstract class AsrService {
  Stream<AsrResult> start(); // emit partial & final
  Future<void> stop();
}
```

Emit `AsrResult(isFinal:true)` when you finalize a segment. Fill `lowConfidenceWords` from your logprobs. Set `needsReview` true when average confidence < threshold or new proper nouns are detected.

### 2) Transcript → Improved Transcript (Liquid)
- Replace `LiquidService.mock()` in `lib/src/services/liquid_service.dart` with Liquid SDK calls.
- Provide:
  - `raw` text
  - `lowConfidence` tokens
  - `glossary` (names/brands/acronyms)
  - `historyPairs` (previous corrections)

**Prompt sketch** (system):
```
You improve noisy transcripts from accented English into clear English.
Rules: fix mishearings, preserve intended meaning, keep named entities from GLOSSARY, do not invent facts.
If uncertain, keep the original token.
Return only the corrected sentence.
```

**User content**:
```
RAW: send ze email to marie about investors call
LOW_CONF: ["ze","investors","guillaume"]
GLOSSARY: ["Marie","MarseilleTech","Guillaume"]
HISTORY: [{"before":"investors call","after":"investors' call"}]
```

Expect a single-line improved sentence.

### 3) Improved Transcript → Response (Liquid)
- Use a compact conversational model locally.
- System prompt idea:
```
You are Nova, a warm, concise founder's right-hand assistant. 
Give practical answers in 1-2 sentences. 
Do NOT execute actions; just respond.
Tone: encouraging, professional, slightly playful.
```

**User content**: the improved transcript.

Return plain text (no tool calls).

### 4) Response → Voice (TTS)
- This MVP uses `flutter_tts`. For fully local/offline voices:
  - **Piper** (Rhasspy/Mimic3): great quality, low resource; integrate via platform channel or a plugin.
  - **Coqui XTTS**: higher quality; heavier.
- Swap `TtsService` to call your chosen on-device TTS binary/library.

---

## Review & XP (Human-in-the-loop)

- **When to ask for review**: avg token logprob below threshold OR ≥2 low-confidence tokens OR new proper noun not in glossary.
- **Rewards**: Approve (+10 XP), Edit & Save (+15 XP), Add to Glossary (+5 XP).
- **Levels**: Rookie (0–49), Skilled (50–119), Mentor (120+). Avatar glow color changes by level.

All corrections/glossary are stored locally (`ApplicationDocumentsDirectory`) in JSON files:
- `utterances.json`, `corrections.json`, `glossary.json`, `xp.json`

---

## Notes & Limits

- **Privacy**: This MVP stores data locally. Add encryption at rest if needed.
- **Audio**: The mock ASR does not record real audio. Wire Whisper for production.
- **Liquid**: Replace the mock with actual on-device Liquid SDK calls when available on your target platform.
- **No actions**: The assistant only replies; it does not send emails or schedule events in this MVP.

---

## File layout

```
lib/
  main.dart
  src/
    app_state.dart
    models.dart
    pages/
      status_page.dart
      review_page.dart
    services/
      asr_service.dart        # Whisper integration point (mock provided)
      liquid_service.dart     # Liquid integration point (mock provided)
      tts_service.dart        # TTS via flutter_tts (swap for Piper/Coqui)
    storage/
      local_store.dart        # JSON persistence
```

---

## Demo tips (hackathon)

1. Start on **Page 1**: Wake Nova ⇒ see avatar glow + XP ring.
2. Speak a few lines (or let the mock feed them).
3. Go to **Page 2**: Approve/Edit a couple of items ⇒ **level up** moment.
4. Show before/after transcript examples for accent phrases (“ze” → “the”).

Good luck & have fun building! ✨
