import 'package:flutter/material.dart';
import 'package:omni_network/omni_network.dart';

/// Compact interactive selector for choosing or switching the active AI model
/// alias or `'provider:model'` across [OmniAi] routes and providers.
class OmniModelPicker extends StatelessWidget {
  /// Creates a model switcher bound to [ai].
  const OmniModelPicker({
    super.key,
    required this.ai,
    required this.selectedModel,
    required this.onSelected,
    this.extraModels = const [],
    this.compact = false,
  });

  /// AI router providing configured routes and default model.
  final OmniAi ai;

  /// Currently selected route alias or `'provider:model'`.
  final String selectedModel;

  /// Invoked when the user picks a different model or route alias.
  final ValueChanged<String> onSelected;

  /// Additional `'provider:model'` choices presented alongside configured routes.
  final List<String> extraModels;

  /// Whether to render as an icon-compact pill instead of an expanded chip.
  final bool compact;

  List<String> _choices() {
    final seen = <String>{};
    final items = <String>[];
    void add(String? value) {
      if (value != null && value.isNotEmpty && seen.add(value)) {
        items.add(value);
      }
    }

    add(selectedModel);
    add(ai.defaultModel);
    for (final alias in ai.routes.keys) {
      add(alias);
    }
    for (final extra in extraModels) {
      add(extra);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final choices = _choices();
    final label = selectedModel.isEmpty ? 'Select model' : selectedModel;

    return PopupMenuButton<String>(
      tooltip: 'Select AI model',
      initialValue: selectedModel.isEmpty ? null : selectedModel,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final c in choices)
          PopupMenuItem<String>(
            value: c,
            child: _MenuRow(
              name: c,
              selected: c == selectedModel,
              subtitle: _subtitleFor(c),
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: compact ? 15 : 16,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  String? _subtitleFor(String choice) {
    final route = ai.routes[choice];
    if (route == null || route.targets.isEmpty) return null;
    final primary = route.targets.first;
    final fallbackCount = route.targets.length - 1;
    final suffix = fallbackCount > 0 ? ' (+$fallbackCount fallback)' : '';
    return '${primary.provider}:${primary.model}$suffix';
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.name,
    required this.selected,
    this.subtitle,
  });

  final String name;
  final bool selected;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? Icons.check : Icons.circle_outlined,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
