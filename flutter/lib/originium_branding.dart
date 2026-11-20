/// User-visible product branding for the rustdesk-originium fork.
///
/// Only the strings the user actually sees are rebranded here. Internal
/// identifiers stay untouched on purpose:
///
/// * `hbb_common::config::APP_NAME` still reads `RustDesk`, because it feeds
///   the config/log directory layout and `is_custom_client()` switches the
///   update flow to the custom-client path.
/// * Crate names, the `flutter_hbb` Dart package and the `rustdesk.exe` binary
///   name stay as-is so the upstream build scripts keep working.
///
/// Renaming any of those would change on-disk paths and protocol behaviour for
/// no user-visible benefit, so the fork only changes presentation.
library;

/// Product name shown in window titles, the about panel and installer copy.
const String kOriginiumProductName = 'rustdesk-originium';

/// Short tag used where the product name would be too long, e.g. the tray.
const String kOriginiumProductTag = 'originium';

/// Builds a window title for the given section, e.g.
/// `File Transfer - rustdesk-originium`.
String originiumWindowTitle(String section) =>
    '$section - $kOriginiumProductName';
