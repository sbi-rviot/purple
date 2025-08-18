class Utterance {
  Utterance({
    required this.id,
    required this.createdAt,
    required this.audioPath,
    required this.rawText,
    required this.improvedText,
    required this.lowConfidence,
    required this.needsReview,
    required this.responseText,
  });

  final String id;
  final DateTime createdAt;
  final String? audioPath;
  final String rawText;
  String improvedText;
  final List<String> lowConfidence;
  bool needsReview;
  final String responseText;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'audioPath': audioPath,
    'rawText': rawText,
    'improvedText': improvedText,
    'lowConfidence': lowConfidence,
    'needsReview': needsReview,
    'responseText': responseText,
  };

  static Utterance fromJson(Map<String, dynamic> j) => Utterance(
    id: j['id'],
    createdAt: DateTime.parse(j['createdAt']),
    audioPath: j['audioPath'],
    rawText: j['rawText'],
    improvedText: j['improvedText'],
    lowConfidence: (j['lowConfidence'] as List).cast<String>(),
    needsReview: j['needsReview'] as bool,
    responseText: j['responseText'] as String,
  );
}

class CorrectionPair {
  final String before;
  final String after;
  CorrectionPair({required this.before, required this.after});

  Map<String, dynamic> toJson() => {'before': before, 'after': after};
  static CorrectionPair fromJson(Map<String, dynamic> j) => CorrectionPair(before: j['before'], after: j['after']);
}

enum Level { rookie, skilled, mentor }

class XpState {
  int totalXp = 0;
  Level get level {
    if (totalXp >= 120) return Level.mentor;
    if (totalXp >= 50) return Level.skilled;
    return Level.rookie;
  }

  double get progressToNext {
    switch (level) {
      case Level.rookie: return (totalXp % 50) / 50.0;
      case Level.skilled: return ((totalXp - 50) % 70) / 70.0;
      case Level.mentor: return 1.0;
    }
  }

  void add(int x) => totalXp += x;
}
