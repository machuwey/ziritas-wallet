
import Foundation
import ComposableArchitecture

class FundManagerViewModel {
    let accountStore: StoreOf<AccountFeature>

    init(accountStore: StoreOf<AccountFeature>) {
        self.accountStore = accountStore
    }
}

