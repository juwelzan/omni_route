/// Category of an [OmniRouteException].
enum OmniErrorCode {
  /// `screenName` is empty.
  emptyScreenName,

  /// A route path is empty.
  emptyRoutePath,

  /// A route path breaks the path rules.
  invalidRoutePath,

  /// Two routes match the same URLs.
  duplicateRoute,

  /// No route builds the requested screen.
  missingRoute,

  /// A Bloc type has no registered factory.
  missingBlocFactory,

  /// A Bloc type is registered or provided twice.
  duplicateBlocRegistration,

  /// A route parameter is missing or has the wrong type.
  invalidParameter,

  /// Navigation was used with no mounted OmniApp.
  notInitialized,

  /// A stateful screen with Blocs is shown outside a route without
  /// `OmniScreenHost`.
  screenNotHosted,

  /// A configuration OmniRoute does not allow.
  unsupportedConfiguration,

  /// `OmniLifecycle` is mixed into an `OmniStatefulWidget` instead of its
  /// `OmniState`, so its hooks would never run.
  lifecycleOnWidget,

  /// Guards exceeded the maximum number of redirects (redirect loop).
  redirectLoop,
}

/// The single exception type thrown by OmniRoute for configuration and
/// usage mistakes. [message] says what went wrong; [hint] how to fix it.
class OmniRouteException implements Exception {
  /// Creates an exception with a [code], [message] and optional [hint].
  const OmniRouteException(this.code, this.message, {this.hint});

  /// What kind of error this is.
  final OmniErrorCode code;

  /// What went wrong.
  final String message;

  /// How to fix it, when known.
  final String? hint;

  @override
  String toString() {
    final buffer = StringBuffer('OmniRouteException(${code.name}): $message');
    if (hint != null) buffer.write('\nHint: $hint');
    return buffer.toString();
  }
}
