import 'package:flutter/material.dart';
import '../assistant_profiles.dart';

/// Opens a modal bottom sheet to pick an AssistantProfile.
/// Returns the selected profile, or null if dismissed.
Future<AssistantProfile?> showAssistantPicker(
  BuildContext context, {
  required List<AssistantProfile> profiles,
  AssistantProfile? current,
}) {
  return showModalBottomSheet<AssistantProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      final modalColor = theme.colorScheme.surface;
      final divider = Divider(
        height: 1,
        thickness: 1,
        color: theme.colorScheme.outlineVariant.withOpacity(0.4),
      );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: modalColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 24,
                  offset: Offset(0, 8),
                  color: Colors.black26,
                ),
              ],
            ),
            child: _AssistantPickerSheet(
              profiles: profiles,
              current: current,
              divider: divider,
            ),
          ),
        ),
      );
    },
  );
}

class _AssistantPickerSheet extends StatefulWidget {
  const _AssistantPickerSheet({
    required this.profiles,
    required this.current,
    required this.divider,
  });

  final List<AssistantProfile> profiles;
  final AssistantProfile? current;
  final Divider divider;

  @override
  State<_AssistantPickerSheet> createState() => _AssistantPickerSheetState();
}

class _AssistantPickerSheetState extends State<_AssistantPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.profiles.where((p) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.key.toLowerCase().contains(q);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Height: 70% of viewport, adaptive.
        final maxH = MediaQuery.of(context).size.height * 0.7;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Choose your assistant',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop<AssistantProfile>(null),
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search assistants…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: widget.divider,
              ),

              // List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final selected = widget.current?.key == p.key;
                    return _AssistantCard(
                      profile: p,
                      selected: selected,
                      onTap: () => Navigator.of(context).pop<AssistantProfile>(p),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final AssistantProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final textColor = theme.colorScheme.onSurface;
    final badgeColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant;

    return Material(
      color: cardColor,
      elevation: selected ? 2 : 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(initial: profile.name.isNotEmpty ? profile.name[0] : '?', color: profile.color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(selected ? 0.16 : 0.4),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected ? theme.colorScheme.primary : Colors.transparent,
                              width: selected ? 1 : 0,
                            ),
                          ),
                          child: Text(
                            selected ? 'Selected' : 'Tap to select',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.color});
  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color.withOpacity(0.16);
    final fg = color;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
