import SwiftUI

struct MembershipSettingsCard: View {
    @ObservedObject var membershipStore: MembershipStore
    let showMembership: () -> Void

    var body: some View {
        InstrumentCard(fill: AppTheme.cardStrong) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        SectionTitle(title: String(localized: "settings.subscription"))
                        Text(String(localized: "settings.subscription_body"))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer(minLength: 10)

                    StatusBadge(
                        title: membershipStore.hasPaidAccess
                            ? String(localized: "membership.full_access")
                            : String(localized: "membership.free_trial"),
                        tone: membershipStore.hasCoreAccess ? .success : .warning,
                        icon: membershipStore.hasPaidAccess ? "checkmark.seal.fill" : "clock"
                    )
                }

                DetailTile(
                    title: String(localized: "membership.title"),
                    value: membershipStore.statusText,
                    caption: String(localized: "membership.settings_body"),
                    accentColor: membershipStore.hasCoreAccess ? AppTheme.success : AppTheme.warning
                )

                Button(String(localized: "membership.manage"), action: showMembership)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

struct MembershipLockedPage: View {
    let featureTitle: String
    @ObservedObject var membershipStore: MembershipStore
    let showMembership: () -> Void

    var body: some View {
        NavigationStack {
            AdaptiveDashboard {
                Spacer(minLength: 24)

                InstrumentCard(fill: AppTheme.cardStrong) {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.warning)

                        VStack(alignment: .leading, spacing: 8) {
                            SectionTitle(title: String(format: String(localized: "membership.locked_title"), featureTitle))
                            Text(String(localized: "membership.locked_body"))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Button(String(localized: "membership.view_options"), action: showMembership)
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }

                Spacer(minLength: 24)
            }
            .navigationTitle(featureTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MembershipPaywallView: View {
    @ObservedObject var membershipStore: MembershipStore
    let close: () -> Void

    var body: some View {
        NavigationStack {
            AdaptiveDashboard {
                InstrumentCard(fill: AppTheme.cardStrong) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(AppTheme.accent)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "membership.paywall_title"))
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)

                                Text(String(localized: "membership.paywall_body"))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            includedRow(String(localized: "membership.includes_tone"))
                            includedRow(String(localized: "membership.includes_sweep"))
                            includedRow(String(localized: "membership.includes_noise"))
                            includedRow(String(localized: "membership.includes_presets"))
                        }

                        VStack(spacing: 10) {
                            ForEach(MembershipPlan.allCases) { plan in
                                purchaseRow(for: plan)
                            }
                        }

                        Button(String(localized: "membership.restore")) {
                            Task { await membershipStore.restorePurchases() }
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button(String(localized: "membership.close"), action: close)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
            .navigationTitle(String(localized: "membership.title"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                String(localized: "membership.title"),
                isPresented: Binding(
                    get: { membershipStore.alertMessage != nil },
                    set: { if !$0 { membershipStore.alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    membershipStore.alertMessage = nil
                }
            } message: {
                Text(membershipStore.alertMessage ?? "")
            }
        }
    }

    private func includedRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.success)
                .frame(width: 18, height: 18)

            Text(text)
                .font(.caption)
                .foregroundStyle(.white)
        }
    }

    private func purchaseRow(for plan: MembershipPlan) -> some View {
        let product = membershipStore.product(for: plan)
        let isCurrentPlan = isCurrent(plan)

        return Button {
            Task { await membershipStore.purchase(plan) }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.black.opacity(0.82))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppTheme.accent))
                        }

                        if isCurrentPlan {
                            Text(String(localized: "membership.current_plan"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.success)
                        }
                    }

                    Text(plan.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(product?.displayPrice ?? membershipStore.purchaseButtonTitle(for: plan))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)

                    Text(String(localized: "membership.continue"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isCurrentPlan ? AppTheme.accent.opacity(0.16) : Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isCurrentPlan ? AppTheme.accent.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(product == nil || membershipStore.isLoadingProduct || isCurrentPlan)
        .opacity(product == nil && !membershipStore.isLoadingProduct ? 0.62 : 1)
    }

    private func isCurrent(_ plan: MembershipPlan) -> Bool {
        switch plan {
        case .lifetime:
            return membershipStore.hasLifetimeUnlock
        case .monthly, .yearly:
            return membershipStore.activeSubscriptionProductID == plan.productID
        }
    }
}
