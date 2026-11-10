//
//  IceBarPresentationPolicy.swift
//  Ice
//

/// Decides whether the Trincano Bar must wait for a cache refresh before it
/// appears.
enum IceBarPresentationPolicy {
    /// The bar waits only when the section has items but there is no image to
    /// show for any of them (nothing useful to draw yet). Otherwise it
    /// appears at once with the cached images and the refresh runs in the
    /// background; the view updates when it finishes.
    static func shouldWaitForRefresh(itemCount: Int, itemsWithImages: Int) -> Bool {
        itemCount > 0 && itemsWithImages == 0
    }
}

/// Gate for the 5 s timer / space / screen / theme refresh: the wallpaper and
/// menu bar capture runs only while the bar is on screen. Opening the bar
/// already captures once (performShow -> updateAllProperties), so nothing is
/// stale.
enum IceBarPeriodicRefresh {
    static func run(isBarVisible: Bool, capture: () -> Void) {
        if isBarVisible {
            capture()
        }
    }
}
