import 'package:flutter/widgets.dart';

/// Keys on the book's chrome, so an app can find the footer bar and the close
/// button in its own widget tree — for example to spotlight them in a
/// coach mark.
///
/// Keys, not type names: `flutter build --obfuscate` renames every class, so a
/// search by `runtimeType.toString()` silently finds nothing in a release
/// build. A key survives obfuscation.
///
/// ```dart
/// final footer = find.byKey(FlipBookKeys.footerBar);
/// ```
abstract final class FlipBookKeys {
  /// The whole footer bar: the navigation row and the voice row together.
  static const Key footerBar = ValueKey<String>('page_curl_flip.footerBar');

  /// The icon of the header's × close button.
  static const Key closeIcon = ValueKey<String>('page_curl_flip.closeIcon');
}
