import Foundation
import StoreKit

@MainActor
final class MembershipStore: ObservableObject {
    nonisolated static let lifetimeProductID = "com.phil.AcoustaLab.lifetime"
    nonisolated static let monthlyProductID = "com.phil.AcoustaLab.pro.monthly"
    nonisolated static let yearlyProductID = "com.phil.AcoustaLab.pro.yearly"
    private static let trialStartDateKey = "trial_start_date"
    private static let trialDurationDays = 3

    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var hasLifetimeUnlock = false
    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var activeSubscriptionProductID: String?
    @Published private(set) var isLoadingProduct = false
    @Published var alertMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        if UserDefaults.standard.object(forKey: Self.trialStartDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: Self.trialStartDateKey)
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var hasCoreAccess: Bool {
        hasPaidAccess || trialDaysRemaining > 0
    }

    var hasPaidAccess: Bool {
        hasLifetimeUnlock || hasActiveSubscription
    }

    var trialDaysRemaining: Int {
        guard let startDate = UserDefaults.standard.object(forKey: Self.trialStartDateKey) as? Date else {
            return Self.trialDurationDays
        }

        let elapsed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(Self.trialDurationDays - elapsed, 0)
    }

    var statusText: String {
        if hasLifetimeUnlock {
            return String(localized: "membership.status_lifetime")
        }

        if hasActiveSubscription {
            return String(localized: "membership.status_subscription")
        }

        if trialDaysRemaining > 0 {
            return String(format: String(localized: "membership.status_trial_days"), trialDaysRemaining)
        }

        return String(localized: "membership.status_expired")
    }

    var lifetimeProduct: Product? {
        productsByID[Self.lifetimeProductID]
    }

    var monthlyProduct: Product? {
        productsByID[Self.monthlyProductID]
    }

    var yearlyProduct: Product? {
        productsByID[Self.yearlyProductID]
    }

    func product(for plan: MembershipPlan) -> Product? {
        productsByID[plan.productID]
    }

    func purchaseButtonTitle(for plan: MembershipPlan) -> String {
        guard let product = product(for: plan) else {
            return isLoadingProduct
                ? String(localized: "membership.loading_product")
                : String(localized: "membership.product_unavailable")
        }

        return String(format: String(localized: "membership.purchase_price"), product.displayPrice)
    }

    func configure() async {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: update)
            }
        }

        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            let products = try await Product.products(for: MembershipPlan.allCases.map(\.productID))
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            productsByID = [:]
        }
    }

    func purchaseLifetime() async {
        await purchase(.lifetime)
    }

    func purchase(_ plan: MembershipPlan) async {
        guard let product = product(for: plan) else {
            alertMessage = String(localized: "membership.product_unavailable_body")
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transactionResult: verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            alertMessage = String(localized: "membership.purchase_failed")
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            alertMessage = hasPaidAccess
                ? String(localized: "membership.restore_success")
                : String(localized: "membership.restore_empty")
        } catch {
            alertMessage = String(localized: "membership.restore_failed")
        }
    }

    private func refreshEntitlements() async {
        var lifetimeUnlocked = false
        var subscriptionUnlocked = false
        var activeSubscriptionID: String?
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else {
                continue
            }

            if transaction.productID == Self.lifetimeProductID {
                lifetimeUnlocked = true
            } else if MembershipPlan.subscriptionProductIDs.contains(transaction.productID),
                      (transaction.expirationDate ?? .distantFuture) > now {
                subscriptionUnlocked = true
                activeSubscriptionID = transaction.productID
            }
        }

        hasLifetimeUnlock = lifetimeUnlocked
        hasActiveSubscription = subscriptionUnlocked
        activeSubscriptionProductID = activeSubscriptionID
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            if transaction.productID == Self.lifetimeProductID {
                hasLifetimeUnlock = transaction.revocationDate == nil
            } else if MembershipPlan.subscriptionProductIDs.contains(transaction.productID) {
                let isActive = transaction.revocationDate == nil && (transaction.expirationDate ?? .distantFuture) > Date()
                hasActiveSubscription = isActive
                activeSubscriptionProductID = isActive ? transaction.productID : nil
            }
            await transaction.finish()
        case .unverified:
            alertMessage = String(localized: "membership.purchase_unverified")
        }
    }
}

enum MembershipPlan: CaseIterable, Identifiable {
    case yearly
    case monthly
    case lifetime

    var id: String { productID }

    var productID: String {
        switch self {
        case .yearly:
            return MembershipStore.yearlyProductID
        case .monthly:
            return MembershipStore.monthlyProductID
        case .lifetime:
            return MembershipStore.lifetimeProductID
        }
    }

    var title: String {
        switch self {
        case .yearly:
            return String(localized: "membership.yearly")
        case .monthly:
            return String(localized: "membership.monthly")
        case .lifetime:
            return String(localized: "membership.lifetime")
        }
    }

    var subtitle: String {
        switch self {
        case .yearly:
            return String(localized: "membership.yearly_body")
        case .monthly:
            return String(localized: "membership.monthly_body")
        case .lifetime:
            return String(localized: "membership.lifetime_body")
        }
    }

    var badge: String? {
        switch self {
        case .yearly:
            return String(localized: "membership.best_value")
        case .monthly, .lifetime:
            return nil
        }
    }

    static var subscriptionProductIDs: Set<String> {
        [MembershipStore.monthlyProductID, MembershipStore.yearlyProductID]
    }
}
