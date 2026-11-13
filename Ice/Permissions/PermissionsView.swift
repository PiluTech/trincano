//
//  PermissionsView.swift
//  Ice
//

import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var manager: AppPermissions

    private var continueButtonText: LocalizedStringKey {
        if case .hasRequired = manager.permissionsState {
            "Continue in Limited Mode"
        } else {
            "Continue"
        }
    }

    private var continueButtonForegroundStyle: some ShapeStyle {
        switch manager.permissionsState {
        case .missing:
            AnyShapeStyle(.secondary)
        case .hasAll:
            AnyShapeStyle(.primary)
        case .hasRequired:
            AnyShapeStyle(.yellow)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.vertical)

            permissionsStack

            footerView
                .padding(.vertical)
        }
        .padding(.horizontal)
        .frame(width: 550)
        .fixedSize()
    }

    @ViewBuilder
    private var headerView: some View {
        Label {
            Text("Permissions")
                .font(.system(size: 40, weight: .medium))
        } icon: {
            if let nsImage = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 85, height: 85)
            }
        }
    }

    /// Blue that passes WCAG AA (4.5:1) on both themes; see `ContrastPolicy`.
    private static let highlightColor = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let c = ContrastPolicy.permissionsHighlight(isDark: isDark)
        return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
    })

    @ViewBuilder
    private var explanationBox: some View {
        IceSection {
            VStack {
                Text("Trincano needs your permission to manage the menu bar.")
                    .fontWeight(.medium)
                Text("Absolutely no personal information is collected or stored.")
                    .bold()
                    .foregroundStyle(Self.highlightColor)
            }
            .padding()
        }
        .font(.title3)
    }

    @ViewBuilder
    private var permissionsStack: some View {
        VStack {
            explanationBox
            ForEach(manager.allPermissions) { permission in
                permissionBox(permission)
            }
        }
    }

    @ViewBuilder
    private var footerView: some View {
        HStack {
            quitButton
            continueButton
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Text("Quit")
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var continueButton: some View {
        Button {
            appState.dismissWindow(.permissions)

            guard manager.permissionsState != .missing else {
                appState.performSetup(hasPermissions: false)
                return
            }

            appState.performSetup(hasPermissions: true)

            Task {
                appState.activate(withPolicy: .regular)
                appState.openWindow(.settings)
            }
        } label: {
            Text(continueButtonText)
                .frame(maxWidth: .infinity)
                .foregroundStyle(continueButtonForegroundStyle)
        }
        .disabled(manager.permissionsState == .missing)
    }

    @ViewBuilder
    private func permissionBox(_ permission: Permission) -> some View {
        IceSection {
            VStack(spacing: 12) {
                Text(permission.title)
                    .font(.title.weight(.medium))
                    .underline()

                VStack(spacing: 2) {
                    Text("Trincano needs this to:")
                        .font(.title3)
                        .bold()

                    VStack(alignment: .leading) {
                        ForEach(permission.details, id: \.self) { detail in
                            HStack {
                                Text("•").bold()
                                Text(detail).fontWeight(.medium)
                            }
                        }
                    }
                }

                Button {
                    permission.performRequest()
                    Task {
                        await permission.waitForPermission()
                        appState.activate(withPolicy: .regular)
                        appState.openWindow(.permissions)
                    }
                } label: {
                    if permission.hasPermission {
                        Text("Permission Granted")
                            .foregroundStyle(.green)
                    } else {
                        Text("Grant Permission")
                    }
                }
                .allowsHitTesting(!permission.hasPermission)

                if !permission.isRequired {
                    CalloutBox("Trincano can work in a limited mode without this permission.") {
                        Image(systemName: "checkmark.shield")
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
        }
    }
}
