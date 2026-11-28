import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

/// Interactive showcase of all 12 CollectUI-inspired [OmniBottomNavigationStyle]
/// modes, live customization toggles, scroll-to-hide, gradient overrides, and
/// direct `OmniPage(bottomNavigationBar: ...)` embedding.
class BottomNavDemoScreen extends OmniStatefulWidget {
  /// Creates the interactive bottom navigation demo screen.
  const BottomNavDemoScreen({super.key});

  @override
  String get routePath => '/bottom-nav-demo';

  @override
  String get title => 'Bottom Navigation Bar';

  @override
  State<BottomNavDemoScreen> createState() => _BottomNavDemoScreenState();
}

class _BottomNavDemoScreenState extends OmniState<BottomNavDemoScreen> {
  final _scrollController = ScrollController();
  final _navController = OmniBottomNavigationController(initialIndex: 0);

  OmniBottomNavigationStyle _style = OmniBottomNavigationStyle.floating;
  OmniBottomNavLabelMode _labelMode = OmniBottomNavLabelMode.styleDefault;
  bool _showCenterAction = true;
  bool _hideOnScroll = false;
  bool _showBadges = true;
  bool _gradientAccent = false;
  bool _enableBlur = false;

  /// Notch customization (curved notch & centre FAB styles). Starts as the
  /// package default; "Reset" goes back to it.
  OmniBottomNavigationNotch _notch = OmniBottomNavigationNotch.standard;

  bool get _hasNotch =>
      _style == OmniBottomNavigationStyle.curvedNotch ||
      _style == OmniBottomNavigationStyle.centerFabNotch;

  @override
  void dispose() {
    _scrollController.dispose();
    _navController.dispose();
    super.dispose();
  }

  List<OmniBottomNavigationItem> _buildItems() => [
    OmniBottomNavigationItem(
      icon: const Icon(Icons.home_outlined),
      selectedIcon: const Icon(Icons.home_rounded),
      label: 'Home',
      activeColor: const Color(0xFF2563EB),
      badgeCount: _showBadges ? 3 : null,
    ),
    OmniBottomNavigationItem(
      icon: const Icon(Icons.explore_outlined),
      selectedIcon: const Icon(Icons.explore_rounded),
      label: 'Discover',
      activeColor: const Color(0xFF7C3AED),
      showDotBadge: _showBadges,
    ),
    OmniBottomNavigationItem(
      icon: const Icon(Icons.wallet_outlined),
      selectedIcon: const Icon(Icons.wallet_rounded),
      label: 'Wallet',
      activeColor: const Color(0xFF059669),
      badgeText: _showBadges ? 'PRO' : null,
    ),
    OmniBottomNavigationItem(
      icon: const Icon(Icons.person_outline_rounded),
      selectedIcon: const Icon(Icons.person_rounded),
      label: 'Profile',
      activeColor: const Color(0xFFD97706),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final colors = context.colors;

    return AnimatedBuilder(
      animation: _navController,
      builder: (context, _) {
        final items = _buildItems();
        final currentTab = items[_navController.index];

        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            title: Text(screenTitle),
            actions: [
              IconButton(
                tooltip: 'Open OmniPage route integration',
                icon: const Icon(Icons.route_rounded),
                onPressed: () => context.to<OmniPageNavFeedScreen>(),
              ),
            ],
          ),
          body: ListView(
            controller: _scrollController,
            padding: tk.pagePadding.copyWith(
              bottom: tk.pagePadding.bottom + 96,
            ),
            children: [
              Card(
                child: Padding(
                  padding: tk.cardPadding,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            (currentTab.activeColor ?? colors.primaryColor)
                                .withValues(alpha: 0.14),
                        foregroundColor:
                            currentTab.activeColor ?? colors.primaryColor,
                        child: currentTab.selectedIcon ?? currentTab.icon,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mode: ${_style.label}',
                              style: context.textStyles.title,
                            ),
                            Text(
                              'Active Tab: ${currentTab.label} · Inside Scaffold(extendBody: true)',
                              style: context.textStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              tk.gapSm,
              FilledButton.tonalIcon(
                icon: const Icon(Icons.layers_outlined),
                label: const Text('Try Direct OmniPage Bottom Bar'),
                onPressed: () => context.to<OmniPageNavFeedScreen>(),
              ),
              tk.gapMd,
              Text(
                'CollectUI & Platform Modes',
                style: context.textStyles.title,
              ),
              tk.gapXs,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in OmniBottomNavigationStyle.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _style == s,
                      onSelected: (_) => setState(() => _style = s),
                    ),
                ],
              ),
              if (_hasNotch) ...[
                tk.gapMd,
                _NotchPanel(
                  notch: _notch,
                  showTravel: _style == OmniBottomNavigationStyle.curvedNotch,
                  onChanged: (n) => setState(() => _notch = n),
                ),
              ],
              tk.gapMd,
              Text('Label Behaviour', style: context.textStyles.title),
              tk.gapXs,
              SegmentedButton<OmniBottomNavLabelMode>(
                segments: const [
                  ButtonSegment(
                    value: OmniBottomNavLabelMode.styleDefault,
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: OmniBottomNavLabelMode.alwaysShow,
                    label: Text('Always'),
                  ),
                  ButtonSegment(
                    value: OmniBottomNavLabelMode.selectedOnly,
                    label: Text('Active'),
                  ),
                  ButtonSegment(
                    value: OmniBottomNavLabelMode.never,
                    label: Text('Icons'),
                  ),
                ],
                selected: {_labelMode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _labelMode = s.first),
              ),
              tk.gapSm,
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Center / Island Action Button'),
                      value: _showCenterAction,
                      onChanged: (v) => setState(() => _showCenterAction = v),
                    ),
                    SwitchListTile(
                      title: const Text('Hide on Scroll Down'),
                      value: _hideOnScroll,
                      onChanged: (v) => setState(() => _hideOnScroll = v),
                    ),
                    SwitchListTile(
                      title: const Text('Live Badges & Dot Indicators'),
                      value: _showBadges,
                      onChanged: (v) => setState(() => _showBadges = v),
                    ),
                    SwitchListTile(
                      title: const Text('Gradient Pill Accent'),
                      value: _gradientAccent,
                      onChanged: (v) => setState(() => _gradientAccent = v),
                    ),
                    SwitchListTile(
                      title: const Text('Enable Frosted Blur (Glass)'),
                      value: _enableBlur,
                      onChanged: (v) => setState(() => _enableBlur = v),
                    ),
                  ],
                ),
              ),
              tk.gapMd,
              Text('Scrollable Feed Preview', style: context.textStyles.title),
              tk.gapXs,
              for (var i = 1; i <= 16; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('$i')),
                      title: Text('Mobile Pattern Card #$i'),
                      subtitle: const Text(
                        'Scroll down to test blur backdrop & hideOnScroll',
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: OmniBottomNavigationBar(
            style: _style,
            labelMode: _labelMode,
            controller: _navController,
            scrollController: _scrollController,
            hideOnScroll: _hideOnScroll,
            enableBlur: _enableBlur,
            notch: _notch,
            indicatorGradient: _gradientAccent
                ? LinearGradient(
                    colors: [colors.primaryColor, colors.secondaryColor],
                  )
                : null,
            activeContentColor: _gradientAccent ? Colors.white : null,
            centerAction: _showCenterAction
                ? OmniBottomNavigationAction(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Quick Create',
                    gradient: LinearGradient(
                      colors: [colors.primaryColor, colors.secondaryColor],
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Center action on ${_style.label}!'),
                        ),
                      );
                    },
                  )
                : null,
            items: items,
          ),
        );
      },
    );
  }
}

/// How the `OmniPage` bars behave while pages change; the example app passes
/// it to `OmniApp.bottomBarTransition`.
final omniPageBarMode = ValueNotifier<OmniPageBarTransition>(
  OmniPageBarTransition.slide,
);

/// Shared bar embedded directly into three [OmniPage] routes without any
/// outer `OmniStatefulShell` or `Scaffold.bottomNavigationBar`.
const omniPageDemoSharedBar = OmniBottomNavigationBar(
  style: OmniBottomNavigationStyle.curvedNotch,
  items: [
    OmniBottomNavigationItem(
      icon: Icon(Icons.dynamic_feed_outlined),
      selectedIcon: Icon(Icons.dynamic_feed_rounded),
      label: 'Feed',
      routePath: '/omni-page-nav/feed',
    ),
    OmniBottomNavigationItem(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome_rounded),
      label: 'Explore',
      routePath: '/omni-page-nav/explore',
    ),
    OmniBottomNavigationItem(
      icon: Icon(Icons.bookmark_outline_rounded),
      selectedIcon: Icon(Icons.bookmark_rounded),
      label: 'Saved',
      routePath: '/omni-page-nav/saved',
    ),
  ],
);

/// Demo Screen 1 hosted directly with `OmniPage(bottomNavigationBar: ...)`.
class OmniPageNavFeedScreen extends OmniStatelessWidget {
  /// Creates the Feed route screen.
  const OmniPageNavFeedScreen({super.key});

  @override
  String get routePath => '/omni-page-nav/feed';

  @override
  Widget build(BuildContext context) => _OmniPageNavBody(
    title: 'OmniPage Direct Feed',
    subtitle: 'Embedded straight inside OmniPage.screen(..., bottomNavigationBar: const OmniBottomNavigationBar(...)) with auto route sync.',
    icon: Icons.dynamic_feed_rounded,
    color: const Color(0xFF2563EB),
  );
}

/// Demo Screen 2 hosted directly with `OmniPage(bottomNavigationBar: ...)`.
class OmniPageNavExploreScreen extends OmniStatelessWidget {
  /// Creates the Explore route screen.
  const OmniPageNavExploreScreen({super.key});

  @override
  String get routePath => '/omni-page-nav/explore';

  @override
  Widget build(BuildContext context) => _OmniPageNavBody(
    title: 'OmniPage Direct Explore',
    subtitle: 'Active tab highlighted & switched by routePath automatically!',
    icon: Icons.auto_awesome_rounded,
    color: const Color(0xFF7C3AED),
  );
}

/// Demo Screen 3 hosted directly with `OmniPage(bottomNavigationBar: ...)`.
class OmniPageNavSavedScreen extends OmniStatelessWidget {
  /// Creates the Saved route screen.
  const OmniPageNavSavedScreen({super.key});

  @override
  String get routePath => '/omni-page-nav/saved';

  @override
  Widget build(BuildContext context) => _OmniPageNavBody(
    title: 'OmniPage Direct Saved',
    subtitle: 'Notice zero Scaffold bottomNavigationBar needed on these pages.',
    icon: Icons.bookmark_rounded,
    color: const Color(0xFF059669),
  );
}

class _OmniPageNavBody extends StatelessWidget {
  const _OmniPageNavBody({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.to<BottomNavDemoScreen>(),
        ),
      ),
      body: ListView(
        padding: tk.pagePadding.copyWith(
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          Card(
            child: Padding(
              padding: tk.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: color.withValues(alpha: 0.14),
                    foregroundColor: color,
                    child: Icon(icon, size: 28),
                  ),
                  tk.gapSm,
                  Text(title, style: context.textStyles.heading),
                  tk.gapXs,
                  Text(subtitle, style: context.textStyles.bodyMuted),
                ],
              ),
            ),
          ),
          tk.gapSm,
          const _PageBarModeCard(),
        ],
      ),
    );
  }
}

/// Picks [omniPageBarMode] and opens a page without a bar.
class _PageBarModeCard extends StatelessWidget {
  const _PageBarModeCard();

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Card(
      child: Padding(
        padding: tk.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bar while pages change', style: context.textStyles.title),
            tk.gapXs,
            Text(
              'Fixed: the bar stays put and only its indicator moves. '
              'With page: the bar travels with each page.',
              style: context.textStyles.bodyMuted,
            ),
            tk.gapSm,
            ValueListenableBuilder<OmniPageBarTransition>(
              valueListenable: omniPageBarMode,
              builder: (context, mode, _) =>
                  SegmentedButton<OmniPageBarTransition>(
                    segments: const [
                      ButtonSegment(
                        value: OmniPageBarTransition.slide,
                        label: Text('Fixed · slide'),
                      ),
                      ButtonSegment(
                        value: OmniPageBarTransition.fade,
                        label: Text('Fixed · fade'),
                      ),
                      ButtonSegment(
                        value: OmniPageBarTransition.withPage,
                        label: Text('With page'),
                      ),
                    ],
                    selected: {mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => omniPageBarMode.value = s.first,
                  ),
            ),
            tk.gapSm,
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open a page without a bar'),
              onPressed: () => context.push('/omni-page-nav/details'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A page without a bottom bar: the fixed bar slides (or fades) away while
/// it comes in, and back when it is closed.
class OmniPageNavDetailsScreen extends OmniStatelessWidget {
  /// Creates the details screen.
  const OmniPageNavDetailsScreen({super.key});

  @override
  String get routePath => '/omni-page-nav/details';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Details (no bar)')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This page has no bottom bar. Go back to see it return.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

/// Live controls for [OmniBottomNavigationNotch]: shape, tab-switch motion,
/// orb size, lift, gap, depth and wave width.
class _NotchPanel extends StatelessWidget {
  const _NotchPanel({
    required this.notch,
    required this.showTravel,
    required this.onChanged,
  });

  final OmniBottomNavigationNotch notch;
  final bool showTravel;
  final ValueChanged<OmniBottomNavigationNotch> onChanged;

  // Shown values when a field is left to its default (50 px orb).
  double get _orb => notch.orbSize ?? 50;
  double get _lift => notch.lift ?? _orb * 0.4;
  double get _gap => notch.gap ?? _orb * 0.12;
  double get _depth => notch.depth ?? (_orb - _lift + _gap) * 0.72;

  OmniBottomNavigationNotch _with({
    OmniNotchShape? shape,
    OmniNotchTravel? travel,
    double? orbSize,
    double? lift,
    double? gap,
    double? depth,
    double? spread,
  }) => OmniBottomNavigationNotch(
    shape: shape ?? notch.shape,
    travel: travel ?? notch.travel,
    orbSize: orbSize ?? notch.orbSize,
    lift: lift ?? notch.lift,
    gap: gap ?? notch.gap,
    depth: depth ?? notch.depth,
    spread: spread ?? notch.spread,
  );

  Widget _slider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => Row(
    children: [
      SizedBox(width: 92, child: Text(label)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 40,
        child: Text(value.toStringAsFixed(value < 3 ? 2 : 0)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final isDefault = notch == OmniBottomNavigationNotch.standard;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notch & orb',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: isDefault
                      ? null
                      : () => onChanged(OmniBottomNavigationNotch.standard),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(isDefault ? 'Default' : 'Reset'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SegmentedButton<OmniNotchShape>(
              segments: const [
                ButtonSegment(
                  value: OmniNotchShape.smooth,
                  label: Text('Smooth'),
                ),
                ButtonSegment(
                  value: OmniNotchShape.circular,
                  label: Text('Circle'),
                ),
                ButtonSegment(value: OmniNotchShape.none, label: Text('None')),
              ],
              selected: {notch.shape},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onChanged(_with(shape: s.first)),
            ),
            if (showTravel) ...[
              const SizedBox(height: 8),
              SegmentedButton<OmniNotchTravel>(
                segments: const [
                  ButtonSegment(
                    value: OmniNotchTravel.slide,
                    label: Text('Slide'),
                  ),
                  ButtonSegment(value: OmniNotchTravel.dip, label: Text('Dip')),
                  ButtonSegment(value: OmniNotchTravel.pop, label: Text('Pop')),
                ],
                selected: {notch.travel},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onChanged(_with(travel: s.first)),
              ),
            ],
            const SizedBox(height: 4),
            _slider(
              context,
              'Orb size',
              _orb,
              36,
              72,
              (v) => onChanged(_with(orbSize: v)),
            ),
            _slider(
              context,
              'Lift',
              _lift,
              0,
              40,
              (v) => onChanged(_with(lift: v)),
            ),
            if (notch.shape != OmniNotchShape.none)
              _slider(
                context,
                'Gap',
                _gap,
                0,
                16,
                (v) => onChanged(_with(gap: v)),
              ),
            if (notch.shape == OmniNotchShape.smooth) ...[
              _slider(
                context,
                'Depth',
                _depth,
                0,
                48,
                (v) => onChanged(_with(depth: v)),
              ),
              _slider(
                context,
                'Wave width',
                notch.spread,
                1,
                2.4,
                (v) => onChanged(_with(spread: v)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
