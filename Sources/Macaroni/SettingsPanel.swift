import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case input
    case windows
    case dock
    case finder
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .input: "Mouse & Trackpad"
        case .windows: "Windows"
        case .dock: "Dock"
        case .finder: "Finder"
        case .general: "General"
        }
    }

    var subtitle: String {
        switch self {
        case .input: "Independent scrolling where macOS still links the controls"
        case .windows: "Fast placement of the active window"
        case .dock: "Make the Dock appear and disappear instantly"
        case .finder: "Useful file-management controls"
        case .general: "Startup, permissions, and restoration"
        }
    }

    var systemImage: String {
        switch self {
        case .input: "computermouse"
        case .windows: "rectangle.3.group"
        case .dock: "dock.rectangle"
        case .finder: "folder"
        case .general: "gearshape"
        }
    }
}

struct SettingsPanel: View {
    @ObservedObject var model: AppModel
    @State private var selection: SettingsSection = .input

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Macaroni")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } detail: {
            VStack(spacing: 0) {
                sectionHeader
                Divider()

                ScrollView {
                    selectedSection
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                if let error = model.lastError {
                    Divider()
                    errorBanner(error)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 780, height: 560)
        .onAppear {
            model.refreshAccessibility()
            model.refreshFinderExtension()
        }
    }

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(selection.title)
                    .font(.title2.bold())
                Text(selection.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var selectedSection: some View {
        switch selection {
        case .input:
            inputSettings
        case .windows:
            windowSettings
        case .dock:
            dockSettings
        case .finder:
            finderSettings
        case .general:
            generalSettings
        }
    }

    private var inputSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Scroll direction") {
                VStack(alignment: .leading, spacing: 12) {
                    directionPicker(
                        "Trackpad",
                        selection: model.trackpadDirection,
                        set: model.setTrackpadDirection
                    )
                    directionPicker(
                        "Mouse wheel",
                        selection: model.mouseDirection,
                        set: model.setMouseDirection
                    )
                    Text("macOS displays both switches, but they still share one base direction. Macaroni intercepts only discrete physical mouse-wheel events when your choices differ.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }

            GroupBox("Trackpad") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(
                        "Disable trackpad acceleration",
                        isOn: binding(model.disableTrackpadAcceleration, model.setDisableTrackpadAcceleration)
                    )
                    Text("Mouse acceleration is available natively in System Settings → Mouse → Advanced.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }

            accessibilityCard
        }
    }

    private var windowSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Window snapping") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(
                        "Enable global window shortcuts",
                        isOn: binding(model.windowSnappingEnabled, model.setWindowSnappingEnabled)
                    )
                    Toggle(
                        "Snap windows when dragged to screen edges",
                        isOn: binding(model.windowDragSnappingEnabled, model.setWindowDragSnappingEnabled)
                    )

                    Text("Drag a window to the left or right edge for half screen, or to the top edge to maximize it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    ForEach(WindowSnapAction.allCases, id: \.rawValue) { action in
                        HStack {
                            Button(action.title) {
                                model.snapWindow(action)
                            }
                            .frame(width: 110, alignment: .leading)

                            Text(actionExplanation(action))
                                .foregroundStyle(.secondary)
                            Spacer()
                            shortcutBadge(action.shortcutDescription)
                        }
                        .disabled(!model.windowSnappingEnabled)
                    }
                }
                .padding(.top, 6)
            }

            accessibilityCard
        }
    }

    private var dockSettings: some View {
        GroupBox("Dock behavior") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(
                    "Automatically hide and show the Dock",
                    isOn: binding(model.dockAutoHide, model.setDockAutoHide)
                )
                Toggle(
                    "Remove the delay before a hidden Dock appears",
                    isOn: binding(model.instantDockReveal, model.setInstantDockReveal)
                )
                Toggle(
                    "Remove the Dock hide and show animation",
                    isOn: binding(model.disableDockAnimation, model.setDisableDockAnimation)
                )
                Text("Changing these options briefly restarts the Dock so the new behavior takes effect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
    }

    private var finderSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Finder behavior") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(
                        "Show hidden and system files",
                        isOn: binding(model.showHiddenFiles, model.setShowHiddenFiles)
                    )
                    Toggle(
                        "Disable Finder sound effects",
                        isOn: binding(model.disableFinderSounds, model.setDisableFinderSounds)
                    )
                    Toggle(
                        "Add “Quit Finder” to the Finder menu",
                        isOn: binding(model.showQuitFinder, model.setShowQuitFinder)
                    )
                }
                .padding(.top, 6)
            }

            GroupBox("New File menu") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(
                            model.finderExtensionEnabled ? "Finder extension enabled" : "Finder extension needs enabling",
                            systemImage: model.finderExtensionEnabled ? "checkmark.circle.fill" : "puzzlepiece.extension"
                        )
                        .foregroundStyle(model.finderExtensionEnabled ? .green : .orange)
                        Spacer()
                        Button("Manage Extension…") {
                            model.openFinderExtensionSettings()
                        }
                    }
                    Text("Once enabled, New File… appears when you right-click the Desktop or a Finder folder. Macaroni creates a blank file and selects its name so you can rename it inline.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Startup") {
                Toggle(
                    "Launch Macaroni at login",
                    isOn: binding(model.launchAtLogin, model.setLaunchAtLogin)
                )
                .padding(.top, 6)
            }

            accessibilityCard

            GroupBox("Restore") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Restore the scrolling, Dock, Finder, and trackpad-acceleration values captured before Macaroni first changed them.")
                        .foregroundStyle(.secondary)
                    Button("Restore Original Settings") {
                        model.restoreOriginalSettings()
                    }
                }
                .padding(.top, 6)
            }

            GroupBox("About") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Macaroni 0.3.0")
                            .fontWeight(.semibold)
                        Text("Make your Mac feel right.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Quit Macaroni") {
                        model.quit()
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var accessibilityCard: some View {
        GroupBox("Accessibility") {
            HStack {
                Label(
                    model.accessibilityGranted ? "Permission enabled" : "Permission required for independent mouse scrolling, window snapping, and inline Finder rename",
                    systemImage: model.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(model.accessibilityGranted ? .green : .orange)
                Spacer()
                if model.accessibilityGranted {
                    Button("Refresh") {
                        model.refreshAccessibility()
                    }
                } else {
                    Button("Enable…") {
                        model.requestAccessibility()
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func directionPicker(
        _ title: String,
        selection: ScrollDirection,
        set: @escaping (ScrollDirection) -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: Binding(get: { selection }, set: set)) {
                ForEach(ScrollDirection.allCases) { direction in
                    Text(direction.title).tag(direction)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .textSelection(.enabled)
            Spacer()
            Button {
                model.lastError = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }

    private func shortcutBadge(_ shortcut: String) -> some View {
        Text(shortcut)
            .font(.system(.body, design: .rounded).weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func actionExplanation(_ action: WindowSnapAction) -> String {
        switch action {
        case .leftHalf: "Move to the left half"
        case .rightHalf: "Move to the right half"
        case .maximize: "Fill the usable display"
        }
    }

    private func binding(_ value: Bool, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { value }, set: set)
    }
}
