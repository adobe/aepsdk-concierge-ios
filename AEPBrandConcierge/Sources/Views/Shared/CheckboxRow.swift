//
//  CheckboxRow.swift
//  AEPBrandConcierge
//
//  Created by Tim Kim on 9/4/25.
//

import SwiftUI

struct CheckboxRow: View {
    @Binding var isOn: Bool
    let label: String
    let accent: Color
    var cornerRadius: CGFloat = 6
    /// Label text color. Defaults to system `.primary`.
    var labelColor: Color? = nil
    /// Checkbox outline border color. `nil` = adaptive default based on `colorScheme`.
    var borderColor: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(checkboxBorderColor, lineWidth: 1.25)
                        .frame(width: 20, height: 20)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(accent))
                    }
                }
                .frame(width: 44, height: 44)
                labelText
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var labelText: some View {
        if let labelColor {
            Text(label)
                .foregroundStyle(labelColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(label)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var checkboxBorderColor: Color {
        if let borderColor { return borderColor }
        return colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.35)
    }
}

#Preview("CheckboxRow") {
    struct CheckboxRowPreviewHost: View {
        @State private var isOn: Bool = false
        var body: some View {
            CheckboxRow(isOn: $isOn,
                        label: "Helpful and relevant recommendations",
                        accent: .accentColor)
                .padding()
                .background(Color(UIColor.systemBackground))
        }
    }
    return CheckboxRowPreviewHost()
}
