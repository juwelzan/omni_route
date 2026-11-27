import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:omni_responsive/omni_responsive.dart';

/// Every widget test fails if a tracked object (Element, State, Route,
/// ChangeNotifier, Image…) is not disposed, or is not garbage-collected
/// after disposal.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withTrackedAll();
  // App-wide singletons start fresh in every test (each test sets its own
  // SharedPreferences mock values).
  setUp(() {
    OmniPreferences.debugReset();
    OmniTextScale.debugReset();
  });
  await testMain();
}
