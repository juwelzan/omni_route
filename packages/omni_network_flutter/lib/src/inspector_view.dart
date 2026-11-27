import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'inspector.dart';

/// Active view mode inside [OmniInspectorView].
enum InspectorTab {
  /// Paired HTTP requests and responses.
  http,

  /// Talker-style unified color-coded timeline (HTTP, Route, Bloc, WS, AI).
  logs,

  /// Realtime WebSocket events.
  ws,

  /// Multi-Model AI calls and telemetry.
  ai,
}

/// The inspector UI: Talker-style color-coded log & network cards, search and
/// category filters, 1-click copy on every card, and full detail views.
///
/// Works without a parent `Navigator` (it switches views internally), so it can
/// be shown from `MaterialApp.builder` via [OmniInspectorLauncher].
class OmniInspectorView extends StatefulWidget {
  /// Creates the view.
  const OmniInspectorView({
    super.key,
    required this.inspector,
    this.onClose,
    this.initialTab = InspectorTab.http,
  });

  /// Data source.
  final OmniInspector inspector;

  /// Shows a close button when set.
  final VoidCallback? onClose;

  /// Initial tab displayed when opened.
  final InspectorTab initialTab;

  @override
  State<OmniInspectorView> createState() => _OmniInspectorViewState();
}

class _OmniInspectorViewState extends State<OmniInspectorView> {
  final _filter = TextEditingController();
  InspectorEntry? _selected;
  InspectorLogEntry? _selectedLog;
  late InspectorTab _tab = widget.initialTab;
  String _selectedLogCategory = 'all';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  static Color _color(InspectorStatus s, ColorScheme c) => switch (s) {
    InspectorStatus.pending => const Color(0xFFE879F9),
    InspectorStatus.success => const Color(0xFF4ADE80),
    InspectorStatus.clientError => const Color(0xFFFB923C),
    InspectorStatus.serverError || InspectorStatus.failed => c.error,
  };

  static Color _logColor(InspectorLogKind k, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (k) {
      InspectorLogKind.httpResponse =>
        dark ? const Color(0xFF4ADE80) : Colors.green.shade700,
      InspectorLogKind.httpRequest =>
        dark ? const Color(0xFFE879F9) : Colors.purple.shade600,
      InspectorLogKind.httpWarning || InspectorLogKind.warning =>
        dark ? const Color(0xFFFB923C) : Colors.orange.shade800,
      InspectorLogKind.httpError || InspectorLogKind.error =>
        dark ? const Color(0xFFF87171) : Colors.red.shade700,
      InspectorLogKind.route =>
        dark ? const Color(0xFFC084FC) : Colors.deepPurple.shade600,
      InspectorLogKind.blocCreate =>
        dark ? const Color(0xFF86EFAC) : Colors.teal.shade700,
      InspectorLogKind.blocEvent || InspectorLogKind.blocTransition =>
        dark ? const Color(0xFF2DD4BF) : Colors.teal.shade800,
      InspectorLogKind.ws =>
        dark ? const Color(0xFF38BDF8) : Colors.lightBlue.shade700,
      InspectorLogKind.ai =>
        dark ? const Color(0xFF818CF8) : Colors.indigo.shade600,
      InspectorLogKind.info =>
        dark ? const Color(0xFF60A5FA) : Colors.blue.shade700,
    };
  }

  static String _fmtClock(DateTime dt) {
    final t = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  void _copy(BuildContext context, String text, String feedback) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Text(feedback),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    child: Builder(
      builder: (messengerCtx) => Scaffold(
        backgroundColor: Theme.of(messengerCtx).colorScheme.surface,
        body: ListenableBuilder(
          listenable: Listenable.merge([widget.inspector, _filter]),
          builder: (context, _) {
            if (_selected case final sel? when _tab == InspectorTab.http || _tab == InspectorTab.logs) {
              return _detail(context, sel);
            }
            if (_selectedLog case final log? when _tab == InspectorTab.logs) {
              return _logDetail(context, log);
            }
            return _list(context);
          },
        ),
      ),
    ),
  );

  Widget _bar(
    BuildContext context,
    String title, {
    Widget? leading,
    List<Widget> actions = const [],
  }) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            ?leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...actions,
            if (widget.onClose case final close?)
              IconButton(
                tooltip: 'Close inspector',
                icon: const Icon(Icons.close),
                onPressed: close,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _list(BuildContext context) {
    final q = _filter.text.trim().toLowerCase();
    final title = switch (_tab) {
      InspectorTab.http => 'Network (${widget.inspector.entries.length})',
      InspectorTab.logs => 'All Logs (${widget.inspector.logs.length})',
      InspectorTab.ws => 'WebSocket (${widget.inspector.wsEntries.length})',
      InspectorTab.ai => 'AI Calls (${widget.inspector.aiEntries.length})',
    };
    final scheme = Theme.of(context).colorScheme;
    final hasAnyLogs = widget.inspector.logs.isNotEmpty;
    return Column(
      children: [
        _bar(
          context,
          title,
          actions: [
            IconButton(
              tooltip: 'Copy all logs',
              icon: const Icon(Icons.copy_all),
              onPressed: !hasAnyLogs
                  ? null
                  : () {
                      final combined = [
                        for (final l in widget.inspector.logs)
                          '=== ${l.tag} | ${_fmtClock(l.timestamp)} ===\n${l.copyText}',
                      ].join('\n\n');
                      _copy(
                        context,
                        combined,
                        'Copied ${widget.inspector.logs.length} logs to clipboard',
                      );
                    },
            ),
            IconButton(
              tooltip: 'Copy HAR',
              icon: const Icon(Icons.download_outlined),
              onPressed: widget.inspector.entries.isEmpty
                  ? null
                  : () => _copy(
                      context,
                      widget.inspector.toHarJson(),
                      'HAR copied to clipboard',
                    ),
            ),
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.inspector.clear,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('HTTP (${widget.inspector.entries.length})'),
                  selected: _tab == InspectorTab.http,
                  onSelected: (_) => setState(() {
                    _selectedLog = null;
                    _tab = InspectorTab.http;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Logs (${widget.inspector.logs.length})'),
                  selected: _tab == InspectorTab.logs,
                  onSelected: (_) => setState(() {
                    _selected = null;
                    _selectedLog = null;
                    _tab = InspectorTab.logs;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('WS (${widget.inspector.wsEntries.length})'),
                  selected: _tab == InspectorTab.ws,
                  onSelected: (_) => setState(() {
                    _selected = null;
                    _selectedLog = null;
                    _tab = InspectorTab.ws;
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('AI (${widget.inspector.aiEntries.length})'),
                  selected: _tab == InspectorTab.ai,
                  onSelected: (_) => setState(() {
                    _selected = null;
                    _selectedLog = null;
                    _tab = InspectorTab.ai;
                  }),
                ),
              ],
            ),
          ),
        ),
        if (_tab == InspectorTab.logs) _logCategoryStrip(context),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _filter,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            InspectorTab.http => _httpList(context, q, scheme),
            InspectorTab.logs => _logsList(context, q, scheme),
            InspectorTab.ws => _wsList(context, q, scheme),
            InspectorTab.ai => _aiList(context, q, scheme),
          },
        ),
      ],
    );
  }

  Widget _logCategoryStrip(BuildContext context) {
    final logs = widget.inspector.logs;
    final counts = <String, int>{'all': logs.length};
    for (final l in logs) {
      counts[l.tag] = (counts[l.tag] ?? 0) + 1;
    }
    final orderedTags = [
      'all',
      for (final tag in [
        'http-response',
        'http-request',
        'http-warning',
        'http-error',
        'route',
        'bloc-event',
        'bloc-transition',
        'bloc-create',
        'ws-in',
        'ws-out',
        'ai-response',
        'info',
        'warning',
        'error',
      ])
        if ((counts[tag] ?? 0) > 0) tag,
    ];
    for (final tag in counts.keys) {
      if (!orderedTags.contains(tag)) orderedTags.add(tag);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tag in orderedTags) ...[
              FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text('${counts[tag]} $tag'),
                selected: _selectedLogCategory == tag,
                onSelected: (_) => setState(() => _selectedLogCategory = tag),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _talkerCard({
    required BuildContext context,
    required Color accent,
    required Widget child,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: Material(
      color: accent.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: accent.withValues(alpha: 0.72), width: 1.15),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );

  Widget _httpList(BuildContext context, String q, ColorScheme scheme) {
    final items = [
      for (final e in widget.inspector.entries)
        if (q.isEmpty ||
            '${e.method} ${e.url} ${e.statusCode ?? ''} ${e.label}'
                .toLowerCase()
                .contains(q))
          e,
    ];
    if (items.isEmpty) return const Center(child: Text('No requests'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final uri = Uri.tryParse(e.url);
        final accent = _color(e.status, scheme);
        final copyPayload = e.formattedResponseBody().isNotEmpty
            ? e.formattedResponseBody()
            : e.formattedFullLog();
        return _talkerCard(
          context: context,
          accent: accent,
          child: ListTile(
            key: ValueKey('entry-${e.id}'),
            dense: true,
            leading: Text(
              e.method,
              style: TextStyle(fontWeight: FontWeight.bold, color: accent),
            ),
            title: Text(
              uri == null
                  ? e.url
                  : '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: accent),
            ),
            subtitle: Text(
              [
                _fmtClock(e.startedAt),
                uri?.host ?? '',
                if (e.duration case final d?) '${d.inMilliseconds} ms',
                if (e.source case final s? when s.name != 'network') s.name,
                if (e.label != 'default') e.label,
              ].where((x) => x.isNotEmpty).join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.error != null ? 'ERR' : '${e.statusCode ?? '…'}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Copy response',
                  icon: Icon(Icons.copy, size: 18, color: accent),
                  onPressed: () => _copy(
                    context,
                    copyPayload,
                    'Copied ${e.method} ${e.statusCode ?? 'log'} response!',
                  ),
                ),
              ],
            ),
            onTap: () => setState(() => _selected = e),
          ),
        );
      },
    );
  }

  Widget _logsList(BuildContext context, String q, ColorScheme scheme) {
    final brightness = Theme.of(context).brightness;
    final items = [
      for (final l in widget.inspector.logs)
        if ((_selectedLogCategory == 'all' || l.tag == _selectedLogCategory) &&
            (q.isEmpty ||
                '${l.tag} ${l.title} ${l.subtitle}'.toLowerCase().contains(q)))
          l,
    ];
    if (items.isEmpty) return const Center(child: Text('No logs recorded'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final l = items[i];
        final accent = _logColor(l.kind, brightness);
        final header = [
          '${l.tag} | ${_fmtClock(l.timestamp)}',
          if (l.duration case final d?) '${d.inMilliseconds}ms',
        ].join(' ');
        final payloadToCopy = (l.copyBody != null && l.copyBody!.isNotEmpty)
            ? l.copyBody!
            : l.copyText;
        return _talkerCard(
          context: context,
          accent: accent,
          child: ListTile(
            key: ValueKey('log-${l.id}'),
            dense: true,
            title: Text(
              header,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: accent,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              [l.title, if (l.subtitle.isNotEmpty) l.subtitle].join('\n'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Copy ${l.tag}',
              icon: Icon(Icons.copy, size: 18, color: accent),
              onPressed: () => _copy(
                context,
                payloadToCopy,
                'Copied ${l.tag} to clipboard',
              ),
            ),
            onTap: () => setState(() {
              if (l.httpEntry != null) {
                _selected = l.httpEntry;
              } else {
                _selectedLog = l;
              }
            }),
          ),
        );
      },
    );
  }

  Widget _wsList(BuildContext context, String q, ColorScheme scheme) {
    final items = [
      for (final e in widget.inspector.wsEntries)
        if (q.isEmpty ||
            '${e.direction} ${e.uri} ${e.summary}'.toLowerCase().contains(q))
          e,
    ];
    if (items.isEmpty) {
      return const Center(child: Text('No WebSocket events'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final isErr = e.direction == 'err';
        final accent = isErr ? scheme.error : const Color(0xFF38BDF8);
        return _talkerCard(
          context: context,
          accent: accent,
          child: ListTile(
            dense: true,
            leading: Text(
              e.direction.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: accent),
            ),
            title: Text(
              e.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${e.uri} · ${_fmtClock(e.timestamp)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Copy WS frame',
              icon: Icon(Icons.copy, size: 18, color: accent),
              onPressed: () => _copy(context, e.summary, 'Copied WS frame'),
            ),
          ),
        );
      },
    );
  }

  Widget _aiList(BuildContext context, String q, ColorScheme scheme) {
    final items = [
      for (final e in widget.inspector.aiEntries)
        if (q.isEmpty ||
            '${e.providerId} ${e.model} ${e.promptPreview ?? ''} ${e.responsePreview ?? ''} ${e.error ?? ''}'
                .toLowerCase()
                .contains(q))
          e,
    ];
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Calls: ${widget.inspector.aiEntries.length} · '
            'Tokens: ${widget.inspector.totalAiTokens} · '
            'Est. Cost: \$${widget.inspector.totalAiCostUsd.toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No AI calls'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    final accent = e.error != null
                        ? scheme.error
                        : const Color(0xFF818CF8);
                    return _talkerCard(
                      context: context,
                      accent: accent,
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          e.error != null
                              ? Icons.error_outline
                              : Icons.auto_awesome,
                          color: accent,
                        ),
                        title: Text('${e.providerId}:${e.model}'),
                        subtitle: Text(
                          [
                            if (e.promptPreview != null) 'Q: ${e.promptPreview}',
                            if (e.responsePreview != null)
                              'A: ${e.responsePreview}',
                            if (e.error != null) 'Error: ${e.error}',
                            if (e.usedFallback) 'fallback',
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${e.usage.totalTokens} tok'),
                                Text(
                                  '${e.latency.inMilliseconds} ms',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Copy AI reply',
                              icon: Icon(Icons.copy, size: 18, color: accent),
                              onPressed: () => _copy(
                                context,
                                e.responsePreview ?? e.error ?? '',
                                'Copied AI response',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static List<TextSpan> _syntaxSpans(String input, Color fallbackColor) {
    final spans = <TextSpan>[];
    final lines = input.split('\n');
    final isJsonLike = () {
      final t = input.trimLeft();
      return t.startsWith('{') || t.startsWith('[');
    }();

    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      if (!isJsonLike) {
        spans.add(
          TextSpan(
            text: li + 1 < lines.length ? '$line\n' : line,
            style: TextStyle(color: fallbackColor),
          ),
        );
        continue;
      }

      var i = 0;
      while (i < line.length) {
        final c = line[i];
        if (c == '"') {
          var j = i + 1;
          var escaped = false;
          while (j < line.length) {
            final d = line[j];
            j++;
            if (escaped) {
              escaped = false;
            } else if (d == r'\') {
              escaped = true;
            } else if (d == '"') {
              break;
            }
          }
          var k = j;
          while (k < line.length && line[k] == ' ') {
            k++;
          }
          final isKey = k < line.length && line[k] == ':';
          spans.add(
            TextSpan(
              text: line.substring(i, j),
              style: TextStyle(
                color: isKey ? const Color(0xFF67E8F9) : const Color(0xFFFDE68A),
                fontWeight: isKey ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
          i = j;
        } else if ('{}[],:'.contains(c)) {
          spans.add(
            TextSpan(
              text: c,
              style: const TextStyle(color: Color(0xFFCBD5E1)),
            ),
          );
          i++;
        } else if (c == '-' || (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39)) {
          var j = i + 1;
          while (j < line.length && '0123456789eE+-.'.contains(line[j])) {
            j++;
          }
          spans.add(
            TextSpan(
              text: line.substring(i, j),
              style: const TextStyle(color: Color(0xFFC4B5FD)),
            ),
          );
          i = j;
        } else if (line.startsWith('true', i) ||
            line.startsWith('null', i) ||
            line.startsWith('false', i)) {
          final n = line.startsWith('false', i) ? 5 : 4;
          spans.add(
            TextSpan(
              text: line.substring(i, i + n),
              style: const TextStyle(
                color: Color(0xFFF472B6),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
          i += n;
        } else {
          spans.add(
            TextSpan(
              text: c,
              style: TextStyle(color: fallbackColor),
            ),
          );
          i++;
        }
      }
      if (li + 1 < lines.length) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }

  Widget _syntaxBox(String text, Color accent) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withValues(alpha: 0.72), width: 1.1),
    ),
    child: SelectableText.rich(
      TextSpan(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.4,
          color: Color(0xFFE2E8F0),
        ),
        children: _syntaxSpans(text, accent),
      ),
    ),
  );

  Widget _logDetail(BuildContext context, InspectorLogEntry log) {
    final accent = _logColor(log.kind, Theme.of(context).brightness);
    final codeAccent = _logColor(log.kind, Brightness.dark);
    return Column(
      children: [
        _bar(
          context,
          '${log.tag} · ${_fmtClock(log.timestamp)}',
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selectedLog = null),
          ),
          actions: [
            IconButton(
              tooltip: 'Copy log',
              icon: const Icon(Icons.copy),
              onPressed: () => _copy(
                context,
                log.copyText,
                'Copied ${log.tag} log to clipboard',
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (log.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(log.subtitle, style: TextStyle(color: accent)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _copy(context, log.copyText, 'Copied full log'),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Full Log'),
                  ),
                  if (log.copyBody != null && log.copyBody!.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _copy(
                        context,
                        log.copyBody!,
                        'Copied JSON payload',
                      ),
                      icon: const Icon(Icons.data_object, size: 16),
                      label: const Text('Copy JSON'),
                    ),
                ],
              ),
              if (log.copyBody != null && log.copyBody!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Payload', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                _syntaxBox(log.copyBody!, codeAccent),
              ],
              const SizedBox(height: 12),
              Text('Full Record', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              _syntaxBox(log.copyText, codeAccent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, InspectorEntry e) {
    final prettyRes = e.formattedResponseBody();
    final prettyReq = e.formattedRequestBody();
    final scheme = Theme.of(context).colorScheme;
    final statusAccent = _color(e.status, scheme);
    final codeAccent = switch (e.status) {
      InspectorStatus.pending => const Color(0xFFE879F9),
      InspectorStatus.success => const Color(0xFF4ADE80),
      InspectorStatus.clientError => const Color(0xFFFB923C),
      InspectorStatus.serverError || InspectorStatus.failed =>
        const Color(0xFFF87171),
    };
    final reqAccent = const Color(0xFFE879F9);

    Widget section(
      String title,
      Map<String, String> headers,
      String? body,
      Color accent,
    ) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: accent),
          ),
          const SizedBox(height: 6),
          if (headers.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final h in headers.entries)
                    SelectableText.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: '${h.key}: ',
                            style: const TextStyle(color: Color(0xFF67E8F9)),
                          ),
                          TextSpan(
                            text: h.value,
                            style: const TextStyle(color: Color(0xFFCBD5E1)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (body != null && body.isNotEmpty) _syntaxBox(body, accent),
        ],
      ),
    );

    final statusLabel = switch (e.status) {
      InspectorStatus.pending => 'PENDING',
      InspectorStatus.success => 'SUCCESS ${e.statusCode ?? ''}'.trim(),
      InspectorStatus.clientError => 'WARNING ${e.statusCode ?? ''}'.trim(),
      InspectorStatus.serverError => 'ERROR ${e.statusCode ?? ''}'.trim(),
      InspectorStatus.failed => 'FAILED',
    };

    return Column(
      children: [
        _bar(
          context,
          '${e.method} ${e.statusCode ?? e.error ?? '…'}',
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selected = null),
          ),
          actions: [
            IconButton(
              tooltip: 'Copy response',
              icon: const Icon(Icons.data_object),
              onPressed: () => _copy(
                context,
                prettyRes.isNotEmpty ? prettyRes : e.formattedFullLog(),
                'Copied full API response',
              ),
            ),
            IconButton(
              tooltip: 'Copy as cURL',
              icon: const Icon(Icons.copy),
              onPressed: () =>
                  _copy(context, e.toCurl(), 'cURL copied to clipboard'),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusAccent.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.method} · $statusLabel',
                        style: TextStyle(
                          color: statusAccent,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        e.url,
                        style: TextStyle(
                          color: statusAccent,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      if (e.duration != null || e.source != null || e.error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (e.duration case final d?)
                              '${d.inMilliseconds} ms',
                            if (e.source case final s?) s.name,
                            ?e.error,
                          ].join(' · '),
                          style: TextStyle(color: statusAccent, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _copy(
                        context,
                        prettyRes.isNotEmpty ? prettyRes : e.formattedFullLog(),
                        'Full API response copied!',
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Full Response'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copy(
                        context,
                        e.formattedFullLog(),
                        'Complete HTTP log copied!',
                      ),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Copy Full Log'),
                    ),
                  ],
                ),
              ),
              section(
                'Request',
                e.requestHeaders,
                prettyReq.isNotEmpty ? prettyReq : e.requestBody,
                reqAccent,
              ),
              section(
                'Response',
                e.responseHeaders,
                prettyRes.isNotEmpty
                    ? prettyRes
                    : (e.responseBody ?? e.error),
                codeAccent,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// Puts a small floating button over [child] that opens the inspector as a
/// full-screen panel. Renders only [child] when the inspector is disabled.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) =>
///       OmniInspectorLauncher(inspector: inspector, child: child!),
/// )
/// ```
class OmniInspectorLauncher extends StatefulWidget {
  /// Creates the launcher.
  const OmniInspectorLauncher({
    super.key,
    required this.inspector,
    required this.child,
    this.alignment = Alignment.bottomRight,
    this.initialTab = InspectorTab.http,
  });

  /// Data source.
  final OmniInspector inspector;

  /// The app.
  final Widget child;

  /// Button position.
  final Alignment alignment;

  /// Initial tab shown when opening the inspector.
  final InspectorTab initialTab;

  @override
  State<OmniInspectorLauncher> createState() => _OmniInspectorLauncherState();
}

class _OmniInspectorLauncherState extends State<OmniInspectorLauncher> {
  bool _open = false;

  /// Whether the entries were handed to our [Overlay] (they then must be
  /// removed before being disposed).
  bool _inserted = false;

  late final OverlayEntry _app = OverlayEntry(builder: (_) => widget.child);
  late final OverlayEntry _ui = OverlayEntry(builder: _buildUi);

  void _toggle() {
    _open = !_open;
    _ui.markNeedsBuild();
  }

  @override
  void didUpdateWidget(OmniInspectorLauncher old) {
    super.didUpdateWidget(old);
    _app.markNeedsBuild();
    _ui.markNeedsBuild();
  }

  @override
  void dispose() {
    if (_inserted) {
      _app.remove();
      _ui.remove();
    }
    _app.dispose();
    _ui.dispose();
    super.dispose();
  }

  Widget _buildUi(BuildContext context) {
    if (_open) {
      return OmniInspectorView(
        inspector: widget.inspector,
        initialTab: widget.initialTab,
        onClose: _toggle,
      );
    }
    return Align(
      alignment: widget.alignment,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Open network inspector',
            onPressed: _toggle,
            child: const Icon(Icons.network_check),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.inspector.enabled) return widget.child;
    _inserted = true;
    // Own Overlay: tooltips and text fields need one, and
    // MaterialApp.builder sits above the app's Navigator/Overlay. The app
    // is the bottom entry, the button/panel the top one.
    return Overlay(initialEntries: [_app, _ui]);
  }
}
