part of 'omni_bottom_navigation.dart';

/// One action of an [OmniContextualActionBar].
@immutable
class OmniContextualAction {
  /// Creates an action; [label] is its tooltip and screen-reader name.
  const OmniContextualAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  /// Action icon.
  final Widget icon;

  /// Tooltip, overflow-menu text and screen-reader name.
  final String label;

  /// Called on tap; `null` disables the action.
  final VoidCallback? onPressed;

  /// Tints the action with the theme's error colour (delete, remove…).
  final bool destructive;
}

/// Selection-mode actions that take the place of the bottom navigation bar
/// (Gmail, Files, Photos): while [active], the bar fades out and an action
/// bar with a close button, a [title] ("3 selected") and [actions] slides in
/// over the same slot.
///
/// ```dart
/// Scaffold(
///   bottomNavigationBar: OmniContextualActionBar(
///     active: selected.isNotEmpty,
///     title: '${selected.length} selected',
///     onClose: clearSelection,
///     actions: [
///       OmniContextualAction(
///         icon: const Icon(Icons.share_outlined),
///         label: 'Share',
///         onPressed: share,
///       ),
///       OmniContextualAction(
///         icon: const Icon(Icons.delete_outline),
///         label: 'Delete',
///         destructive: true,
///         onPressed: delete,
///       ),
///     ],
///     child: OmniBottomNavigationBar(items: [...]),
///   ),
/// )
/// ```
///
/// - The navigation bar stays mounted (its state, indicator and route sync
///   are untouched) but can't be tapped or focused, and screen readers skip
///   it.
/// - Actions that don't fit move into an overflow menu.
/// - With [onClose], the system back button leaves selection mode first.
/// - Reduced motion swaps the bars instantly.
class OmniContextualActionBar extends StatefulWidget {
  /// Wraps the navigation bar [child].
  const OmniContextualActionBar({
    super.key,
    required this.active,
    required this.actions,
    required this.child,
    this.title,
    this.onClose,
    this.backgroundColor,
    this.foregroundColor,
    this.margin = EdgeInsets.zero,
    this.borderRadius = 0,
    this.height = 64,
    this.duration = const Duration(milliseconds: 240),
  }) : assert(height > 0),
       assert(borderRadius >= 0);

  /// Whether selection mode is on.
  final bool active;

  /// The actions, most important first.
  final List<OmniContextualAction> actions;

  /// The navigation bar shown while not [active].
  final Widget child;

  /// Usually the selection count, e.g. "3 selected".
  final String? title;

  /// Leaves selection mode (close button and system back).
  final VoidCallback? onClose;

  /// Bar colour (default: the theme's `surfaceContainerHigh`).
  final Color? backgroundColor;

  /// Icon and text colour (default: `onSurface`).
  final Color? foregroundColor;

  /// Space around the bar (match a floating navigation bar).
  final EdgeInsetsGeometry margin;

  /// Corner radius (match a floating navigation bar).
  final double borderRadius;

  /// Bar height above the bottom safe area.
  final double height;

  /// Swap animation length.
  final Duration duration;

  @override
  State<OmniContextualActionBar> createState() =>
      _OmniContextualActionBarState();
}

class _OmniContextualActionBarState extends State<OmniContextualActionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.active ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));

  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _swap,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(OmniContextualActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _swap.duration = widget.duration;
    if (widget.active != oldWidget.active) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduce) {
        _swap.value = widget.active ? 1 : 0;
      } else if (widget.active) {
        _swap.forward();
      } else {
        _swap.reverse();
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _swap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showing = _swap.value > 0;
    final nav = FadeTransition(
      opacity: ReverseAnimation(_curve),
      child: IgnorePointer(
        ignoring: widget.active,
        child: ExcludeFocus(
          excluding: widget.active,
          child: ExcludeSemantics(
            excluding: widget.active,
            child: widget.child,
          ),
        ),
      ),
    );
    Widget result = Stack(
      alignment: Alignment.bottomCenter,
      children: [
        nav,
        if (showing)
          FadeTransition(
            opacity: _curve,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(_curve),
              child: IgnorePointer(
                ignoring: !widget.active,
                child: _ContextualBar(config: widget),
              ),
            ),
          ),
      ],
    );
    if (widget.onClose != null) {
      result = PopScope(
        canPop: !widget.active,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && widget.active) widget.onClose!();
        },
        child: result,
      );
    }
    return result;
  }
}

class _ContextualBar extends StatelessWidget {
  const _ContextualBar({required this.config});

  final OmniContextualActionBar config;

  static const double _slot = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );
    final bg = config.backgroundColor ?? scheme.surfaceContainerHigh;
    final fg = config.foregroundColor ?? scheme.onSurface;
    final margin = config.margin.resolve(Directionality.of(context));
    final floating = margin != EdgeInsets.zero;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final radius = BorderRadius.circular(config.borderRadius);

    Widget bar = LayoutBuilder(
      builder: (context, constraints) {
        final hasClose = config.onClose != null;
        final hasTitle = config.title != null && config.title!.isNotEmpty;
        // Room for actions after the close button and a readable title.
        final reserved = (hasClose ? _slot : 0) + (hasTitle ? 96 : 0) + 16;
        var fit = ((constraints.maxWidth - reserved) / _slot).floor();
        fit = math.max(0, fit);
        final actions = config.actions;
        final overflowing = actions.length > fit;
        final visible = overflowing
            ? actions.take(math.max(0, fit - 1)).toList()
            : actions;
        final hidden = overflowing
            ? actions.skip(visible.length).toList()
            : const <OmniContextualAction>[];

        Color tint(OmniContextualAction a) => a.destructive ? scheme.error : fg;

        return Row(
          children: [
            const SizedBox(width: 4),
            if (hasClose)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: fg,
                tooltip: l10n?.closeButtonTooltip ?? 'Close',
                onPressed: config.onClose,
              ),
            if (hasTitle)
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(start: hasClose ? 4 : 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      config.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: fg),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            for (final a in visible)
              IconButton(
                icon: a.icon,
                color: tint(a),
                tooltip: a.label,
                onPressed: a.onPressed,
              ),
            if (hidden.isNotEmpty)
              PopupMenuButton<int>(
                icon: Icon(Icons.more_vert_rounded, color: fg),
                tooltip: l10n?.showMenuTooltip ?? 'More',
                onSelected: (i) => hidden[i].onPressed?.call(),
                itemBuilder: (_) => [
                  for (var i = 0; i < hidden.length; i++)
                    PopupMenuItem<int>(
                      value: i,
                      enabled: hidden[i].onPressed != null,
                      child: Row(
                        children: [
                          IconTheme.merge(
                            data: IconThemeData(color: tint(hidden[i])),
                            child: hidden[i].icon,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            hidden[i].label,
                            style: TextStyle(color: tint(hidden[i])),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(width: 4),
          ],
        );
      },
    );

    bar = Material(
      color: bg,
      borderRadius: floating ? radius : null,
      clipBehavior: floating ? Clip.antiAlias : Clip.none,
      elevation: floating ? 3 : 0,
      child: Padding(
        padding: EdgeInsets.only(bottom: floating ? 0 : safeBottom),
        child: SizedBox(height: config.height, child: bar),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: config.title,
      child: Padding(
        padding: floating
            ? margin.copyWith(bottom: margin.bottom + safeBottom)
            : EdgeInsets.zero,
        child: bar,
      ),
    );
  }
}
