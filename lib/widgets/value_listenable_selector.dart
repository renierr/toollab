import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Like [ValueListenableBuilder], but rebuilds only when [selector]'s result
/// changes, so a fast-changing value does not rebuild what ignores most of it.
class ValueListenableSelector<T, S> extends StatefulWidget {
  final ValueListenable<T> valueListenable;
  final S Function(T value) selector;
  final ValueWidgetBuilder<S> builder;
  final Widget? child;

  const ValueListenableSelector({
    super.key,
    required this.valueListenable,
    required this.selector,
    required this.builder,
    this.child,
  });

  @override
  State<ValueListenableSelector<T, S>> createState() =>
      _ValueListenableSelectorState<T, S>();
}

class _ValueListenableSelectorState<T, S>
    extends State<ValueListenableSelector<T, S>> {
  late S _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selector(widget.valueListenable.value);
    widget.valueListenable.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ValueListenableSelector<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_onChanged);
      widget.valueListenable.addListener(_onChanged);
    }
    _selected = widget.selector(widget.valueListenable.value);
  }

  @override
  void dispose() {
    widget.valueListenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.selector(widget.valueListenable.value);
    if (next != _selected) setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _selected, widget.child);
}
