import 'dart:async';

import 'download_target.dart';

/// A response whose body arrives over time (see `OmniNetwork.openStream`).
final class OmniStreamResponse {
  /// Creates a streamed response.
  OmniStreamResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required void Function() cancel,
  }) : _cancel = cancel; // ignore: prefer_initializing_formals

  /// HTTP status code (2xx).
  final int statusCode;

  /// Response headers (lower-case names).
  final Map<String, String> headers;

  /// Body chunks; single subscription. Cancelling it closes the connection.
  final Stream<List<int>> body;

  final void Function() _cancel;

  /// Closes the connection.
  void cancel() => _cancel();
}

/// Forwards a download body to a stream. Internal.
final class StreamTarget extends DownloadTarget {
  /// Creates a target; [onCancel] aborts the request.
  StreamTarget(void Function() onCancel) {
    _controller = StreamController<List<int>>(onCancel: onCancel);
  }

  late final StreamController<List<int>> _controller;
  final Completer<(int, Map<String, String>)> _started = Completer();
  (int, Map<String, String>)? _head;

  /// Body stream.
  Stream<List<int>> get stream => _controller.stream;

  /// Completes with status and headers when the body starts.
  Future<(int, Map<String, String>)> get started => _started.future;

  /// Records status and headers before [begin]. Internal.
  void head(int status, Map<String, String> headers) =>
      _head = (status, headers);

  /// Delivers a failure to the body stream. Internal.
  void fail(Object error, StackTrace st) {
    if (!_started.isCompleted) return; // reported by openStream itself
    if (!_controller.isClosed) {
      _controller.addError(error, st);
      _controller.close();
    }
  }

  @override
  Future<int> existingLength() async => 0;

  @override
  Future<void> begin({required bool append}) async {
    if (!_started.isCompleted) {
      _started.complete(_head ?? (200, const <String, String>{}));
    }
  }

  @override
  Future<void> add(List<int> chunk) async {
    if (!_controller.isClosed) _controller.add(chunk);
  }

  @override
  Future<void> commit() async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> abort() async {}
}
