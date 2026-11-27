import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:omni_responsive/omni_responsive.dart';

/// Immutable telemetry breadcrumb stored in a bounded ring buffer for crash
/// diagnostics without runtime listeners or UI rebuilds.
@immutable
class OmniBreadcrumb {
  /// Creates a diagnostic breadcrumb entry.
  const OmniBreadcrumb({
    required this.timestamp,
    required this.category,
    required this.message,
    this.routePath,
    this.device,
    this.data,
  });

  /// UTC or local wall-clock instant when the event occurred.
  final DateTime timestamp;

  /// Coarse category such as `'navigation'`, `'flow'`, `'bloc'`, `'error'`, or
  /// `'custom'`.
  final String category;

  /// Human-readable event summary.
  final String message;

  /// Canonical active route pattern if known.
  final String? routePath;

  /// Active responsive [OmniDeviceType] snapshot at the moment of the event.
  final OmniDeviceType? device;

  /// Optional structured key-value metadata.
  final Map<String, Object?>? data;

  /// Compact single-line representation used in [OmniBreadcrumbRecorder.export].
  String formatLine() {
    final buf = StringBuffer()
      ..write('[${timestamp.toIso8601String()}] [$category]');
    if (device != null) buf.write(' (${device!.name})');
    if (routePath != null) buf.write(' $routePath');
    buf.write(': $message');
    if (data != null && data!.isNotEmpty) {
      buf.write(' | $data');
    }
    return buf.toString();
  }
}

/// Fixed-capacity O(1) ring buffer holding recent navigation and error events
/// with strict memory bounds and zero UI rebuild overhead.
class OmniBreadcrumbRecorder {
  /// Creates a recorder retaining at most [maxEntries] breadcrumbs (`0` stops
  /// recording completely with zero heap allocations).
  OmniBreadcrumbRecorder({this.maxEntries = 25})
    : assert(maxEntries >= 0),
      _entries = maxEntries > 0 ? ListQueue<OmniBreadcrumb>(maxEntries) : null;

  /// Maximum entries retained before oldest entries are evicted in O(1).
  final int maxEntries;

  final ListQueue<OmniBreadcrumb>? _entries;

  /// Unmodifiable snapshot ordered oldest -> newest.
  List<OmniBreadcrumb> get entries =>
      _entries == null ? const [] : List<OmniBreadcrumb>.unmodifiable(_entries);

  /// Appends [crumb], discarding the oldest item if [maxEntries] is reached.
  void record(OmniBreadcrumb crumb) {
    final queue = _entries;
    if (queue == null || maxEntries <= 0) return;
    if (queue.length >= maxEntries) {
      queue.removeFirst();
    }
    queue.addLast(crumb);
  }

  /// Convenience helper recording a typed event cleanly.
  void add(
    String message, {
    String category = 'custom',
    String? routePath,
    OmniDeviceType? device,
    Map<String, Object?>? data,
  }) {
    if (_entries == null || maxEntries <= 0) return;
    record(
      OmniBreadcrumb(
        timestamp: DateTime.now(),
        category: category,
        message: message,
        routePath: routePath,
        device: device,
        data: data,
      ),
    );
  }

  /// Drops all retained entries cleanly on dispose/reset.
  void clear() => _entries?.clear();

  /// Exports a concise diagnostic crash/bug report string combining optional
  /// [currentLocation], [device], [stackPaths], and [error].
  String export({
    String? currentLocation,
    OmniDeviceType? device,
    List<String> stackPaths = const [],
    Object? error,
    StackTrace? stackTrace,
  }) {
    final out = StringBuffer()
      ..writeln('=== OmniRoute Diagnostics ===')
      ..writeln(
        'platform=${defaultTargetPlatform.name} kIsWeb=$kIsWeb'
        '${device != null ? ' device=${device.name}' : ''}',
      );
    if (currentLocation != null) {
      out.writeln('location=$currentLocation');
    }
    if (stackPaths.isNotEmpty) {
      out.writeln('stack=[${stackPaths.join(' -> ')}]');
    }
    if (error != null) {
      out.writeln('error=$error');
    }
    final list = _entries;
    if (list != null && list.isNotEmpty) {
      out.writeln('breadcrumbs (${list.length}):');
      for (final b in list) {
        out.writeln('  ${b.formatLine()}');
      }
    }
    if (stackTrace != null) {
      out.writeln('stackTrace:');
      out.writeln(stackTrace.toString());
    }
    return out.toString();
  }
}
