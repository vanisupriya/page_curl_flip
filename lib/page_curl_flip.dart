/// A realistic cylindrical page-curl animation for Flutter.
///
/// Three entry points, lowest level first:
///
/// * [CurlOverlay] — the raw curl, driven by a single `progress` value.
/// * [PageCurlRoute] — a page transition that peels the old screen away.
/// * [FlipBook] — a complete multi-page book with table of contents.
library;

export 'src/curl_overlay.dart';
export 'src/flip_book.dart';
export 'src/flip_book_bookmarks.dart';
export 'src/flip_book_contents.dart';
export 'src/flip_book_export.dart';
export 'src/flip_book_export_entry.dart';
export 'src/flip_book_export_kind.dart';
export 'src/flip_book_footer.dart';
export 'src/flip_book_header.dart';
export 'src/flip_book_keys.dart';
export 'src/flip_book_marker.dart';
export 'src/flip_book_marker_style.dart';
export 'src/flip_book_page_style.dart';
export 'src/flip_book_pages.dart';
export 'src/flip_book_read_aloud.dart';
export 'src/flip_book_swipe.dart';
export 'src/flip_book_page.dart';
export 'src/flip_book_read_speed.dart';
export 'src/flip_speed.dart';
export 'src/page_curl_route.dart';
export 'src/read_marker_text.dart';
export 'src/reader_mark.dart';
