import SwiftUI
import ComposableArchitecture

struct DevView: View {
    @ObservedObject var viewModel: ContentViewViewModel
    @State private var isPresentingPinSetup = false
    @State private var isPresentingPinVerification = false
    var accountStore: StoreOf<AccountFeature>

    init(accountStore: StoreOf<AccountFeature>){
        self.accountStore = accountStore
        viewModel = ContentViewViewModel(accountStore: accountStore)
    }
    
    var body: some View {
        VStack {
            Text("Strapex").font(.largeTitle).padding()
            Text("Development view").font(.callout)
            Button("Create Wallet") {
                if viewModel.keychain.hasPin(service: "com.strapex.wallet", account: "user-pin") {
                    isPresentingPinVerification = true
                    viewModel.isCreatingWallet = true
                } else {
                    isPresentingPinSetup = true
                }
            }
        }
        .padding()
        //.background(.mainStrapex)
        //.foregroundColor(.buttonText)
        .cornerRadius(10)
        // Present PinVerificationView on app launch if PIN is set
        .onAppear {
            if KeychainHelper.standard.hasPin(service: "com.strapex.wallet", account: "user-pin") {
                isPresentingPinVerification = true
            }
        }
        
        .sheet(isPresented: $isPresentingPinSetup) {
            PinSetupView()
        }
        // Pin Verification
        .sheet(isPresented: $isPresentingPinVerification, onDismiss: {
            // Set isAuthenticated to true when the PIN verification view is dismissed
            viewModel.isAuthenticated = true
            // Attempt to retrieve existing wallet
            if viewModel.isCreatingWallet{
                viewModel.createWallet()
            } else {
                viewModel.retrieveWallet()
            }
        }) {
            PinVerificationView(onPinVerified: {
                isPresentingPinVerification = false
                viewModel.isAuthenticated = true
                // Attempt to retrieve existing wallet
                viewModel.retrieveWallet()
            }, onDismiss: {
                isPresentingPinVerification = false
            })
        }
        

        
    }
}

