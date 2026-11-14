//
//  LaunchWindowPolicy.swift
//  Ice
//

/// A menu bar app must not open windows by itself on every launch (audit A4).
/// A window may appear on its own only the first time; afterwards the user asks
/// for it (menu, hotkey, reopening the app, or the status indicator).
enum LaunchWindowPolicy {
    enum PermissionsPrompt: Equatable {
        /// Open the Permissions window now.
        case openWindow
        /// Do not open anything; show a clickable indicator in the menu bar.
        case showIndicator
        /// Nothing to ask.
        case none
    }

    /// What to do at launch about missing permissions.
    static func permissionsPromptAtLaunch(permissionsMissing: Bool, promptedBefore: Bool) -> PermissionsPrompt {
        guard permissionsMissing else {
            return .none
        }
        return promptedBefore ? .showIndicator : .openWindow
    }
}
