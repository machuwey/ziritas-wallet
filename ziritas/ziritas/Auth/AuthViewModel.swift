
import Foundation
import ComposableArchitecture
import LocalAuthentication

class AuthViewModel: ObservableObject {
        
    let accountStore: StoreOf<AccountFeature>
    
    init(accountStore: StoreOf<AccountFeature>) {
        self.accountStore = accountStore
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate yourself to unlock your places."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                if success {
                    Task { @MainActor in
                        self.accountStore.send(.isAuthenticated(true))
                    }
                } else {
                    // error
                }
            }
        } else {
            // no biometrics
        }
    }    
}
