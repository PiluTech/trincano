//
//  DisplayMapView.swift
//  Ice
//

import SwiftUI

/// Draws the connected displays as in the system arrangement and shows the
/// per-display setting (how hidden items are shown) for the selected one.
///
/// Only what is already stored per display is exposed: ``DisplayBarMode``.
struct DisplayMapView: View {
    @ObservedObject var settings: GeneralSettings
    @State private var selectedID: UInt32?
    /// Bumped when the screen configuration changes, to rebuild the map.
    @State private var screenRevision = 0

    private let mapHeight: CGFloat = 150

    private var descriptors: [DisplayDescriptor] {
        NSScreen.screens.map { screen in
            DisplayDescriptor(
                id: screen.displayID,
                uuid: screen.displayUUIDString,
                name: screen.localizedName,
                frame: screen.frame,
                hasNotch: screen.hasNotch
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                let entries = DisplayMapModel.entries(for: descriptors, fitting: geometry.size)
                ZStack(alignment: .topLeading) {
                    ForEach(entries) { entry in
                        mapButton(for: entry, isSelected: entry.id == effectiveSelectedID(entries))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Displays"))
            }
            .frame(height: mapHeight)

            detail
        }
        .id(screenRevision)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screenRevision += 1
        }
    }

    // MARK: Map

    /// The selected display, falling back to the first one when the selected
    /// display was disconnected (or nothing is selected yet).
    private func effectiveSelectedID(_ entries: [DisplayMapEntry]) -> UInt32? {
        if let selectedID, entries.contains(where: { $0.id == selectedID }) {
            return selectedID
        }
        return entries.first?.id
    }

    @ViewBuilder
    private func mapButton(for entry: DisplayMapEntry, isSelected: Bool) -> some View {
        Button {
            selectedID = entry.id
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: DisplayMapText.title(for: entry))
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(verbatim: DisplayMapText.resolution(for: entry))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.top, entry.hasNotch ? 12 : 4)
            .frame(width: entry.rect.width, height: entry.rect.height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1))
            )
            .overlay(alignment: .top) {
                if entry.hasNotch {
                    UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
                        .fill(.primary)
                        .frame(width: 28, height: 7)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .position(x: entry.rect.midX, y: entry.rect.midY)
        .help(DisplayMapText.title(for: entry))
        .accessibilityLabel(Text(verbatim: DisplayMapText.accessibilityLabel(for: entry)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(Motion.animation(.color), value: isSelected)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        let entries = DisplayMapModel.entries(for: descriptors, fitting: CGSize(width: 100, height: 100))
        if let id = effectiveSelectedID(entries), let entry = entries.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: DisplayMapText.title(for: entry))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        Text(verbatim: DisplayMapText.resolution(for: entry, includesDuplicate: true))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if entry.hasNotch {
                        Text("With notch")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if let key = entry.profileKey {
                    IcePicker("Hidden items on this display", selection: modeBinding(for: key)) {
                        Text("Follow \"Use Trincano Bar\"").tag(DisplayBarMode.followGlobal)
                        Text("Trincano Bar").tag(DisplayBarMode.bar)
                        Text("Expand the menu bar").tag(DisplayBarMode.inline)
                    }
                    .annotation("How hidden items are shown on this display.")
                } else {
                    Text("This display has no stable identifier, so it can't keep its own setting. It follows \"Use Trincano Bar\".")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .id(entry.id)
            .transition(.opacity)
            .animation(Motion.animation(.fade), value: entry.id)
        }
    }

    private func modeBinding(for uuid: String) -> Binding<DisplayBarMode> {
        Binding(
            get: { settings.displayProfiles.mode(for: uuid) },
            set: { settings.displayProfiles.set($0, for: uuid) }
        )
    }
}

/// Texts of the display map. Names come from the system and are never
/// translated; only the fallbacks and suffixes are.
private enum DisplayMapText {
    static func title(for entry: DisplayMapEntry) -> String {
        let base = entry.name.isEmpty ? String(localized: "Display \(entry.position)") : entry.name
        guard let duplicate = entry.duplicate else {
            return base
        }
        return "\(base) · \(duplicate.ordinal)"
    }

    static func resolution(for entry: DisplayMapEntry, includesDuplicate: Bool = false) -> String {
        let size = "\(Int(entry.pixelSize.width)) × \(Int(entry.pixelSize.height))"
        guard includesDuplicate, let duplicate = entry.duplicate else {
            return size
        }
        return "\(size) · " + String(localized: "\(duplicate.ordinal) of \(duplicate.count) with this name")
    }

    static func accessibilityLabel(for entry: DisplayMapEntry) -> String {
        var parts = [title(for: entry), resolution(for: entry)]
        if entry.hasNotch {
            parts.append(String(localized: "With notch"))
        }
        return parts.joined(separator: ", ")
    }
}
