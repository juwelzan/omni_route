import 'http_status.dart';
import 'omni_response.dart';

/// Base class of every error thrown by OmniNetwork.
sealed class OmniNetworkException implements Exception {
  const OmniNetworkException(this.message, {this.uri, this.cause});

  /// Human-readable description (never contains headers or bodies).
  final String message;

  /// Request URL with the query string removed (it may carry secrets).
  final Uri? uri;

  /// Underlying error, if any.
  final Object? cause;

  /// HTTP status of the response, or `null` when there was no response
  /// (offline, timeout, cancelled…).
  int? get statusCode => null;

  /// No connection to the server, or it did not answer in time.
  bool get isOffline => this is ConnectionFailure || this is TimeoutFailure;

  /// The request timed out.
  bool get isTimeout => this is TimeoutFailure;

  /// The request was cancelled or the client was closed.
  bool get isCancelled => this is CancelledFailure || this is ClosedFailure;

  /// Not signed in or the session expired (401, or the token refresh
  /// failed).
  bool get isUnauthorized => this is AuthFailure || statusCode == 401;

  @override
  String toString() => '$runtimeType: $message${uri == null ? '' : ' ($uri)'}';
}

/// Which phase of a request timed out.
enum TimeoutStage {
  /// Overall request deadline elapsed.
  overall,

  /// Transfer stalled with no bytes sent or received.
  idle,

  /// Establishing the TCP/TLS connection took too long.
  connect,

  /// Sending the request body took too long.
  send,

  /// Waiting for or receiving the response took too long.
  receive,
}

/// Classified cause of a [ConnectionFailure].
enum ConnectionReason {
  /// Unclassified network or socket error.
  unknown,

  /// Device appears offline or no route to host exists.
  noInternet,

  /// DNS host lookup failed.
  dnsFailed,

  /// TLS handshake, certificate, or SSL pin verification failed.
  sslMismatch,

  /// Remote host refused the connection.
  connectionRefused,

  /// Connection was reset or closed mid-transfer.
  connectionReset,
}

/// The request did not finish within its timeout.
final class TimeoutFailure extends OmniNetworkException {
  /// Creates a timeout failure.
  const TimeoutFailure(
    this.timeout, {
    super.uri,
    this.stage = TimeoutStage.overall,
  }) : super('Request timed out after $timeout');

  /// The timeout that elapsed.
  final Duration timeout;

  /// Request phase where the timeout occurred.
  final TimeoutStage stage;
}

/// The server could not be reached or the connection broke.
final class ConnectionFailure extends OmniNetworkException {
  /// Creates a connection failure.
  const ConnectionFailure(
    super.message, {
    super.uri,
    super.cause,
    this.reason = ConnectionReason.unknown,
  });

  /// Classified cause of this connection failure.
  final ConnectionReason reason;
}

/// The request was cancelled.
final class CancelledFailure extends OmniNetworkException {
  /// Creates a cancellation failure.
  const CancelledFailure({super.uri}) : super('Request cancelled');
}

/// The client was closed before or while the request ran.
final class ClosedFailure extends OmniNetworkException {
  /// Creates a closed-client failure.
  const ClosedFailure({super.uri}) : super('OmniNetwork client is closed');
}

/// The request could not be built (bad URL, unsupported body…).
final class RequestFailure extends OmniNetworkException {
  /// Creates a request-building failure.
  const RequestFailure(super.message, {super.uri, super.cause});
}

/// The server answered with a non-2xx status (typed calls only; `sendRaw`
/// returns every status).
final class HttpFailure extends OmniNetworkException {
  /// Creates an HTTP status failure for [response].
  HttpFailure(this.response)
    : super(
        [
          'HTTP ${response.statusCode}',
          ?httpReasonPhrase(response.statusCode),
        ].join(' '),
        uri: response.requestUri,
      );

  /// The full response, e.g. to read an error body via `response.json`.
  /// Not included in [toString], so it is never logged by accident.
  final OmniRawResponse response;

  /// HTTP status code.
  @override
  int get statusCode => response.statusCode;
}

/// The body could not be parsed or decoded into the requested type.
final class DecodeFailure extends OmniNetworkException {
  /// Creates a decoding failure.
  const DecodeFailure(super.message, {super.uri, super.cause, this.stackTrace});

  /// Where the decoder threw, when the failure came from a decoder.
  final StackTrace? stackTrace;
}

/// Authentication failed and could not be recovered: the token refresh
/// failed, threw or timed out (the refresh-failed callback has run).
final class AuthFailure extends OmniNetworkException {
  /// Creates an auth failure.
  const AuthFailure(super.message, {super.uri, super.cause, this.response});

  /// The 401 (or other expired-token) response that triggered the refresh.
  final OmniRawResponse? response;

  @override
  int? get statusCode => response?.statusCode;
}

/// The circuit breaker for [host] is open: the request was not sent.
final class CircuitOpenFailure extends OmniNetworkException {
  /// Creates an open-circuit failure.
  CircuitOpenFailure(this.host, {super.uri})
    : super('Circuit open for $host; request not sent');

  /// `host:port` whose circuit is open.
  final String host;
}

/// Removes user info, query and fragment so errors never leak secrets.
Uri safeUri(Uri uri) => Uri(
  scheme: uri.scheme,
  host: uri.host,
  port: uri.hasPort ? uri.port : null,
  path: uri.path,
);
