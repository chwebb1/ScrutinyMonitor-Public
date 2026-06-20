//
//  SidebarActionBar.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//
import SwiftUI

public struct SidebarActionBar: View {
    var selectedInstallationName: String?
    var onAddInstallation: () -> Void
    var onEditInstallation: () -> Void
    var onDeleteInstallation: () -> Void

    public var body: some View {
        // ⚡ Bolt: Extracted optional unwrapping and string interpolation out of the ViewBuilder
        // and replaced inline `.map` to avoid closure allocations during render passes.
        // Using a single `if let` safely unwraps without forced unwrapping and redundant string interpolation.
        let editLabel: String
        let editHelp: String
        let deleteLabel: String
        let deleteHelp: String

        if let name = selectedInstallationName {
            let editBase = "Edit \(name)"
            let deleteBase = "Delete \(name)"
            editLabel = editBase
            editHelp = "\(editBase) (⌘E)"
            deleteLabel = deleteBase
            deleteHelp = "\(deleteBase) (⌘⌫)"
        } else {
            editLabel = "Edit Installation"
            editHelp = "Select an installation to edit (⌘E)"
            deleteLabel = "Delete Installation"
            deleteHelp = "Select an installation to delete (⌘⌫)"
        }

        return VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Button(action: onAddInstallation) {
                    Label("Add Installation", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add Installation")
                .help("Add Scrutiny installation (⌘N)")
                .keyboardShortcut("n", modifiers: .command)

                Button(action: onEditInstallation) {
                    Label("Edit Installation", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(editLabel)
                .disabled(selectedInstallationName == nil)
                .help(editHelp)
                .keyboardShortcut("e", modifiers: .command)

                Button(role: .destructive, action: onDeleteInstallation) {
                    Label("Delete Installation", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(deleteLabel)
                .disabled(selectedInstallationName == nil)
                .help(deleteHelp)
                .keyboardShortcut(.delete, modifiers: .command)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(.bar)
        }
    }
}
