import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omni_network/omni_network.dart';

/// Builds reactive UI from a [RequestController].
///
/// Automatically triggers [RequestController.load] when [loadOnInit] is `true`
/// and the controller starts in [RequestIdle].
class OmniRequestBuilder<T> extends StatefulWidget {
  /// Creates a request builder bound to [controller].
  const OmniRequestBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.loadOnInit = true,
    this.showPreviousOnError = false,
  });

  /// Controller managing the async request lifecycle.
  final RequestController<T> controller;

  /// Called when data is available ([RequestSuccess], or [RequestLoading] with
  /// `previous != null` while refreshing).
  final Widget Function(BuildContext context, T data, bool isRefreshing)
  builder;

  /// Shown on [RequestIdle] or initial [RequestLoading] without previous data.
  final WidgetBuilder? loadingBuilder;

  /// Shown on [RequestEmpty].
  final WidgetBuilder? emptyBuilder;

  /// Shown on [RequestError] (unless [showPreviousOnError] is `true` and
  /// previous data exists).
  final Widget Function(
    BuildContext context,
    Object error,
    VoidCallback retry,
  )?
  errorBuilder;

  /// Calls `controller.load()` once if [controller] starts in [RequestIdle].
  final bool loadOnInit;

  /// Renders the last successful data instead of [errorBuilder] when a
  /// refresh fails.
  final bool showPreviousOnError;

  @override
  State<OmniRequestBuilder<T>> createState() => _OmniRequestBuilderState<T>();
}

class _OmniRequestBuilderState<T> extends State<OmniRequestBuilder<T>> {
  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant OmniRequestBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _maybeLoad();
    }
  }

  void _maybeLoad() {
    if (widget.loadOnInit &&
        !widget.controller.isClosed &&
        widget.controller.state is RequestIdle<T>) {
      unawaited(widget.controller.load());
    }
  }

  void _retry() {
    if (!widget.controller.isClosed) {
      unawaited(widget.controller.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RequestState<T>>(
      initialData: widget.controller.state,
      stream: widget.controller.stream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.controller.state;
        return switch (state) {
          RequestIdle<T>() || RequestLoading<T>(previous: null) =>
            widget.loadingBuilder?.call(context) ??
                const Center(child: CircularProgressIndicator()),
          RequestLoading<T>(:final previous?) => widget.builder(
            context,
            previous,
            true,
          ),
          RequestSuccess<T>(:final data) => widget.builder(
            context,
            data,
            false,
          ),
          RequestEmpty<T>() =>
            widget.emptyBuilder?.call(context) ??
                const Center(child: Text('No data')),
          RequestError<T>(:final error, :final previous) =>
            widget.showPreviousOnError && previous != null
                ? widget.builder(context, previous, false)
                : widget.errorBuilder?.call(context, error, _retry) ??
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$error', textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: _retry,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
        };
      },
    );
  }
}
