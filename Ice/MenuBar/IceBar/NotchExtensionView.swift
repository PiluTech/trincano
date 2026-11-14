//
//  NotchExtensionView.swift
//  Ice
//

import SwiftUI

/// The Trincano Bar presented as an extension that grows out of the notch:
/// items grouped by "behind the notch" and "hidden", wrapped in rows, with
/// vertical scrolling past three rows. Only used on a screen with a notch
/// (see ``NotchExtensionPresentation``); everywhere else the standard bar is
/// used.
struct NotchExtensionContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var colorManager: IceBarColorManager
    @ObservedObject var itemManager: MenuBarItemManager
    @ObservedObject var imageCache: MenuBarItemImageCache
    @ObservedObject var menuBarManager: MenuBarManager
    @State private var contentHeight: CGFloat = 0
    @State private var appeared = false

    let screen: NSScreen
    let section: MenuBarSection.Name

    private let contentPadding: CGFloat = 12

    private var groups: [NotchExtensionGroups.Group<MenuBarItem>] {
        NotchExtensionGroups.make(
            behindNotch: itemManager.notchObscuredItems(on: screen),
            hidden: itemManager.itemCache[section],
            id: \.windowID
        )
    }

    private var usesBlackBackground: Bool {
        NotchExtensionPresentation.usesBlackBackground(
            menuBarBrightness: colorManager.colorInfo?.color.brightness.map { Double($0) }
        )
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20)
    }

    private var maxContentHeight: CGFloat {
        NotchExtensionFrame.contentMaxHeight - contentPadding * 2
    }

    /// 200 ms ease-out from the notch; no movement with "Reduce motion".
    private var appearAnimation: Animation? {
        Motion.reduceMotion ? nil : .easeOut(duration: Motion.duration(.fade))
    }

    var body: some View {
        mainContent
            .padding(contentPadding)
            .frame(
                minWidth: NotchExtensionFrame.minWidth - NotchExtensionFrame.outerInset * 2,
                maxWidth: NotchExtensionFrame.contentMaxWidth
            )
            .frame(maxHeight: NotchExtensionFrame.contentMaxHeight)
            .background {
                if usesBlackBackground {
                    shape.fill(Color.black)
                } else {
                    Color.clear
                        .menuBarItemContainer(appState: appState, colorInfo: colorManager.colorInfo)
                        .clipShape(shape)
                }
            }
            .environment(\.colorScheme, usesBlackBackground ? .dark : .light)
            .foregroundStyle(usesBlackBackground ? Color.white : Color.black)
            .padding([.horizontal, .bottom], NotchExtensionFrame.outerInset)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .fixedSize()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || Motion.reduceMotion ? 0 : -8)
            .onAppear {
                withAnimation(appearAnimation) {
                    appeared = true
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Trincano Bar"))
    }

    @ViewBuilder
    private var mainContent: some View {
        if !ScreenCapture.cachedCheckPermissions() {
            Text("The Trincano Bar requires screen recording permissions.")
                .fixedSize(horizontal: false, vertical: true)
        } else if menuBarManager.isMenuBarHiddenBySystemUserDefaults {
            Text("Trincano cannot display menu bar items for automatically hidden menu bars")
                .fixedSize(horizontal: false, vertical: true)
        } else if itemManager.itemCache.managedItems.isEmpty {
            HStack {
                Text("Loading menu bar items…")
                ProgressView()
                    .controlSize(.small)
            }
        } else if imageCache.cacheFailed(for: section) {
            Text("Unable to display menu bar items")
        } else if groups.isEmpty {
            Text("No hidden items on this screen.")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        } else {
            groupList
        }
    }

    @ViewBuilder
    private var groupList: some View {
        let groups = groups
        let total = groups.reduce(0) { $0 + $1.items.count }

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(groups.indices, id: \.self) { index in
                    groupView(groups[index])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onFrameChange(update: Binding(
                get: { CGRect(x: 0, y: 0, width: 0, height: contentHeight) },
                set: { contentHeight = $0.height }
            ))
        }
        .scrollIndicators(contentHeight > maxContentHeight ? .automatic : .never)
        .frame(height: contentHeight > 0 ? min(contentHeight, maxContentHeight) : nil)
        .overlay(alignment: .bottom) {
            if contentHeight > maxContentHeight {
                Text("Scroll to see all \(total) items")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                    .background(
                        LinearGradient(
                            colors: [.clear, usesBlackBackground ? .black : .white],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func groupView(_ group: NotchExtensionGroups.Group<MenuBarItem>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(group.kind == .behindNotch ? "Behind the notch" : "Hidden items")
                Text(verbatim: "· \(group.items.count)")
            }
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.leading, 6)
            .accessibilityAddTraits(.isHeader)

            NotchFlowLayout(spacing: 2) {
                ForEach(group.items, id: \.windowID) { item in
                    IceBarItemView(
                        imageCache: imageCache,
                        itemManager: itemManager,
                        menuBarManager: menuBarManager,
                        item: item,
                        section: section
                    )
                    .frame(minWidth: TargetSize.notchExtensionButton.width, minHeight: TargetSize.notchExtensionButton.height)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Lays out subviews in wrapped rows (see ``FlowRows``).
private struct NotchFlowLayout: Layout {
    let spacing: CGFloat

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [[Int]] {
        FlowRows.rows(
            widths: subviews.map { $0.sizeThatFits(.unspecified).width },
            maxWidth: maxWidth,
            spacing: spacing
        )
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? NotchExtensionFrame.contentMaxWidth
        let rows = rows(for: subviews, maxWidth: maxWidth)
        var width: CGFloat = 0
        var height: CGFloat = 0
        for (rowIndex, row) in rows.enumerated() {
            let sizes = row.map { subviews[$0].sizeThatFits(.unspecified) }
            width = max(width, sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(row.count - 1, 0)))
            height += (sizes.map(\.height).max() ?? 0) + (rowIndex > 0 ? spacing : 0)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            var rowHeight: CGFloat = 0
            for index in row {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + spacing
        }
    }
}
