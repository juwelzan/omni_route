/// Highly customizable multi-mode mobile bottom navigation bar with
/// CollectUI-inspired styles (`floating`, `floatingBubble`, `slidingPill`,
/// `curvedNotch`, `centerFabNotch`, `splitIsland`, `glass`, `glowingDot`,
/// `topIndicator`, `floatingCircles`, `materialPill`, `cupertino`).
///
/// Works directly inside Flutter's `Scaffold(bottomNavigationBar: ...)`,
/// floating inside `Stack` / `Scaffold(extendBody: true)`, or embedded
/// directly inside `omni_route`'s `OmniPage` and `OmniStatefulShell`.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../omni_colors.dart';

part 'omni_bottom_navigation_style.dart';
part 'omni_bottom_navigation_notch.dart';
part 'omni_bottom_navigation_painters.dart';
part 'omni_bottom_navigation_bar.dart';
