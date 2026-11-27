import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

/// Every way to use `showOmniBottomSheet` (`/settings/sheets`).
class SheetsDemoScreen extends OmniStatefulWidget {
  /// Creates the demo.
  const SheetsDemoScreen({super.key});

  @override
  String get routePath => '/settings/sheets';

  @override
  String get title => 'Bottom Sheets';

  @override
  State<SheetsDemoScreen> createState() => _SheetsDemoScreenState();
}

class _SheetsDemoScreenState extends OmniState<SheetsDemoScreen> {
  OmniSheetStyle _style = OmniSheetStyle.adaptive;
  String? _city;

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  // 1. Sized to its content; returns the picked value.
  Future<void> _pickCity() async {
    final city = await showOmniBottomSheet<String>(
      context: context,
      style: _style,
      builder: (context) => const _CityPicker(),
    );
    if (!mounted || city == null) return;
    setState(() => _city = city);
    _toast('Picked $city');
  }

  // 2. Medium / large detents with a long list that drags the sheet.
  void _openList() => showOmniBottomSheet<void>(
    context: context,
    style: _style,
    detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
    builder: (context) => const _LongList(),
  );

  // 3. A form: sits above the keyboard and refuses to close with edits.
  void _openForm() => showOmniBottomSheet<void>(
    context: context,
    style: _style,
    builder: (context) => const _NoteForm(),
  );

  // 4. Everything customised.
  void _openCustom() => showOmniBottomSheet<void>(
    context: context,
    style: OmniSheetStyle.floating,
    motion: OmniSheetMotion.bouncy,
    cornerRadius: 32,
    margin: const EdgeInsets.all(16),
    backgroundColor: context.colors.primaryColor,
    handleColor: context.colors.buttonTextColor.withValues(alpha: 0.6),
    builder: (context) => _CustomContent(color: context.colors.buttonTextColor),
  );

  // 5. Must be closed with its button.
  void _openLocked() => showOmniBottomSheet<void>(
    context: context,
    style: _style,
    isDismissible: false,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Terms updated', style: context.textStyles.title),
          const SizedBox(height: 8),
          Text(
            'Tapping outside or dragging down does nothing here — '
            'the sheet stretches and springs back.',
            style: context.textStyles.bodyMuted,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => OmniSheet.of(context).close(),
            child: const Text('Accept'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text('$screenTitle ($routePath)')),
      body: ListView(
        padding: tk.pagePadding,
        children: [
          Text('Style', style: context.textStyles.title),
          tk.gapSm,
          SegmentedButton<OmniSheetStyle>(
            segments: const [
              ButtonSegment(
                value: OmniSheetStyle.adaptive,
                label: Text('Adaptive'),
              ),
              ButtonSegment(
                value: OmniSheetStyle.material,
                label: Text('Material'),
              ),
              ButtonSegment(
                value: OmniSheetStyle.cupertino,
                label: Text('iOS'),
              ),
              ButtonSegment(
                value: OmniSheetStyle.floating,
                label: Text('Floating'),
              ),
            ],
            selected: {_style},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _style = s.first),
          ),
          tk.gapMd,
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _DemoTile(
                  icon: Icons.location_city,
                  title: 'Pick a city',
                  subtitle: _city == null
                      ? 'Sized to content · returns a result'
                      : 'Last picked: $_city',
                  onTap: _pickCity,
                ),
                _DemoTile(
                  icon: Icons.view_agenda_outlined,
                  title: 'Long list with detents',
                  subtitle: 'Medium ↔ large · drag the list to move the sheet',
                  onTap: _openList,
                ),
                _DemoTile(
                  icon: Icons.edit_note,
                  title: 'Form with keyboard',
                  subtitle: 'Above the keyboard · asks before losing edits',
                  onTap: _openForm,
                ),
                _DemoTile(
                  icon: Icons.palette_outlined,
                  title: 'Custom look',
                  subtitle: 'Floating · bouncy spring · own colors & radius',
                  onTap: _openCustom,
                ),
                _DemoTile(
                  icon: Icons.map_outlined,
                  title: 'Scalable sheet on a page',
                  subtitle: 'Opens at medium · peek / medium / large · dims',
                  onTap: () => context.to<ScalableSheetDemoScreen>(),
                ),
                _DemoTile(
                  icon: Icons.lock_outline,
                  title: 'Not dismissible',
                  subtitle: 'Only its button closes it',
                  onTap: _openLocked,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _CityPicker extends StatelessWidget {
  const _CityPicker();

  static const _cities = ['Dhaka', 'Chattogram', 'Sylhet', 'Khulna'];

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
        child: Text('Choose a city', style: context.textStyles.title),
      ),
      for (final city in _cities)
        ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(city),
          onTap: () => OmniSheet.of(context).close(city),
        ),
      const SizedBox(height: 8),
    ],
  );
}

class _LongList extends StatelessWidget {
  const _LongList();

  @override
  Widget build(BuildContext context) {
    final sheet = OmniSheet.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('Students', style: context.textStyles.title),
              ),
              // Rebuilds only this button when the detent changes.
              ValueListenableBuilder<int>(
                valueListenable: sheet.detent,
                builder: (context, detent, _) => TextButton(
                  onPressed: () => sheet.snapTo(detent == 0 ? 1 : 0),
                  child: Text(detent == 0 ? 'Expand' : 'Collapse'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          // No controller needed on iOS/Android; desktop passes it explicitly.
          child: ListView.builder(
            controller: sheet.scrollController,
            itemCount: 60,
            itemBuilder: (context, i) => ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text('Student #${100 + i}'),
              subtitle: const Text('Drag at the top of the list to close'),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteForm extends StatefulWidget {
  const _NoteForm();

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  final _text = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: context.styles.dangerButton,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) OmniSheet.of(context).close();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmDiscard();
    },
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New note', style: context.textStyles.title),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Write something…'),
            onChanged: (v) {
              final dirty = v.trim().isNotEmpty;
              if (dirty != _dirty) setState(() => _dirty = dirty);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() => _dirty = false);
              OmniSheet.of(context).close();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _CustomContent extends StatelessWidget {
  const _CustomContent({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.celebration, size: 48, color: color),
        const SizedBox(height: 12),
        Text(
          'Premium unlocked',
          style: context.textStyles.heading.copyWith(color: color),
        ),
        const SizedBox(height: 6),
        Text(
          'Floating style, bouncy spring, your own colors and radius.',
          textAlign: TextAlign.center,
          style: context.textStyles.body.copyWith(color: color),
        ),
      ],
    ),
  );
}

/// `OmniScalableSheet` on a page (`/settings/sheets/scalable`): opens at
/// medium, rests on peek / medium / large, dims the page above medium.
class ScalableSheetDemoScreen extends OmniStatefulWidget {
  /// Creates the demo.
  const ScalableSheetDemoScreen({super.key});

  @override
  String get routePath => '/settings/sheets/scalable';

  @override
  String get title => 'Scalable Sheet';

  @override
  State<ScalableSheetDemoScreen> createState() =>
      _ScalableSheetDemoScreenState();
}

class _ScalableSheetDemoScreenState extends OmniState<ScalableSheetDemoScreen> {
  final _sheet = OmniScalableSheetController();
  OmniSheetStyle _style = OmniSheetStyle.adaptive;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(screenTitle),
      actions: [
        PopupMenuButton<OmniSheetStyle>(
          tooltip: 'Style',
          icon: const Icon(Icons.style_outlined),
          initialValue: _style,
          onSelected: (s) => setState(() => _style = s),
          itemBuilder: (_) => [
            for (final s in OmniSheetStyle.values)
              PopupMenuItem(value: s, child: Text(s.name)),
          ],
        ),
      ],
    ),
    body: OmniScalableSheet(
      // A new style is a new sheet (it opens again at its initial size).
      key: ValueKey(_style),
      controller: _sheet,
      style: _style,
      detents: const [
        OmniSheetDetent.height(150), // peek
        OmniSheetDetent.medium,
        OmniSheetDetent.large,
      ],
      initialDetent: 1, // opens at medium
      dimFromDetent: 1, // the map dims as it grows past medium
      body: _FakeMap(sheet: _sheet),
      builder: (context) => _PlacesList(sheet: _sheet),
    ),
  );
}

class _FakeMap extends StatelessWidget {
  const _FakeMap({required this.sheet});

  final OmniScalableSheetController sheet;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.secondaryBackgroundColor, c.infoBackgroundColor],
            ),
          ),
        ),
        for (final (x, y) in const [(0.2, 0.15), (0.7, 0.3), (0.45, 0.5)])
          Align(
            alignment: Alignment(x * 2 - 1, y * 2 - 1),
            child: Icon(Icons.location_on, size: 40, color: c.primaryColor),
          ),
        // Rides above the sheet without rebuilding the page.
        AnimatedBuilder(
          animation: sheet.height,
          builder: (context, child) => Positioned(
            right: 16,
            bottom: sheet.height.value + 16,
            child: child!,
          ),
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Show places',
            onPressed: sheet.expand,
            child: const Icon(Icons.list),
          ),
        ),
      ],
    );
  }
}

class _PlacesList extends StatelessWidget {
  const _PlacesList({required this.sheet});

  final OmniScalableSheetController sheet;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text('Places nearby', style: context.textStyles.title),
            ),
            ValueListenableBuilder<int>(
              valueListenable: sheet.detent,
              builder: (context, detent, _) => TextButton(
                onPressed: detent == 2 ? sheet.collapse : sheet.expand,
                child: Text(detent == 2 ? 'Collapse' : 'Expand'),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          controller: OmniSheet.of(context).scrollController,
          itemCount: 30,
          itemBuilder: (context, i) => ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text('Place #${i + 1}'),
            subtitle: Text('${(i + 1) * 120} m away'),
          ),
        ),
      ),
    ],
  );
}
