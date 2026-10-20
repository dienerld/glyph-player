import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/theme.dart';

/// Which item of a list has its details panel open, by identity (a movie id),
/// so the panel follows its item when the rows reflow. At most one is open;
/// the ones closing stay listed until their panel finished shrinking.
class ItemExpansion extends ChangeNotifier {
  Object? _open;
  final _closing = <Object>[];
  Object? _focusBack;

  /// The item whose panel is open, if any.
  Object? get open => _open;

  /// Items with a panel on screen: the closing ones, then the open one.
  List<Object> get shown => [..._closing, ?_open];

  /// Opens the panel of [key], moving it from another item; closes it when it
  /// is already the open one.
  void toggle(Object key) {
    if (_open == key) {
      close();
      return;
    }
    final was = _open;
    if (was != null) _closing.add(was);
    _closing.remove(key);
    _open = key;
    notifyListeners();
  }

  /// Closes the open panel. With [returnFocus] its item takes the keyboard
  /// focus back (see [takeFocusBack]).
  void close({bool returnFocus = false}) {
    final was = _open;
    if (was == null) return;
    _open = null;
    _closing
      ..remove(was)
      ..add(was);
    if (returnFocus) {
      _focusBack = was;
      // Only the item built in the next frame may claim it.
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusBack = null);
    }
    notifyListeners();
  }

  /// A closing panel of [key] finished shrinking.
  void closed(Object key) {
    if (_closing.remove(key)) notifyListeners();
  }

  /// Drops every panel at once, without animation: the list itself changed
  /// (sort, search).
  void reset() {
    if (_open == null && _closing.isEmpty) return;
    _open = null;
    _closing.clear();
    notifyListeners();
  }

  /// Forgets panels whose item is no longer listed. Silent: meant for build,
  /// which uses the result right away.
  void retainWhere(bool Function(Object key) listed) {
    if (_open != null && !listed(_open!)) _open = null;
    _closing.removeWhere((k) => !listed(k));
  }

  /// True once for the item that should take the focus back after a close.
  bool takeFocusBack(Object key) {
    if (_focusBack != key) return false;
    _focusBack = null;
    return true;
  }
}

/// Puts a card inside an expandable list: it can open its own panel with
/// [toggle] and knows whether that panel [isOpen].
class ExpandableItem extends InheritedWidget {
  const ExpandableItem({
    super.key,
    required this.expansion,
    required this.itemKey,
    required this.isOpen,
    required super.child,
  });
  final ItemExpansion expansion;
  final Object itemKey;
  final bool isOpen;

  /// The enclosing item, or null outside an expandable list.
  static ExpandableItem? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ExpandableItem>();

  void toggle() => expansion.toggle(itemKey);

  @override
  bool updateShouldNotify(ExpandableItem old) =>
      old.expansion != expansion ||
      old.itemKey != itemKey ||
      old.isOpen != isOpen;
}

/// Builds the details panel of [item]. [maxHeight] keeps it within the
/// visible area; [close] closes it and gives the focus back to the item.
typedef PanelBuilder<T> =
    Widget Function(
      BuildContext context,
      T item,
      double maxHeight,
      VoidCallback close,
    );

/// Opt-in details accordion of a list: tapping an item opens a full-width
/// panel right below its row.
class ItemPanel<T> {
  const ItemPanel({required this.keyOf, required this.builder});

  /// Identity of an item; the panel follows it when the rows reflow.
  final Object Function(T item) keyOf;
  final PanelBuilder<T> builder;
}

/// Tallest a panel may be in a list of [viewportHeight]: it has to fit, with
/// a margin, for the open animation to end with all of it in view. Never so
/// small that the panel's fixed parts no longer fit.
double panelMaxHeight(double viewportHeight) {
  if (!viewportHeight.isFinite) return 560;
  final h = viewportHeight - 2 * Tokens.gap - 24;
  return h < 360 ? 360 : h;
}

/// Esc closes the open panel of [expansion] while the focus is in [child]
/// (the panel or a card), and gives the focus back to the card.
class CloseOnEscape extends StatelessWidget {
  const CloseOnEscape({
    super.key,
    required this.expansion,
    required this.child,
  });
  final ItemExpansion expansion;
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      if (expansion.open != null)
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            expansion.close(returnFocus: true),
    },
    child: child,
  );
}

/// Full-width slot of a details panel: grows open from its top edge while
/// [open], shrinks shut otherwise (then calls [onClosed]). Once open it
/// scrolls itself into view. Reduced motion: no growing, a jump instead of a
/// scroll. Kept alive in a lazy list, so scrolling it out of view and back
/// does not open it (and take the focus) again.
class ExpandingPanel extends StatefulWidget {
  const ExpandingPanel({
    super.key,
    required this.open,
    required this.child,
    this.onClosed,
    this.gap = Tokens.gap,
  });
  final bool open;
  final Widget child;
  final VoidCallback? onClosed;

  /// Space above the panel, part of what grows and shrinks.
  final double gap;

  @override
  State<ExpandingPanel> createState() => _ExpandingPanelState();
}

class _ExpandingPanelState extends State<ExpandingPanel>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Tokens.slide,
  )..addStatusListener(_onStatus);
  late final _size = CurvedAnimation(
    parent: _controller,
    curve: Tokens.slideCurve,
  );
  bool _reduce = false;
  bool _started = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _controller.duration = _reduce ? Duration.zero : Tokens.slide;
    if (_started) return;
    _started = true;
    if (widget.open) {
      _controller.forward();
    } else {
      _afterFrame(widget.onClosed);
    }
  }

  @override
  void didUpdateWidget(ExpandingPanel old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    widget.open ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _size.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _afterFrame(
        () => Scrollable.ensureVisible(
          context,
          duration: _reduce ? Duration.zero : Tokens.slide,
          curve: Tokens.slideCurve,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    } else if (status == AnimationStatus.dismissed) {
      _afterFrame(widget.onClosed);
    }
  }

  void _afterFrame(VoidCallback? run) {
    if (run == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) run();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: Padding(
        padding: EdgeInsets.only(top: widget.gap),
        child: widget.child,
      ),
    );
  }
}
