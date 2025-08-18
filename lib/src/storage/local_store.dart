import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models.dart';

class LocalStore {
  late Directory _dir;
  late File _utterFile;
  late File _glossaryFile;
  late File _xpFile;
  late File _corrFile;

  Future<void> init() async {
    _dir = await getApplicationDocumentsDirectory();
    _utterFile = File('${_dir.path}/utterances.json');
    _glossaryFile = File('${_dir.path}/glossary.json');
    _xpFile = File('${_dir.path}/xp.json');
    _corrFile = File('${_dir.path}/corrections.json');
    for (final f in [_utterFile, _glossaryFile, _xpFile, _corrFile]) {
      if (!await f.exists()) await f.writeAsString(f == _xpFile ? '{"xp":0}' : '[]');
    }
  }

  Future<List<Utterance>> loadUtterances() async {
    final j = jsonDecode(await _utterFile.readAsString()) as List;
    return j.map((e) => Utterance.fromJson(e)).toList();
  }

  Future<void> saveUtterances(List<Utterance> list) async {
    final j = list.map((e) => e.toJson()).toList();
    await _utterFile.writeAsString(jsonEncode(j));
  }

  Future<Set<String>> loadGlossary() async {
    final j = jsonDecode(await _glossaryFile.readAsString()) as List;
    return j.cast<String>().toSet();
  }

  Future<void> saveGlossary(Set<String> glossary) async {
    await _glossaryFile.writeAsString(jsonEncode(glossary.toList()));
  }

  Future<int> loadXp() async {
    final j = jsonDecode(await _xpFile.readAsString()) as Map<String, dynamic>;
    return (j['xp'] as num).toInt();
    }

  Future<void> saveXp(int xp) async {
    await _xpFile.writeAsString(jsonEncode({'xp': xp}));
  }

  Future<void> addCorrection(CorrectionPair pair) async {
    final list = await loadCorrections();
    list.add({'before': pair.before, 'after': pair.after});
    await _corrFile.writeAsString(jsonEncode(list));
  }

  Future<List<Map<String, String>>> loadCorrections() async {
    final j = jsonDecode(await _corrFile.readAsString()) as List;
    return j.map((e) => {
      'before': e['before'] as String,
      'after': e['after'] as String
    }).toList();
  }
}
