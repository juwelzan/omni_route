part of 'omni_network.dart';

/// Low-level calls on [OmniNetwork], available with
/// `import 'package:omni_network/advanced.dart'`.
///
/// Apps normally use the verbs (`get`, `post`, …) instead.
extension OmniNetworkAdvanced on OmniNetwork {
  /// Sends [request] and returns the raw response for **any** status code
  /// (no decoding, no status check).
  Future<OmniRawResponse> sendRaw(OmniRequest request) => _sendRaw(request);

  /// Sends [request] and decodes a 2xx body into `T` (see `get`).
  Future<OmniResponse<T>> send<T>(
    OmniRequest request, {
    JsonDecoder<T>? decoder,
    ResponseAdapter? adapter,
  }) => _send<T>(request, decoder: decoder, adapter: adapter);

  /// Like [send] for a JSON array of objects.
  Future<OmniResponse<List<T>>> sendList<T>(
    OmniRequest request, {
    JsonDecoder<T>? decoder,
    ResponseAdapter? adapter,
  }) => _sendList<T>(request, decoder: decoder, adapter: adapter);

  /// Opens a long-lived streamed response (e.g. Server-Sent Events) through
  /// the full pipeline; see `OmniStreamResponse`.
  Future<OmniStreamResponse> openStream(
    OmniRequest request, {
    Duration? timeout,
    Duration? idleTimeout,
  }) => _openStream(request, timeout: timeout, idleTimeout: idleTimeout);

  /// Builds the [TransportRequest] for [request] without sending it.
  TransportRequest resolve(OmniRequest request) => _resolve(request);

  /// [request] as a `curl` command with this client's base URL and default
  /// headers. Secrets are redacted unless [redact] is `false`. Tokens added
  /// by `auth` are not included (they are added at send time).
  String toCurl(OmniRequest request, {bool redact = true}) =>
      curlFor(_resolve(request), redact: redact, redactor: redactor);
}
