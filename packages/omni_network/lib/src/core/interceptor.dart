import 'dart:async';

import 'omni_network_exception.dart';
import 'omni_request.dart';
import 'omni_response.dart';

/// Hooks around every request of an `OmniNetwork` client.
///
/// Override only what you need. `onRequest` runs in list order;
/// `onResponse` and `onError` run in reverse order (like nested
/// middleware). Interceptors are transport-independent: they never see
/// Dio types.
///
/// ```dart
/// final class AppVersion extends OmniInterceptor {
///   @override
///   OmniRequest onRequest(OmniRequest r) => r.withHeader('X-App', '1.4.0');
/// }
/// ```
///
/// Throwing an [OmniNetworkException] fails the request with it; any other
/// [Exception] becomes a [RequestFailure]. Exceptions thrown from [onError]
/// are ignored so the original failure is preserved.
abstract class OmniInterceptor {
  /// Const constructor for subclasses.
  const OmniInterceptor();

  /// Creates an inline interceptor from callback functions without subclassing.
  const factory OmniInterceptor.inline({
    FutureOr<OmniRequest> Function(OmniRequest request)? onRequest,
    FutureOr<OmniRawResponse> Function(
      OmniRequest request,
      OmniRawResponse response,
    )?
    onResponse,
    FutureOr<void> Function(OmniRequest request, OmniNetworkException error)?
    onError,
  }) = _InlineInterceptor;

  /// Returns the request to send (e.g. with an added header).
  FutureOr<OmniRequest> onRequest(OmniRequest request) => request;

  /// Returns the response to hand back (any status code).
  FutureOr<OmniRawResponse> onResponse(
    OmniRequest request,
    OmniRawResponse response,
  ) => response;

  /// Observes a failure. The failure is rethrown afterwards.
  FutureOr<void> onError(OmniRequest request, OmniNetworkException error) {}
}

final class _InlineInterceptor extends OmniInterceptor {
  const _InlineInterceptor({this._onRequest, this._onResponse, this._onError});

  final FutureOr<OmniRequest> Function(OmniRequest request)? _onRequest;
  final FutureOr<OmniRawResponse> Function(
    OmniRequest request,
    OmniRawResponse response,
  )?
  _onResponse;
  final FutureOr<void> Function(
    OmniRequest request,
    OmniNetworkException error,
  )?
  _onError;

  @override
  FutureOr<OmniRequest> onRequest(OmniRequest request) =>
      _onRequest == null ? request : _onRequest(request);

  @override
  FutureOr<OmniRawResponse> onResponse(
    OmniRequest request,
    OmniRawResponse response,
  ) => _onResponse == null ? response : _onResponse(request, response);

  @override
  FutureOr<void> onError(OmniRequest request, OmniNetworkException error) =>
      _onError == null ? null : _onError(request, error);
}
