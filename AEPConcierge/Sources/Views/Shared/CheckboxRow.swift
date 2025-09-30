//
//  CheckboxRow.swift
//  AEPConcierge
//
//  Created by Tim Kim on 9/4/25.
//

import SwiftUI

struct CheckboxRow: View {
    @Binding var isOn: Bool
    let label: String
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(checkboxBorderColor, lineWidth: 1.25)
                        .frame(width: 20, height: 20)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(RoundedRectangle(cornerRadius: 6).fill(accent))
                    }
                }
                .frame(width: 44, height: 44)
                Text(label)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var checkboxBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.35)
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


