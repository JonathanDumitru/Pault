// Pault/Views/ProBadge.swift
import SwiftUI

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .accessibilityLabel("Pro feature")
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    ProBadge()
        .padding()
}
