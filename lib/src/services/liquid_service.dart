import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

class LiquidService {
  LiquidService({
    this.maxTokens = 80,
    List<String>? stop,
    String? baseUrl,
    bool? forceSimulator,
  })  : stop = stop ?? kDefaultStops,
        _forceSimulator = forceSimulator,
        _overrideBaseUrl = baseUrl;

  final int maxTokens;
  final List<String> stop;

  final bool? _forceSimulator;
  final String? _overrideBaseUrl;

  // Conservative set of stop sequences to discourage chat logs
  static const List<String> kDefaultStops = <String>[
    "\nUser:",
    "\nAssistant:",
    "User:",
    "Assistant:",
    "<|im_start|>",
    "<|im_end|>",
  ];

  String get _baseUrl {
    if (_overrideBaseUrl != null) return _overrideBaseUrl!;
    final onSim = _forceSimulator ??
        (Platform.isIOS && Platform.environment.containsKey('SIMULATOR_UDID'));
    // Simulator -> host loopback
    return 'http://127.0.0.1:8080/v1/chat/completions';
    // Device -> replace with your Mac’s LAN IP if you run on device
    // return 'http://192.168.1.42:8080/v1/chat/completions';
  }

  Future<String> generateReply(String systemPrompt, String userMessage) async {
  final uri = Uri.parse(_baseUrl);
  print('[Liquid] POST $uri (max_tokens=$maxTokens)');

  final payload = {
    "model": "lfm2",
    "messages": [
      {
        "role": "system",
        "content":
            "$systemPrompt\nWrite plain prose. Do NOT prefix with 'User:' or 'Assistant:' or any role labels."
      },
      {"role": "user", "content": userMessage}
    ],
    "temperature": 0.3,
    "max_tokens": maxTokens,
    // ⚠️ DO NOT send "stop" here — it’s causing early truncation & empty replies.
    // If we need stops later, we’ll add a safer, narrow set.
  };

  final body = jsonEncode(payload);

  http.Response res;
  try {
    res = await http
        .post(uri, headers: {"Content-Type": "application/json"}, body: body)
        .timeout(const Duration(seconds: 20));
  } catch (e) {
    print('[Liquid] NETWORK ERROR: $e');
    rethrow;
  }

  print('[Liquid] Status: ${res.statusCode}');
  // Log the raw JSON body (truncated) for debugging
  final rawBodyPreview =
      res.body.length > 1200 ? '${res.body.substring(0, 1200)}…' : res.body;
  print('[Liquid] RAW body: $rawBodyPreview');

  if (res.statusCode != 200) {
    throw Exception('LFM2 request failed (${res.statusCode})');
  }

  final json = jsonDecode(res.body);
  final raw = (json["choices"]?[0]?["message"]?["content"] as String?) ?? '';

  final cleaned = _sanitize(raw);
  print('[Liquid] reply.len=${cleaned.length}');
  if (cleaned.isEmpty) {
    print('[Liquid] WARNING: reply empty after sanitize. RAW len=${raw.length}');
  }
  return cleaned;
}

  // ---- Sanitization: remove any leading role labels / artifacts ----
  static final RegExp _rolePrefix =
      RegExp(r'^\s*(assistant|user|system)\s*[:：\-]\s*', caseSensitive: false);
  static final RegExp _bracketRole =
      RegExp(r'^\s*[\(\[\{]?\s*(assistant|user|system)\s*[\)\]\}:]?\s*',
          caseSensitive: false);
  static final RegExp _tripleBackticksFront =
      RegExp(r'^\s*```(?:\w+)?\s*', multiLine: false);
  static final RegExp _tripleBackticksEnd =
      RegExp(r'\s*```\s*$', multiLine: false);

  String _sanitize(String s) {
  var out = s.trim();

  // Remove leading role labels like "User:" / "Assistant:" if present at the very start.
  out = out.replaceFirst(
    RegExp(r'^(?:\s*(?:User|Assistant|System)\s*[:：-]\s*)+', caseSensitive: false),
    '',
  );

  // If the whole reply is wrapped in triple backticks, strip them.
  if (RegExp(r'^\s*```').hasMatch(out) && RegExp(r'```\s*$').hasMatch(out)) {
    out = out.replaceFirst(RegExp(r'^\s*```(?:\w+)?\s*'), '');
    out = out.replaceFirst(RegExp(r'\s*```\s*$'), '');
  }

  // Drop a trailing lone role tag on the last line, if any.
  out = out.replaceFirst(
    RegExp(r'(?:\r?\n)\s*(?:User|Assistant)\s*:?$', caseSensitive: false),
    '',
  );

  // Collapse excessive blank lines
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return out.trim();
}
}
