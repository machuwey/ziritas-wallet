

import SwiftUI
import ComposableArchitecture
struct AuthenticationView: View {
    var authModel: AuthViewModel
    var accountStore: StoreOf<AccountFeature>

    init(accountStore: StoreOf<AccountFeature>) {
        self.accountStore = accountStore
        self.authModel = AuthViewModel(accountStore: accountStore)
    }

    var body: some View {
        Text("Please verify yourself")
            .onAppear {
                print("Heyay")
                if let developmentValue = ProcessInfo.processInfo.environment["DEVELOPMENT"], developmentValue == "true" {
                    accountStore.send(.isAuthenticated(true))
                } else {
                    authModel.authenticate()
                }
            }
    }
}

struct Authentication_Preview: PreviewProvider {
    
    // Assuming you have a way to initialize the AccountFeature.State
    static let accountStore = Store(initialState: AccountFeature.State()) {
        AccountFeature()._printChanges()
    }
    
    static var previews: some View {
        AuthenticationView(accountStore: accountStore)
    }
}
