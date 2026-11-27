import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'omni_debug_report.dart';
import 'omni_localization.dart';
import 'omni_preferences.dart';

/// The user's preferred text size. Every `Text` in the app scales with it,
/// on top of the OS accessibility setting — no per-widget code needed.
enum OmniTextSize {
  /// 85 %.
  small(0.85),

  /// 100 % (default).
  medium(1.0),

  /// 115 %.
  large(1.15),

  /// 130 %.
  extraLarge(1.3);

  const OmniTextSize(this.factor);

  /// Multiplier applied to all text.
  final double factor;

  /// The preset whose [factor] equals [factor], or `null` for a custom value.
  static OmniTextSize? fromFactor(double factor) {
    for (final s in values) {
      if ((s.factor - factor).abs() < 0.001) return s;
    }
    return null;
  }

  /// Localized name (English, Bengali, Arabic, Hindi; English otherwise).
  String label([OmniLocaleState? locale]) {
    final state = locale ?? OmniText.state;
    return switch (this) {
      small => OmniText.resolveTextFor(
        state,
        en: 'Small',
        bn: 'ছোট',
        ar: 'صغير',
        hi: 'छोटा',
      ),
      medium => OmniText.resolveTextFor(
        state,
        en: 'Medium',
        bn: 'মাঝারি',
        ar: 'متوسط',
        hi: 'मध्यम',
      ),
      large => OmniText.resolveTextFor(
        state,
        en: 'Large',
        bn: 'বড়',
        ar: 'كبير',
        hi: 'बड़ा',
      ),
      extraLarge => OmniText.resolveTextFor(
        state,
        en: 'Extra large',
        bn: 'অনেক বড়',
        ar: 'كبير جدًا',
        hi: 'बहुत बड़ा',
      ),
    };
  }
}

/// App-wide text size settings for `OmniApp` / `OmniResponsiveApp`.
@immutable
class OmniTextScaling {
  /// Creates the settings. All fields are optional.
  const OmniTextScaling({
    this.initialSize = OmniTextSize.medium,
    this.persist = true,
    this.storageKey = 'default',
    this.minFactor = 0.8,
    this.maxFactor = 1.6,
  }) : assert(minFactor > 0 && maxFactor >= minFactor);

  /// Size used until the user picks one (and when nothing is saved).
  final OmniTextSize initialSize;

  /// Remember the user's choice across launches.
  final bool persist;

  /// Separates saved values of several apps or profiles.
  final String storageKey;

  /// Lowest factor [OmniTextScaleController.setFactor] accepts.
  final double minFactor;

  /// Highest factor [OmniTextScaleController.setFactor] accepts.
  final double maxFactor;

  @override
  bool operator ==(Object other) =>
      other is OmniTextScaling &&
      other.initialSize == initialSize &&
      other.persist == persist &&
      other.storageKey == storageKey &&
      other.minFactor == minFactor &&
      other.maxFactor == maxFactor;

  @override
  int get hashCode =>
      Object.hash(initialSize, persist, storageKey, minFactor, maxFactor);
}

/// Holds the user's text-size factor; saved and restored automatically.
///
/// Apps normally use the global one through [OmniTextScale] or
/// `context.setTextSize(...)`; pass your own to `textScaleController:` on the
/// app to keep it isolated (tests, multi-profile apps).
///
/// A plain listenable rather than a `ChangeNotifier`: the global instance
/// lives for the whole app and needs no `dispose`.
class OmniTextScaleController implements ValueListenable<double> {
  /// Creates a controller starting at [initial].
  OmniTextScaleController({
    OmniTextSize initial = OmniTextSize.medium,
    bool persist = true,
    String storageKey = 'default',
    double minFactor = 0.8,
    double maxFactor = 1.6,
  }) : _value = initial.factor,
       // ignore: prefer_initializing_formals (private named parameter)
       _persist = persist,
       // ignore: prefer_initializing_formals (private named parameter)
       _storageKey = storageKey,
       // ignore: prefer_initializing_formals (private named parameter)
       _minFactor = minFactor,
       // ignore: prefer_initializing_formals (private named parameter)
       _maxFactor = maxFactor;

  double _value;
  bool _persist;
  String _storageKey;
  double _minFactor;
  double _maxFactor;
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  bool _hydrated = false;
  bool _disposed = false;
  int _userEdits = 0;

  /// Whether choices are saved.
  bool get persist => _persist;

  /// Storage separation key.
  String get storageKey => _storageKey;

  /// Lowest accepted factor.
  double get minFactor => _minFactor;

  /// Highest accepted factor.
  double get maxFactor => _maxFactor;

  /// Key the factor is saved under.
  String get prefKey => 'omni_route.textScale.$_storageKey.factor';

  @override
  double get value => _value;

  /// Current factor (1.0 = medium).
  double get factor => _value;

  /// Current preset, or `null` for a custom factor.
  OmniTextSize? get size => OmniTextSize.fromFactor(_value);

  void _set(double next) {
    if (next == _value) return;
    _value = next;
    for (final l in List<VoidCallback>.of(_listeners)) {
      if (_listeners.contains(l)) l();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Picks a preset size.
  void setSize(OmniTextSize size) => setFactor(size.factor);

  /// Sets any factor (clamped to [minFactor]..[maxFactor]), e.g. a slider.
  void setFactor(double factor) {
    if (_disposed) return;
    final next = factor.clamp(_minFactor, _maxFactor).toDouble();
    _userEdits++;
    if (next == _value) return;
    _set(next);
    if (_persist) unawaited(_save(next));
  }

  /// Back to [initial] and forget the saved value.
  Future<void> reset({OmniTextSize initial = OmniTextSize.medium}) async {
    if (_disposed) return;
    _userEdits++;
    _set(initial.factor);
    try {
      await (await OmniPreferences.load()).remove(prefKey);
    } catch (e, st) {
      omniReportRecovered('textScale.reset', e, st);
    }
  }

  /// Restores the saved factor — synchronously when preferences are already
  /// loaded ([OmniPreferences.preload]), so the first frame is right.
  Future<void> hydrate() async {
    if (!_persist || _hydrated || _disposed) return;
    _hydrated = true;
    if (OmniPreferences.cached case final prefs?) {
      _restoreFrom(prefs);
      return;
    }
    final editsBefore = _userEdits;
    try {
      final prefs = await OmniPreferences.load();
      if (_disposed || _userEdits != editsBefore) return;
      _restoreFrom(prefs);
    } catch (e, st) {
      omniReportRecovered('textScale.hydrate', e, st);
    }
  }

  void _restoreFrom(SharedPreferences prefs) {
    final saved = prefs.getDouble(prefKey);
    if (saved == null || saved <= 0) return;
    _set(saved.clamp(_minFactor, _maxFactor).toDouble());
  }

  Future<void> _save(double factor) async {
    try {
      await (await OmniPreferences.load()).setDouble(prefKey, factor);
    } catch (e, st) {
      omniReportRecovered('textScale.save', e, st);
    }
  }

  /// Stops notifying; later changes are ignored.
  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}

/// Global text size, usable without a `BuildContext`:
///
/// ```dart
/// OmniTextScale.setSize(OmniTextSize.large);
/// ```
abstract final class OmniTextScale {
  static final OmniTextScaleController _global = OmniTextScaleController();
  static OmniTextScaling? _attached;

  /// The app-wide controller (used when no controller is passed to the app).
  static OmniTextScaleController get controller => _global;

  /// Current factor.
  static double get factor => _global.value;

  /// Current preset, or `null` for a custom factor.
  static OmniTextSize? get size => _global.size;

  /// Picks a preset size for the whole app.
  static void setSize(OmniTextSize size) => _global.setSize(size);

  /// Sets a custom factor for the whole app.
  static void setFactor(double factor) => _global.setFactor(factor);

  /// Applies [config] to the global controller and restores the saved size
  /// (called by the app host).
  static void attach(OmniTextScaling config) {
    if (_attached == config) return;
    final keyChanged =
        _attached != null && _attached!.storageKey != config.storageKey;
    _attached = config;
    final c = _global
      .._persist = config.persist
      .._storageKey = config.storageKey
      .._minFactor = config.minFactor
      .._maxFactor = config.maxFactor;
    if (keyChanged) c._hydrated = false;
    if (c._userEdits == 0 && !c._hydrated) c._set(config.initialSize.factor);
    unawaited(c.hydrate());
  }

  /// Resets the global state (tests).
  @visibleForTesting
  static void debugReset() {
    _attached = null;
    _global
      .._listeners.clear()
      .._value = OmniTextSize.medium.factor
      .._persist = true
      .._storageKey = 'default'
      .._minFactor = 0.8
      .._maxFactor = 1.6
      .._hydrated = false
      .._disposed = false
      .._userEdits = 0;
  }
}

/// Provides the active [OmniTextScaleController] to the tree. Inserted by the
/// app host; read it through `context.textScaleController`.
class OmniTextScaleScope extends InheritedNotifier<OmniTextScaleController> {
  /// Exposes [controller] to [child].
  const OmniTextScaleScope({
    super.key,
    required OmniTextScaleController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The nearest controller without subscribing to changes.
  static OmniTextScaleController? maybeControllerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OmniTextScaleScope>()?.notifier;

  /// The current factor; the caller rebuilds when it changes.
  static double factorOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OmniTextScaleScope>()
          ?.notifier
          ?.value ??
      OmniTextScale.factor;
}

/// Text size shortcuts on any `BuildContext`.
extension OmniTextScaleContext on BuildContext {
  /// The controller in use (the app's, or the global one).
  OmniTextScaleController get textScaleController =>
      OmniTextScaleScope.maybeControllerOf(this) ?? OmniTextScale.controller;

  /// The user's text size factor; rebuilds this widget when it changes.
  double get textSizeFactor => OmniTextScaleScope.factorOf(this);

  /// The user's text size preset (`null` for a custom factor); rebuilds this
  /// widget when it changes.
  OmniTextSize? get textSize => OmniTextSize.fromFactor(textSizeFactor);

  /// Changes the text size of the whole app (saved automatically).
  void setTextSize(OmniTextSize size) => textScaleController.setSize(size);

  /// Sets a custom text size factor for the whole app.
  void setTextSizeFactor(double factor) =>
      textScaleController.setFactor(factor);
}

/// Ready-made text size control: `A` buttons in increasing sizes, with
/// localized names. Drop it into any settings screen.
class OmniTextSizePicker extends StatelessWidget {
  /// Creates the picker.
  const OmniTextSizePicker({
    super.key,
    this.sizes = OmniTextSize.values,
    this.showLabels = false,
  });

  /// Which presets to offer.
  final List<OmniTextSize> sizes;

  /// Show the localized name under each `A`.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final current = context.textSize;
    final locale = OmniL10nScope.maybeOf(context)?.notifier?.value;
    return SegmentedButton<OmniTextSize>(
      showSelectedIcon: false,
      emptySelectionAllowed: current == null,
      segments: [
        for (final size in sizes)
          ButtonSegment<OmniTextSize>(
            value: size,
            tooltip: size.label(locale),
            label: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The glyph shows the size itself, so it must not scale
                // with the setting it represents.
                Text(
                  'A',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 13 * size.factor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showLabels)
                  Text(
                    size.label(locale),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
      ],
      selected: {?current},
      onSelectionChanged: (s) {
        if (s.isNotEmpty) context.setTextSize(s.first);
      },
    );
  }
}
