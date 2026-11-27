/// Omni bottom sheet: `showOmniBottomSheet`, `OmniSheetRoute` and friends.
///
/// One library split into parts by responsibility:
/// - `omni_sheet_style.dart`, `omni_sheet_detent.dart`, `omni_sheet_motion.dart`
///   — the public configuration types (and the spring / rubber-band math);
/// - `omni_sheet_route.dart` — `showOmniBottomSheet` and the route;
/// - `omni_scalable_sheet.dart` — `OmniScalableSheet`, the in-page sheet;
/// - `omni_sheet_host.dart` — what both hosts give the shared view;
/// - `omni_sheet_controller.dart` — `OmniSheet.of(context)`;
/// - `omni_sheet_view.dart` — the sheet widget: gestures, detents, layout values;
/// - `omni_sheet_look.dart` — colors and the drag handle;
/// - `omni_sheet_scroll.dart` — scroll views inside handing drags to the sheet;
/// - `omni_sheet_render.dart` — the paint-only render object that moves it.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../omni_colors.dart';

part 'omni_sheet_style.dart';
part 'omni_sheet_detent.dart';
part 'omni_sheet_motion.dart';
part 'omni_sheet_controller.dart';
part 'omni_sheet_host.dart';
part 'omni_sheet_route.dart';
part 'omni_scalable_sheet.dart';
part 'omni_sheet_view.dart';
part 'omni_sheet_look.dart';
part 'omni_sheet_scroll.dart';
part 'omni_sheet_render.dart';
