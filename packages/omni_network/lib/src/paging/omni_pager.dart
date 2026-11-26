import 'dart:async';

import '../core/cancel_token.dart';
import '../core/decoding.dart';
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_request.dart';
import 'pagination_strategy.dart';

/// Loads a paginated list page by page. Create with `OmniNetwork.paginate`.
///
/// ```dart
/// final pager = api.paginate<User>('/users',
///     decoder: User.fromJson, strategy: const PagePagination());
/// await pager.next();            // page 1
/// if (pager.hasMore) await pager.next();
/// pager.items;                   // everything loaded so far
/// await pager.close();
/// ```
///
/// * Calling [next] while a page is loading returns the same future (no
///   duplicate requests).
/// * A failed page leaves the state unchanged; call [next] again to retry.
/// * [refresh]/[reset] discard an in-flight page, so a stale response is
///   never applied.
/// * Paging stops when the strategy says so, after [maxPages], or when a
///   cursor repeats (protects against server loops).
final class OmniPager<T> {
  /// Creates a pager. Prefer `OmniNetwork.paginate`.
  OmniPager({
    required this._client,
    required OmniRequest request,
    required this.strategy,
    this._decoder,
    this.itemsKey,
    this.maxPages,
  }) : _base = request;

  final OmniNetwork _client;
  final OmniRequest _base;
  final JsonDecoder<T>? _decoder;

  /// How pages are requested and the end detected.
  final PaginationStrategy strategy;

  /// JSON path of the item array in the full body (e.g. `data`); when
  /// `null` the client's response adapter result is used.
  final String? itemsKey;

  /// Upper bound on pages loaded (`null` = unlimited).
  final int? maxPages;

  final List<T> _items = [];
  final Set<String> _seenCursors = {};
  Object? _cursor;
  bool _hasMore = true;
  int _pages = 0;
  int _generation = 0;
  Future<List<T>>? _loading;
  OmniCancelToken? _token;
  bool _closed = false;

  /// All items loaded so far (unmodifiable view).
  List<T> get items => List.unmodifiable(_items);

  /// Whether another page may exist.
  bool get hasMore => _hasMore && !_closed;

  /// Whether a page is loading.
  bool get isLoading => _loading != null;

  /// Pages loaded so far.
  int get pageCount => _pages;

  /// The failure of the last [next], cleared on success.
  OmniNetworkException? lastError;

  /// Loads the next page and returns its items ([] when there is no more).
  Future<List<T>> next() {
    if (_closed) throw StateError('OmniPager is closed');
    if (!_hasMore) return Future.value(const []);
    return _loading ??= _load();
  }

  Future<List<T>> _load() async {
    final generation = _generation;
    // Yield first so `_loading` is assigned before any `finally` below runs,
    // even when building the request throws synchronously.
    await Future<void>.value();
    final token = _token = OmniCancelToken();
    try {
      final request = strategy
          .requestFor(_base, _cursor)
          .copyWith(cancelToken: token);
      final raw = await _client.sendRaw(request);
      if (!raw.isSuccess) throw HttpFailure(raw);
      final json = parseJson(raw);
      final source = itemsKey == null
          ? _client.responseAdapter.unwrap(json, raw)
          : readJsonPath(json, itemsKey!);
      if (source is! List) {
        throw DecodeFailure(
          'Expected a JSON array of items'
          '${itemsKey == null ? '' : ' at "$itemsKey"'}',
          uri: raw.requestUri,
        );
      }
      final decoder = _decoder ?? _client.decoderFor<T>();
      if (decoder == null) {
        throw DecodeFailure(
          'No JsonDecoder<$T> provided or registered in OmniNetwork(decoders:)',
          uri: raw.requestUri,
        );
      }
      final page = [
        for (var i = 0; i < source.length; i++)
          runDecoder(
            () => decoder(asObject(source[i], raw.requestUri, index: i)),
            raw.requestUri,
          ),
      ];
      if (generation != _generation) throw const CancelledFailure();
      final next = strategy.nextCursor(
        PageContext(
          cursor: _cursor,
          json: json,
          response: raw,
          itemCount: page.length,
        ),
      );
      _items.addAll(page);
      _pages++;
      if (_cursor != null) _seenCursors.add('$_cursor');
      _cursor = next;
      _hasMore =
          next != null &&
          !_seenCursors.contains('$next') &&
          (maxPages == null || _pages < maxPages!);
      lastError = null;
      return page;
    } on OmniNetworkException catch (e) {
      if (generation == _generation) lastError = e;
      rethrow;
    } finally {
      if (generation == _generation) {
        _loading = null;
        _token = null;
      }
    }
  }

  /// Discards loaded items and any in-flight page; the next [next] starts
  /// from the first page.
  void reset() {
    _generation++;
    _token?.cancel();
    _token = null;
    _loading = null;
    _items.clear();
    _seenCursors.clear();
    _cursor = null;
    _hasMore = true;
    _pages = 0;
    lastError = null;
  }

  /// [reset] and load the first page.
  Future<List<T>> refresh() {
    reset();
    return next();
  }

  /// Cancels an in-flight page; [next] then throws [StateError].
  Future<void> close() async {
    if (_closed) return;
    reset();
    _closed = true;
  }
}
