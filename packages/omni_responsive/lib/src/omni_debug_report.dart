import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Records an error that was deliberately recovered from (storage missing,
/// malformed restoration data, …) so it is visible in DevTools / IDE logs
/// instead of vanishing. Debug builds only; free in profile and release.
@internal
void omniReportRecovered(String where, Object error, StackTrace stack) {
  if (!kDebugMode) return;
  developer.log(
    'Recovered in $where',
    name: 'omni_responsive',
    level: 900, // WARNING
    error: error,
    stackTrace: stack,
  );
}
