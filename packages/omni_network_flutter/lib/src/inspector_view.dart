import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'inspector.dart';

/// The inspector UI: request list with filter, and a detail view.
///
/// Works without a `Navigator` (it switches views internally), so it can
/// be shown from `MaterialApp.builder` via [OmniInspectorLauncher].
class OmniInspectorView extends StatefulWidget {
  /// Creates the view.
  const OmniInspectorView({super.key, required this.inspector, this.onClose});

  /// Data source.
  final OmniInspector inspector;

  /// Shows a close button when set.
  final VoidCallback? onClose;

  @override
  State<OmniInspectorView> createState() => _OmniInspectorViewState();
}

class _OmniInspectorViewState extends State<OmniInspectorView> {
  final _filter = TextEditingController();
  InspectorEntry? _selected;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  static Color _color(InspectorStatus s, ColorScheme c) => switch (s) {
    InspectorStatus.pending => c.outline,
    InspectorStatus.success => Colors.green.shade700,
    InspectorStatus.clientError => Colors.orange.shade800,
    InspectorStatus.serverError || InspectorStatus.failed => c.error,
  };

  @override
  Widget build(BuildContext context) => Material(
    child: ListenableBuilder(
      listenable: Listenable.merge([widget.inspector, _filter]),
      builder: (context, _) {
        final sel = _selected;
        return sel == null ? _list(context) : _detail(context, sel);
      },
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
    final items = [
      for (final e in widget.inspector.entries)
        if (q.isEmpty ||
            '${e.method} ${e.url} ${e.statusCode ?? ''} ${e.label}'
                .toLowerCase()
                .contains(q))
          e,
    ];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _bar(
          context,
          'Network (${widget.inspector.entries.length})',
          actions: [
            IconButton(
              tooltip: 'Copy HAR',
              icon: const Icon(Icons.download_outlined),
              onPressed: widget.inspector.entries.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(
                        ClipboardData(text: widget.inspector.toHarJson()),
                      );
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text('HAR copied to clipboard'),
                        ),
                      );
                    },
            ),
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.inspector.clear,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _filter,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: 'Filter by method, URL, status',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No requests'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    final uri = Uri.tryParse(e.url);
                    return ListTile(
                      key: ValueKey('entry-${e.id}'),
                      dense: true,
                      leading: Text(
                        e.method,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      title: Text(
                        uri == null
                            ? e.url
                            : '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          uri?.host ?? '',
                          if (e.duration case final d?)
                            '${d.inMilliseconds} ms',
                          if (e.source case final s? when s.name != 'network')
                            s.name,
                          if (e.label != 'default') e.label,
                        ].where((x) => x.isNotEmpty).join(' · '),
                      ),
                      trailing: Text(
                        e.error != null ? 'ERR' : '${e.statusCode ?? '…'}',
                        style: TextStyle(
                          color: _color(e.status, scheme),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => setState(() => _selected = e),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, InspectorEntry e) {
    Widget section(String title, Map<String, String> headers, String? body) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final h in headers.entries)
                SelectableText(
                  '${h.key}: ${h.value}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              if (body != null) ...[
                const SizedBox(height: 6),
                SelectableText(
                  body,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ],
          ),
        );
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
              tooltip: 'Copy as cURL',
              icon: const Icon(Icons.copy),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: e.toCurl())),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SelectableText(e.url),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  [
                    if (e.duration case final d?) '${d.inMilliseconds} ms',
                    if (e.source case final s?) s.name,
                    ?e.error,
                  ].join(' · '),
                ),
              ),
              section('Request', e.requestHeaders, e.requestBody),
              section('Response', e.responseHeaders, e.responseBody),
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
  });

  /// Data source.
  final OmniInspector inspector;

  /// The app.
  final Widget child;

  /// Button position.
  final Alignment alignment;

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
      return OmniInspectorView(inspector: widget.inspector, onClose: _toggle);
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
