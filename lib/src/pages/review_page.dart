import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.utterances.where((u) => u.needsReview).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Train')),
      body: items.isEmpty
        ? const _EmptyState()
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) => _UtteranceCard(u: items[i]),
          ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.school, size: 64),
            SizedBox(height: 12),
            Text('Nothing to review. Speak a bit and come back!'),
          ],
        ),
      ),
    );
  }
}

class _UtteranceCard extends StatefulWidget {
  final Utterance u;
  const _UtteranceCard({required this.u});

  @override
  State<_UtteranceCard> createState() => _UtteranceCardState();
}

class _UtteranceCardState extends State<_UtteranceCard> {
  bool editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.u.improvedText);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final u = widget.u;

    Widget annotated(String text, List<String> lowConf) {
      final words = text.split(RegExp(r'\s+'));
      return Wrap(
        spacing: 4, runSpacing: 4,
        children: words.map((w) {
          final low = lowConf.contains(w.toLowerCase());
          return DecoratedBox(
            decoration: low ? const BoxDecoration(border: Border(bottom: BorderSide(width: 2))) : const BoxDecoration(),
            child: Text(w),
          );
        }).toList(),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic_none),
                const SizedBox(width: 8),
                Text('${u.createdAt.hour.toString().padLeft(2,'0')}:${u.createdAt.minute.toString().padLeft(2,'0')}'),
                const Spacer(),
                if (!editing)
                  IconButton(onPressed: () => setState(() => editing = true), icon: const Icon(Icons.edit)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Raw', style: TextStyle(fontWeight: FontWeight.w600)),
            annotated(u.rawText, u.lowConfidence),
            const SizedBox(height: 8),
            const Text('Improved', style: TextStyle(fontWeight: FontWeight.w600)),
            editing
              ? TextField(controller: _ctrl, minLines: 1, maxLines: 5)
              : annotated(u.improvedText, const []),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await app.addToGlossary(_suggestHotword(u));
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('+5 XP • Added to glossary')));
                  },
                  icon: const Icon(Icons.star_border),
                  label: const Text('Add to Glossary'),
                ),
                const Spacer(),
                if (editing)
                  FilledButton(
                    onPressed: () async {
                      await app.editAndSave(u, _ctrl.text.trim());
                      if (mounted) {
                        setState(() => editing = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('+15 XP • Saved correction')));
                      }
                    },
                    child: const Text('Save'),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      await app.approve(u);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('+10 XP • Approved')));
                    },
                    child: const Text('Approve'),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  String _suggestHotword(Utterance u) {
    // naive: pick a capitalized token from improvedText
    for (final token in u.improvedText.split(RegExp(r'\s+'))) {
      if (token.isNotEmpty && token[0].toUpperCase() == token[0] && token[0].contains(RegExp(r'[A-Z]'))) {
        return token.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
      }
    }
    return 'Marie';
  }
}
