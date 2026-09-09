import AppKit
import SwiftUI

struct QuickMenuPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Macaroni")
                        .font(.headline)
                    Text("Make your Mac feel right.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Windows")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !model.windowSnappingEnabled {
                        Text("Disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    snapButton(.leftHalf, systemImage: "rectangle.lefthalf.inset.filled")
                    snapButton(.maximize, systemImage: "rectangle.inset.filled")
                    snapButton(.rightHalf, systemImage: "rectangle.righthalf.inset.filled")
                }
            }

            if !model.accessibilityGranted {
                Button {
                    model.requestAccessibility()
                } label: {
                    Label("Enable Accessibility…", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(.orange)
            }

            Divider()

            HStack {
                Button("Settings…") {
                    SettingsWindowController.shared.show(model: model)
                }
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button("Quit") {
                    model.quit()
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear {
            model.refreshAccessibility()
            model.refreshFinderExtension()
        }
    }

    private func snapButton(_ action: WindowSnapAction, systemImage: String) -> some View {
        Button {
            model.snapWindow(action)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(action.title)
                    .font(.caption)
                    .lineLimit(1)
                Text(action.shortcutDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
        .buttonStyle(.bordered)
        .disabled(!model.windowSnappingEnabled)
        .help(action.title)
    }

}
