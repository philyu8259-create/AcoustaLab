import Foundation
import StoreKit

@MainActor
final class MembershipStore: ObservableObject {
    static let lifetimeProductID = "com.phil.AcoustaLab.lifetime"
    private static let trialStartDateKey = "trial_start_date"
    private static let trialDurationDays = 3

    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var hasLifetimeUnlock = false
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
        hasLifetimeUnlock || trialDaysRemaining > 0
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

        if trialDaysRemaining > 0 {
            return String(format: String(localized: "membership.status_trial_days"), trialDaysRemaining)
        }

        return String(localized: "membership.status_expired")
    }

    var purchaseButtonTitle: String {
        if let displayPrice = lifetimeProduct?.displayPrice {
            return String(format: String(localized: "membership.purchase_price"), displayPrice)
        }

        return lifetimeProduct == nil
            ? String(localized: "membership.loading_product")
            : String(localized: "membership.purchase_lifetime")
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
            lifetimeProduct = try await Product.products(for: [Self.lifetimeProductID]).first
        } catch {
            lifetimeProduct = nil
        }
    }

    func purchaseLifetime() async {
        guard let product = lifetimeProduct else {
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
            alertMessage = hasLifetimeUnlock
                ? String(localized: "membership.restore_success")
                : String(localized: "membership.restore_empty")
        } catch {
            alertMessage = String(localized: "membership.restore_failed")
        }
    }

    private func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.lifetimeProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        hasLifetimeUnlock = unlocked
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        switch transactionResult {
        case .verified(let transaction):
            if transaction.productID == Self.lifetimeProductID {
                hasLifetimeUnlock = transaction.revocationDate == nil
            }
            await transaction.finish()
        case .unverified:
            alertMessage = String(localized: "membership.purchase_unverified")
        }
    }
}
