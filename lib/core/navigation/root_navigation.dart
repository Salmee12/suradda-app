import 'package:flutter/widgets.dart';

/// Gives the pages inside RootShell a way to open the root Scaffold's drawer.
///
/// Two simpler approaches don't work here:
///
/// * `Scaffold.of(context)` from inside a page resolves to *that page's* own
///   Scaffold, which has no drawer — so it asserts instead of opening anything.
/// * A top-level `GlobalKey<ScaffoldState>` breaks as soon as two RootShells are
///   alive at the same time (which happens for the duration of a route
///   transition), because both claim the same key and Flutter throws
///   "multiple widgets used the same GlobalKey". It also fails silently — a null
///   `currentState` just makes the button do nothing.
///
/// Scoping the opener to the widget tree avoids both problems.
class RootNavigation extends InheritedWidget {
  const RootNavigation({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  /// Opens the drawer owned by the root Scaffold.
  final VoidCallback openDrawer;

  static RootNavigation of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RootNavigation>();
    assert(
      scope != null,
      'RootNavigation.of() called from a widget that is not inside RootShell.',
    );
    return scope!;
  }

  static RootNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RootNavigation>();

  @override
  bool updateShouldNotify(RootNavigation oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}
