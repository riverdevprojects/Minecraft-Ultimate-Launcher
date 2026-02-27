// DependencyInstallSheet.swift

import SwiftUI

struct DependencyInstallSheet: View {
    let resolutionResult: DependencyResolutionResult
    let onConfirm: ([DependencyItem]) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOptional: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !resolutionResult.required.isEmpty {
                        requiredSection
                    }
                    if !resolutionResult.optional.isEmpty {
                        optionalSection
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 480, minHeight: 360)
        .onAppear {
            selectedOptional = Set(resolutionResult.optional.map(\.id))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Dependency Mods Found", systemImage: "puzzlepiece.extension")
                .font(.title2)
                .fontWeight(.semibold)
            Text("This mod requires additional mods. Required dependencies will be installed automatically. Select optional ones below.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Required (\(resolutionResult.required.count))")
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(resolutionResult.required) { item in
                DependencyRow(item: item, isSelected: true, isRequired: true, onToggle: nil)
            }
        }
    }

    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Optional (\(resolutionResult.optional.count))")
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(resolutionResult.optional) { item in
                DependencyRow(
                    item: item,
                    isSelected: selectedOptional.contains(item.id),
                    isRequired: false,
                    onToggle: { selected in
                        if selected {
                            selectedOptional.insert(item.id)
                        } else {
                            selectedOptional.remove(item.id)
                        }
                    }
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip All") {
                dismiss()
                onCancel()
            }
            .foregroundStyle(.secondary)

            Spacer()

            Button("Install Selected") {
                let selected = resolutionResult.optional.filter { selectedOptional.contains($0.id) }
                dismiss()
                onConfirm(selected)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }
}

// MARK: - DependencyRow

struct DependencyRow: View {
    let item: DependencyItem
    let isSelected: Bool
    let isRequired: Bool
    let onToggle: ((Bool) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if isRequired {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { onToggle?($0) }
                ))
                .labelsHidden()
            }

            CachedAsyncImage(url: item.mod.logoUrl)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.mod.name)
                    .font(.body)
                Text(item.file.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRequired {
                Text("Required")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            } else {
                Text("Optional")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
