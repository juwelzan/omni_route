import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omni_network/omni_network.dart';

/// Infinite-scrolling, pull-to-refresh list view driven by an [OmniPager].
///
/// Automatically loads the first page when empty, fetches the next page when
/// scrolling within [loadThreshold] pixels of the bottom, and shows error/empty
/// states with retry controls.
class OmniPagedListView<T> extends StatefulWidget {
  /// Creates a paged list bound to [pager].
  const OmniPagedListView({
    super.key,
    required this.pager,
    required this.itemBuilder,
    this.separatorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.footerLoadingBuilder,
    this.footerErrorBuilder,
    this.header,
    this.padding,
    this.scrollController,
    this.physics,
    this.shrinkWrap = false,
    this.loadThreshold = 200,
    this.autoLoadFirstPage = true,
    this.enableRefresh = true,
  });

  /// Pagination controller supplying items and page state.
  final OmniPager<T> pager;

  /// Builds each item row at [index].
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Optional separator between item rows.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Full-view loading indicator when page 1 is loading.
  final WidgetBuilder? loadingBuilder;

  /// Shown when page 1 finishes with zero items.
  final WidgetBuilder? emptyBuilder;

  /// Shown when loading fails and zero items are loaded yet.
  final Widget Function(
    BuildContext context,
    Object error,
    VoidCallback retry,
  )?
  errorBuilder;

  /// Footer indicator while subsequent pages are loading.
  final WidgetBuilder? footerLoadingBuilder;

  /// Footer shown when loading a subsequent page fails.
  final Widget Function(
    BuildContext context,
    Object error,
    VoidCallback retry,
  )?
  footerErrorBuilder;

  /// Optional widget rendered above the first item.
  final Widget? header;

  /// Inner list padding.
  final EdgeInsetsGeometry? padding;

  /// Optional external scroll controller.
  final ScrollController? scrollController;

  /// Optional scroll physics.
  final ScrollPhysics? physics;

  /// Whether the internal `ListView` should shrink-wrap its contents.
  final bool shrinkWrap;

  /// Distance in logical pixels from the bottom at which [OmniPager.next] is
  /// triggered automatically.
  final double loadThreshold;

  /// Loads the first page automatically when initialized with an idle pager.
  final bool autoLoadFirstPage;

  /// Wraps the list with a `RefreshIndicator` calling [OmniPager.refresh].
  final bool enableRefresh;

  @override
  State<OmniPagedListView<T>> createState() => _OmniPagedListViewState<T>();
}

class _OmniPagedListViewState<T> extends State<OmniPagedListView<T>> {
  @override
  void initState() {
    super.initState();
    _maybeLoadFirstPage();
  }

  @override
  void didUpdateWidget(covariant OmniPagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pager != widget.pager) {
      _maybeLoadFirstPage();
    }
  }

  void _maybeLoadFirstPage() {
    final p = widget.pager;
    if (widget.autoLoadFirstPage &&
        p.pageCount == 0 &&
        p.items.isEmpty &&
        p.hasMore &&
        !p.isLoading &&
        p.lastError == null) {
      unawaited(p.next());
    }
  }

  bool _onScroll(ScrollNotification notification) {
    final p = widget.pager;
    if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - widget.loadThreshold &&
        p.hasMore &&
        !p.isLoading &&
        p.lastError == null) {
      unawaited(p.next());
    }
    return false;
  }

  void _retryNext() => unawaited(widget.pager.next());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: widget.pager.changes,
      builder: (context, _) {
        final p = widget.pager;
        final items = p.items;
        final error = p.lastError;

        if (items.isEmpty && p.isLoading) {
          return widget.loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty && error != null) {
          return widget.errorBuilder?.call(context, error, _retryNext) ??
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _retryNext,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
        }
        if (items.isEmpty && !p.hasMore) {
          return widget.emptyBuilder?.call(context) ??
              const Center(child: Text('No items'));
        }

        final hasFooter = p.isLoading || error != null;
        final headerOffset = widget.header == null ? 0 : 1;
        final totalCount = items.length + headerOffset + (hasFooter ? 1 : 0);

        Widget list;
        if (widget.separatorBuilder != null) {
          list = ListView.separated(
            controller: widget.scrollController,
            padding: widget.padding,
            physics: widget.physics,
            shrinkWrap: widget.shrinkWrap,
            itemCount: totalCount,
            separatorBuilder: (context, index) {
              if (index < headerOffset || index >= headerOffset + items.length - 1) {
                return const SizedBox.shrink();
              }
              return widget.separatorBuilder!(context, index - headerOffset);
            },
            itemBuilder: (context, index) => _buildRow(context, index, p),
          );
        } else {
          list = ListView.builder(
            controller: widget.scrollController,
            padding: widget.padding,
            physics: widget.physics,
            shrinkWrap: widget.shrinkWrap,
            itemCount: totalCount,
            itemBuilder: (context, index) => _buildRow(context, index, p),
          );
        }

        list = NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: list,
        );

        if (!widget.enableRefresh) return list;
        return RefreshIndicator(
          onRefresh: p.refresh,
          child: list,
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, int index, OmniPager<T> p) {
    if (widget.header != null) {
      if (index == 0) return widget.header!;
      index -= 1;
    }
    final items = p.items;
    if (index < items.length) {
      return widget.itemBuilder(context, items[index], index);
    }
    final error = p.lastError;
    if (error != null) {
      return widget.footerErrorBuilder?.call(context, error, _retryNext) ??
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text('$error')),
                const SizedBox(width: 8),
                TextButton(onPressed: _retryNext, child: const Text('Retry')),
              ],
            ),
          );
    }
    return widget.footerLoadingBuilder?.call(context) ??
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        );
  }
}
