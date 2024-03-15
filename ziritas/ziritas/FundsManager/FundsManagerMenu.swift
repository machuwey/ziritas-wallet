import SwiftUI
import ComposableArchitecture


struct sendFundsPayload: Hashable {
    var account: StoreOf<AccountFeature>
    var token: Token?
}
struct FundsManagerMenu: View {
    
    @State private var showQR = false
    var accountStore :StoreOf<AccountFeature>

    var token: Token?
    let viewModel: FundManagerViewModel
    @State private var navigateToSendView = false
    @State private var selection: sendFundsPayload
    
    
    
    
    init(accountStore: StoreOf<AccountFeature>, token: Token) {
        self.accountStore = accountStore
        self.token = token
        viewModel = FundManagerViewModel(accountStore: accountStore)
        selection = .init(account: accountStore, token: token)
            
    }
    
    
    
    var body: some View {
        
        VStack {
            Spacer()
            
            // Main buttons
            VStack(spacing: 20) {
                
                NavigationLink(value: selection){
                
                        VStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue)
                            Text("Send")
                                .foregroundColor(.blue)
                        }
                    
                    
                }
                
                
                
                Button(action: {
                    //self.showQR = true
                    NotificationCenter.default.post(name: Notification.Name("ShowQRView"), object: nil)
                }) {
                        VStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue)
                            Text("Receive")
                                .foregroundColor(.blue)
                        }
                    }
                
                Button(action: {
                    //
                }) {
                    VStack {
                        Image(systemName: "arrow.2.circlepath.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.blue)
                        Text("Swap")
                            .foregroundColor(.blue)
                    }
                }
                
               
            }
            
            Spacer()
            
        }
        
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .statusBar(hidden: true)
        
        
        .navigationDestination(for: sendFundsPayload.self) { sendFundPayload in
            SendFundsView(accountStore: sendFundPayload.account, token: sendFundPayload.token, receiverPayload: nil)
        }
    }
}


struct FundsManagerMenu_Previews: PreviewProvider {
    static let dummyToken = Token(
        image: "tokenImage", // The name of the image in your asset catalog
        ticker: "DUMMY",
        address: "0x1234567890abcdef",
        balanceSelector: "balanceOf",
        balance: 100.0,
        totalPrice: 200.0
    )
    static let accountStore = Store(initialState: AccountFeature.State()) {
        AccountFeature()._printChanges()
    }
    
    static var previews: some View {
        FundsManagerMenu(accountStore: accountStore, token: dummyToken)
    }
}
