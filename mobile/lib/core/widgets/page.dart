import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

/// A standard screen: top bar with a back arrow (when it can go back), a title, and a body that
/// stays at a readable width on tablets. Use [scroll] false when the body is a list or has its own scroll.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.scroll = true,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
    this.showTopBar = true,
    this.onRefresh,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// A bar pinned above the bottom edge (save button, totals).
  final Widget? bottom;
  final bool scroll;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool showTopBar;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: scroll ? SingleChildScrollView(padding: padding, physics: const AlwaysScrollableScrollPhysics(), child: body) : body,
      ),
    );
    if (onRefresh != null && scroll) content = RefreshIndicator(onRefresh: onRefresh!, child: content);

    return Scaffold(
      appBar: showTopBar ? AppBar(title: Text(title), actions: actions) : null,
      body: SafeArea(top: false, child: content),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: bottom),
                ),
              ),
            ),
    );
  }
}

/// Shows an [AsyncValue] with a skeleton while loading, an error view with retry, and the data.
///
///     AsyncBody(value: ref.watch(itemsProvider), onRetry: () => ref.invalidate(itemsProvider), data: (items) => ...)
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({required this.value, required this.data, super.key, this.onRetry, this.loading});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    // Keep showing old data while a refresh is running.
    if (value.hasValue && !value.hasError) return data(value.requireValue);
    if (value.hasError) return ErrorView(error: value.error!, onRetry: onRetry);
    return loading ?? const SkeletonList();
  }
}
