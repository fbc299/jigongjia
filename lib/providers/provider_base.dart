import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Mixin that provides a reusable [select] static helper for Provider Selector.
/// Eliminates the identical boilerplate repeated across all Provider classes.
mixin ProviderSelectorMixin<T extends ChangeNotifier> on ChangeNotifier {
  /// Build a [Selector] widget that only rebuilds when [selector] returns
  /// a different value, reducing unnecessary rebuilds.
  static Widget select<P extends ChangeNotifier, S>({
    required S Function(P) selector,
    required Widget Function(BuildContext, S, Widget?) builder,
    Widget? child,
  }) {
    return Selector<P, S>(
      selector: (_, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
}
