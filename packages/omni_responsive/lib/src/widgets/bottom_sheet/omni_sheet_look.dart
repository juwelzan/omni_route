part of 'omni_bottom_sheet.dart';

class _SheetLook {
  const _SheetLook(this.background, this.handle, this.cupertinoText);

  final Color background;
  final Color handle;
  final bool cupertinoText;

  static _SheetLook resolve(
    BuildContext context,
    OmniSheetStyle style,
    OmniSheetRoute<dynamic> route,
    bool cupertinoApp,
  ) {
    final omni = Theme.of(context).extension<OmniColors>();
    Color background, handle;
    if (omni != null) {
      background = omni.bottomSheetColor;
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
    } else {
      final theme = Theme.of(context);
      background =
          theme.bottomSheetTheme.modalBackgroundColor ??
          theme.colorScheme.surfaceContainerLow;
      handle =
          theme.bottomSheetTheme.dragHandleColor ??
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    }
    return _SheetLook(
      route.backgroundColor ?? background,
      route.handleColor ?? handle,
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
