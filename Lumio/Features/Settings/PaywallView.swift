import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID = SubscriptionManager.yearlyProductID
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .symbolEffect(.bounce)

                        Text("Lumio Premium")
                            .font(LumioTypography.hero)

                        Text("Unlock the full morning briefing experience")
                            .font(LumioTypography.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Feature list
                    VStack(alignment: .leading, spacing: 14) {
                        PremiumFeatureRow(icon: "calendar.badge.plus", color: .blue, text: "Multiple calendars simultaneously")
                        PremiumFeatureRow(icon: "doc.fill", color: .green, text: "Unlimited PDFs & folders")
                        PremiumFeatureRow(icon: "waveform.badge.sparkles", color: .purple, text: "Full audio: events + lecture summaries")
                        PremiumFeatureRow(icon: "bubble.left.and.sparkles.fill", color: .orange, text: "AI chatbot for your day")
                        PremiumFeatureRow(icon: "rectangle.3.group.fill", color: .pink, text: "Home screen widget")
                        PremiumFeatureRow(icon: "brain", color: .indigo, text: "Learns your preferences over time")
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(uiColor: .secondarySystemBackground)))

                    // Product picker
                    VStack(spacing: 10) {
                        ForEach(subscriptionManager.products) { product in
                            ProductOptionRow(
                                product: product,
                                isSelected: selectedProductID == product.id,
                                isBestValue: product.id == SubscriptionManager.yearlyProductID
                            ) {
                                selectedProductID = product.id
                            }
                        }
                    }

                    // Purchase button
                    VStack(spacing: 10) {
                        Button {
                            Task { await purchase() }
                        } label: {
                            Group {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Get Premium")
                                        .font(LumioTypography.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.lumioAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isPurchasing || subscriptionManager.products.isEmpty)

                        if let error = purchaseError {
                            Text(error)
                                .font(LumioTypography.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button("Restore Purchases") {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)

                        Text("Prices shown in EUR. Payment will be charged to your Apple ID account. Subscriptions auto-renew unless cancelled.")
                            .font(LumioTypography.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func purchase() async {
        guard let product = subscriptionManager.products.first(where: { $0.id == selectedProductID }) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await subscriptionManager.purchase(product)
            dismiss()
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let color: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(text)
                .font(LumioTypography.callout)
        }
    }
}

struct ProductOptionRow: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(LumioTypography.callout.weight(.semibold))
                        if isBestValue {
                            Text("Best value")
                                .font(LumioTypography.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green))
                        }
                    }
                    Text(product.description)
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(LumioTypography.callout.weight(.bold))
                    .foregroundStyle(isSelected ? Color.lumioAccent : .primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.lumioAccent.opacity(0.08) : Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.lumioAccent : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}
