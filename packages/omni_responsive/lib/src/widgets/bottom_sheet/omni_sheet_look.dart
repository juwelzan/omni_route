part of 'omni_bottom_sheet.dart';

class _SheetLook {
  const _SheetLook(
    this.background,
    this.handle,
    this.divider,
    this.cupertinoText,
  );

  final Color background;
  final Color handle;
  final Color divider;
  final bool cupertinoText;

  static _SheetLook resolve(
    BuildContext context,
    OmniSheetStyle style,
    _SheetConfig route,
    bool cupertinoApp,
  ) {
    final omni = Theme.of(context).extension<OmniColors>();
    Color background, handle, divider;
    if (omni != null) {
      background = omni.bottomSheetColor;
      divider = omni.dividerColor;
      handle = style == OmniSheetStyle.material
          ? omni.borderColor
          : omni.hintTextColor.withValues(alpha: 0.55);
    } else if (cupertinoApp) {
      background = CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground,
        context,
      );
      handle = CupertinoDynamicColor.resolve(
        CupertinoColors.systemGrey3,
        context,
      );
      divider = CupertinoDynamicColor.resolve(
        CupertinoColors.separator,
        context,
      );
    } else {
      final theme = Theme.of(context);
      background =
          theme.bottomSheetTheme.modalBackgroundColor ??
          theme.colorScheme.surfaceContainerLow;
      handle =
          theme.bottomSheetTheme.dragHandleColor ??
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
      divider = theme.colorScheme.outlineVariant;
    }
    return _SheetLook(
      route.backgroundColor ?? background,
      route.handleColor ?? handle,
      divider,
      cupertinoApp,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({
    required this.style,
    required this.color,
    required this.hint,
    required this.onTap,
  });

  final OmniSheetStyle style;
  final Color color;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final material = style == OmniSheetStyle.material;
    final width = material ? 32.0 : 36.0;
    final thickness = material ? 4.0 : 5.0;
    return Semantics(
      button: true,
      label: hint,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: material ? 36 : 20,
          child: Align(
            alignment: material ? Alignment.center : const Alignment(0, -0.4),
            child: Container(
              width: width,
              height: thickness,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(thickness),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pinned header: always drags the sheet (it is outside the scroll
/// view) and shows a separator while content is scrolled under it.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.scrolled,
    required this.dividerColor,
    required this.child,
  });

  final ValueListenable<bool> scrolled;
  final Color dividerColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      child,
      // Space is always reserved, so the separator never shifts content.
      ValueListenableBuilder<bool>(
        valueListenable: scrolled,
        builder: (context, isScrolled, divider) => AnimatedOpacity(
          opacity: isScrolled ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: divider,
        ),
        child: SizedBox(height: 1, child: ColoredBox(color: dividerColor)),
      ),
    ],
  );
}
