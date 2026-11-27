part of 'omni_bottom_sheet.dart';

/// Look and feel of an Omni bottom sheet.
enum OmniSheetStyle {
  /// [cupertino] on iOS and macOS, [material] everywhere else (default).
  adaptive,

  /// Material 3: 28dp top corners, drag handle, quick critically-damped
  /// motion, no stretch past the top.
  material,

  /// iOS: grabber, spring motion, rubber-band stretch past the top, the
  /// status bar area left visible above the largest detent.
  cupertino,

  /// An iOS-styled floating card with generous continuous corners, crisp rim
  /// border, circular glass close button, spring motion and bouncing physics.
  floating;

  /// The concrete style for [platform] ([adaptive] resolved).
  OmniSheetStyle resolve(TargetPlatform platform) => switch (this) {
    adaptive => switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => cupertino,
      _ => material,
    },
    _ => this,
  };
}
