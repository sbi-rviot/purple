// lib/src/pages/status_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../assistant_profiles.dart';
import '../models.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const _TitleWithProfilePicker(),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Assistant'),
              Tab(text: 'Review'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AssistantTab(),
            _ReviewTab(),
          ],
        ),
      ),
    );
  }
}

class _TitleWithProfilePicker extends StatelessWidget {
  const _TitleWithProfilePicker();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Row(
      children: [
        const SizedBox(width: 8),
        // Rounded-square avatar in AppBar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            _avatarAsset(app.profile),
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        // Trigger modal picker
        InkWell(
          onTap: () => _showAssistantPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                app.assistantName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssistantTab extends StatelessWidget {
  const _AssistantTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              _FaceHero(),
              SizedBox(height: 16),
              _XpPill(),
              SizedBox(height: 16),
              _PersonaDescription(),
              SizedBox(height: 20),
              _Controls(),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------- Picker (modal) -----------------------

void _showAssistantPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AssistantPickerSheet(),
  );
}

class _AssistantPickerSheet extends StatefulWidget {
  const _AssistantPickerSheet();

  @override
  State<_AssistantPickerSheet> createState() => _AssistantPickerSheetState();
}

class _AssistantPickerSheetState extends State<_AssistantPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profiles = app.profiles
        .where((p) =>
            _q.trim().isEmpty ||
            p.name.toLowerCase().contains(_q.toLowerCase()) ||
            p.description.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose your assistant',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search assistants...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(.5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: profiles.length,
                itemBuilder: (context, i) {
                  final p = profiles[i];
                  final selected = p.key == app.profile.key;
                  return _AssistantTile(
                    profile: p,
                    selected: selected,
                    onTap: () {
                      context.read<AppState>().setProfile(p);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AssistantTile extends StatelessWidget {
  final AssistantProfile profile;
  final bool selected;
  final VoidCallback onTap;

  const _AssistantTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double avatarSize = 80; // BIGGER avatar
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(minHeight: avatarSize), // row tall as image
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withOpacity(.28)
                : theme.colorScheme.outlineVariant,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Square avatar with rounded corners
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                _avatarAsset(profile),
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        profile.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _SelectionChip(selected: selected),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  final bool selected;
  const _SelectionChip({required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceVariant;
    final fg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final border = selected
        ? theme.colorScheme.primary.withOpacity(.35)
        : theme.colorScheme.outlineVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: selected ? 'Selected' : 'Tap to select',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              selected ? 'Selected' : 'Tap to select',
              style: theme.textTheme.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------- Hero with rounded-square loader -----------------------

class _FaceHero extends StatelessWidget {
  const _FaceHero();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final seed = app.themeSeedColor;

    final rawXp = app.xp.totalXp;
    final progress = ((rawXp % 100) / 100).clamp(0.0, 1.0);

    const double size = 160;         // overall square
    const double ringThickness = 8;  // donut thickness
    const double cornerRadius = 28;  // rounded-square radius

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Track
          CustomPaint(
            size: const Size(size, size),
            painter: _RoundedRectProgressPainter(
              progress: 1.0,
              color: seed.withOpacity(0.12),
              thickness: ringThickness,
              radius: cornerRadius,
            ),
          ),
          // Progress starting at 12 o'clock
          CustomPaint(
            size: const Size(size, size),
            painter: _RoundedRectProgressPainter(
              progress: progress,
              color: seed,
              thickness: ringThickness,
              radius: cornerRadius,
            ),
          ),
          // Avatar image clipped to same rounded square
          Padding(
            padding: const EdgeInsets.all(18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cornerRadius),
              child: Image.asset(
                _avatarAsset(app.profile),
                width: size - 36,
                height: size - 36,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedRectProgressPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final double thickness;
  final double radius;

  _RoundedRectProgressPainter({
    required this.progress,
    required this.color,
    required this.thickness,
    required this.radius,
  });

  @override
void paint(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  final outer = RRect.fromRectAndRadius(
    rect.deflate(thickness / 2),
    Radius.circular(radius),
  );

  final paintStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = thickness
    ..strokeCap = StrokeCap.round
    ..color = color;

  final path = Path()..addRRect(outer);

  // Start at 12 o'clock AND make progress grow CLOCKWISE:
  canvas.save();
  canvas.translate(size.width / 2, size.height / 2);
  canvas.rotate(-math.pi / 2); // put 0 at 12
  canvas.scale(-1, 1);         // mirror horizontally → reverse direction to CW
  canvas.translate(-size.width / 2, -size.height / 2);

  final metric = path.computeMetrics().first;
  final subLen = metric.length * progress.clamp(0.0, 1.0);
  final subPath = metric.extractPath(0, subLen);
  canvas.drawPath(subPath, paintStroke);

  canvas.restore();
}


  @override
  bool shouldRepaint(covariant _RoundedRectProgressPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.thickness != thickness ||
      old.radius != radius;
}

// ----------------------- Misc UI -----------------------

class _PersonaDescription extends StatelessWidget {
  const _PersonaDescription();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    return Text(
      app.assistantDescription,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium,
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final seed = app.themeSeedColor;

    if (!app.isUp) {
      // START
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: FilledButton.icon(
          onPressed: () => context.read<AppState>().toggleUpDown(),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
          style: FilledButton.styleFrom(
            backgroundColor: seed,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    // PAUSE + STOP (when running)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: () {
              final a = context.read<AppState>();
              if (a.isUp) a.toggleUpDown();
              a.utterances.clear();
              a.notifyListeners();
            },
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _XpPill extends StatelessWidget {
  const _XpPill();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lvl = app.level.name.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'XP: ${app.xp.totalXp} • $lvl',
        style: const TextStyle(fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ----------------------- Review tab -----------------------

class _ReviewTab extends StatelessWidget {
  const _ReviewTab();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final needs = app.utterances.where((u) => u.needsReview).toList();

    if (needs.isEmpty) {
      return const Center(child: Text('Nothing to review right now.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: needs.length,
      itemBuilder: (context, i) => _UtteranceCard(u: needs[i]),
    );
  }
}

class _UtteranceCard extends StatelessWidget {
  final Utterance u;
  const _UtteranceCard({required this.u});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              u.createdAt.toLocal().toString().split('.').first,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            if (u.rawText.isNotEmpty) ...[
              const Text('Heard', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(u.rawText),
              const SizedBox(height: 8),
            ],
            if (u.improvedText.isNotEmpty) ...[
              const Text('Improved', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(u.improvedText),
              const SizedBox(height: 8),
            ],
            const Text('Response', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(u.responseText),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (u.needsReview)
                  FilledButton.tonal(
                    onPressed: () => app.approve(u),
                    child: const Text('Approve'),
                  ),
                FilledButton.tonal(
                  onPressed: () async {
                    final text = await _promptForText(
                      context,
                      title: 'Edit transcript',
                      initial: u.improvedText,
                    );
                    if (text != null && text.trim().isNotEmpty) {
                      await app.editAndSave(u, text.trim());
                    }
                  },
                  child: const Text('Edit'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final term = await _promptForText(
                      context,
                      title: 'Add to glossary',
                      hint: 'Term or phrase',
                    );
                    if (term != null && term.trim().isNotEmpty) {
                      await app.addToGlossary(term.trim());
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Glossary'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _promptForText(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 5,
        decoration: InputDecoration(hintText: hint),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ----------------------- Helpers -----------------------

String _avatarAsset(AssistantProfile p) {
  switch (p.key) {
    case 'purple':
      return 'assets/avatars/purple.png';
    case 'green':
      return 'assets/avatars/green.png';
    case 'red':
      return 'assets/avatars/red.png';
    default:
      return 'assets/avatars/purple.png';
  }
}
