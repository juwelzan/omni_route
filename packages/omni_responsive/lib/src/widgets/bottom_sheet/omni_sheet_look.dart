part of 'omni_bottom_sheet.dart';

class _SheetLook {
  const _SheetLook({
    required this.background,
    required this.handle,
    required this.divider,
    required this.rimBorder,
    required this.cupertinoText,
    required this.isDark,
  });

  final Color background;
  final Color handle;
  final Color divider;
  final Color rimBorder;
  final bool cupertinoText;
  final bool isDark;

  static _SheetLook resolve(
    BuildContext context,
    OmniSheetStyle style,
    _SheetConfig route,
    bool cupertinoApp,
  ) {
    final theme = Theme.of(context);
    final isDark = cupertinoApp
        ? CupertinoTheme.brightnessOf(context) == Brightness.dark
        : theme.brightness == Brightness.dark;
    final omni = theme.extension<OmniColors>();
    final floating = style == OmniSheetStyle.floating;
    Color background, handle, divider;

    if (omni != null) {
      background = omni.bottomSheetColor;
      divider = omni.dividerColor;
      handle = style == OmniSheetStyle.material
          ? omni.borderColor
          : omni.hintTextColor.withValues(alpha: 0.48);
    } else if (floating) {
      background = isDark
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF4F4F7);
      handle = isDark ? const Color(0xFF545458) : const Color(0xFFC2C2C7);
      divider = isDark ? const Color(0x26FFFFFF) : const Color(0x18000000);
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
      background =
          theme.bottomSheetTheme.modalBackgroundColor ??
          (style == OmniSheetStyle.cupertino
              ? (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9FB))
              : theme.colorScheme.surfaceContainerLow);
      handle =
          theme.bottomSheetTheme.dragHandleColor ??
          (style == OmniSheetStyle.cupertino
              ? (isDark ? const Color(0xFF545458) : const Color(0xFFC2C2C7))
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4));
      divider = style == OmniSheetStyle.cupertino
          ? (isDark ? const Color(0x26FFFFFF) : const Color(0x18000000))
          : theme.colorScheme.outlineVariant;
    }

    final rimBorder = isDark
        ? const Color(0x22FFFFFF)
        : const Color(0xB8FFFFFF);

    return _SheetLook(
      background: route.backgroundColor ?? background,
      handle: route.handleColor ?? handle,
      divider: divider,
      rimBorder: rimBorder,
      cupertinoText: cupertinoApp,
      isDark: isDark,
    );
  }
}

/// নেটিভ iOS / macOS লিকুইড-গ্লাস গোলাকার ক্লোজ (`×`) বাটন।
///
/// স্প্রিং প্রেস-ডাউন স্কেল (`0.86`), হালকা হ্যাপটিক ফিডব্যাক (`HapticFeedback.lightImpact`),
/// হাইলাইট এবং ৪৪×৪৪ হিট টার্গেটসহ iOS-এর মতো আচরণ করে। কাস্টম হেডার বা
/// যেকোনো `OmniBottomSheet`-এ সরাসরি ব্যবহার করা যায়।
class OmniSheetCloseButton extends StatefulWidget {
  /// গোলাকার iOS-স্টাইলের `×` বাটন তৈরি করে।
  const OmniSheetCloseButton({
    super.key,
    this.onPressed,
    this.semanticLabel = 'Close',
    this.size = 38,
    this.backgroundColor,
    this.iconColor,
  });

  /// ট্যাপ কলব্যাক (`null` হলে `OmniSheet` ইন্টারেক্টিভলি বন্ধ করে)।
  final VoidCallback? onPressed;

  /// স্ক্রিন রিডার লেবেল।
  final String semanticLabel;

  /// দৃশ্যমান বৃত্তের ব্যাস (ডিফল্ট `38`, হিট এরিয়া কমপক্ষে `44`)।
  final double size;

  /// কাস্টম ব্যাকগ্রাউন্ড রঙ (ঐচ্ছিক)।
  final Color? backgroundColor;

  /// কাস্টম আইকন রঙ (ঐচ্ছিক)।
  final Color? iconColor;

  @override
  State<OmniSheetCloseButton> createState() => _OmniSheetCloseButtonState();
}

class _OmniSheetCloseButtonState extends State<OmniSheetCloseButton> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool next) {
    if (_pressed != next && mounted) setState(() => _pressed = next);
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }
    final sheet = OmniSheet.maybeOf(context);
    if (sheet is _OmniSheetViewState) {
      unawaited(sheet._dismiss(180));
    } else if (sheet != null) {
      sheet.close();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill =
        widget.backgroundColor ??
        (isDark
            ? const Color(0xEE2C2C2E)
            : (_hovered ? Colors.white : const Color(0xFAFFFFFF)));
    final rim = isDark ? const Color(0x28FFFFFF) : const Color(0x14000000);
    final glyphColor =
        widget.iconColor ??
        (isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E));
    final touchSize = math.max(44.0, widget.size);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onTap: _handleTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _handleTap,
          child: SizedBox.square(
            dimension: touchSize,
            child: Center(
              child: AnimatedScale(
                scale: _pressed ? 0.86 : 1.0,
                duration: Duration(milliseconds: _pressed ? 85 : 190),
                curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 110),
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _pressed
                        ? Color.alphaBlend(
                            isDark
                                ? const Color(0x24FFFFFF)
                                : const Color(0x14000000),
                            fill,
                          )
                        : fill,
                    border: Border.all(color: rim, width: 0.6),
                    boxShadow: _pressed
                        ? const [
                            BoxShadow(
                              color: Color(0x10000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 12,
                              offset: Offset(0, 3),
                            ),
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: Size.square(widget.size * 0.34),
                      painter: _IosCloseGlyphPainter(color: glyphColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosCloseGlyphPainter extends CustomPainter {
  const _IosCloseGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _IosCloseGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({
    required this.style,
    required this.color,
    required this.hint,
    required this.onTap,
    this.compact = false,
  });

  final OmniSheetStyle style;
  final Color color;
  final String hint;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final material = style == OmniSheetStyle.material;
    final width = material
        ? 32.0
        : (style == OmniSheetStyle.floating ? 38.0 : 36.0);
    final thickness = material
        ? 4.0
        : (style == OmniSheetStyle.floating ? 4.5 : 5.0);
    return Semantics(
      button: true,
      label: hint,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!material) HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: compact ? 14 : (material ? 36 : 20),
          child: Align(
            alignment: compact
                ? Alignment.topCenter
                : (material ? Alignment.center : const Alignment(0, -0.4)),
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

class _IosFloatingChrome extends StatelessWidget {
  const _IosFloatingChrome({
    required this.style,
    required this.look,
    required this.showHandle,
    required this.handleHint,
    required this.onHandleTap,
    required this.showCloseButton,
    required this.onClosePressed,
    required this.title,
    required this.trailing,
  });

  final OmniSheetStyle style;
  final _SheetLook look;
  final bool showHandle;
  final String handleHint;
  final VoidCallback onHandleTap;
  final bool showCloseButton;
  final VoidCallback onClosePressed;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = look.cupertinoText
        ? CupertinoTheme.of(context).textTheme.navTitleTextStyle.color
        : theme.colorScheme.onSurface;
    final titleStyle =
        (theme.textTheme.titleMedium ?? const TextStyle(fontSize: 17))
            .copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.35,
              color: textColor,
            );
    final hasTitle = title != null && title!.isNotEmpty;
    final hasBar = showCloseButton || hasTitle || trailing != null;

    if (!hasBar && showHandle) {
      return _SheetHandle(
        style: style,
        color: look.handle,
        hint: handleHint,
        onTap: onHandleTap,
      );
    }

    return SizedBox(
      height: showHandle ? 58 : 54,
      child: Stack(
        children: [
          if (showHandle)
            Positioned(
              left: 0,
              right: 0,
              top: 7,
              child: _SheetHandle(
                style: style,
                color: look.handle,
                hint: handleHint,
                onTap: onHandleTap,
                compact: true,
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            top: showHandle ? 10 : 6,
            bottom: 4,
            child: NavigationToolbar(
              leading: showCloseButton
                  ? OmniSheetCloseButton(onPressed: onClosePressed)
                  : null,
              middle: hasTitle
                  ? Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: titleStyle,
                    )
                  : null,
              trailing: trailing,
              centerMiddle: true,
              middleSpacing: 8,
            ),
          ),
        ],
      ),
    );
  }
}

/// The pinned header: always drags the sheet (it is outside the scroll
/// view) and shows a blurred tint / separator while content is scrolled under it.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.scrolled,
    required this.dividerColor,
    required this.backgroundColor,
    required this.frosted,
    required this.child,
  });

  final ValueListenable<bool> scrolled;
  final Color dividerColor;
  final Color backgroundColor;
  final bool frosted;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: scrolled,
    builder: (context, isScrolled, sep) {
      Widget header = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          // Space is always reserved, so the separator never shifts content.
          AnimatedOpacity(
            opacity: isScrolled ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: sep,
          ),
        ],
      );
      if (frosted && isScrolled) {
        header = ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: ColoredBox(
              color: backgroundColor.withValues(alpha: 0.78),
              child: header,
            ),
          ),
        );
      }
      return header;
    },
    child: SizedBox(
      height: frosted ? 0.5 : 1.0,
      child: ColoredBox(color: dividerColor),
    ),
  );
}
