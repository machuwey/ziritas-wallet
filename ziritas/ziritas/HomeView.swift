import SwiftUI
import ComposableArchitecture
import CodeScanner
struct HomeView: View {
    var viewModel: ContentViewViewModel?
    @State private var isPresentingPinSetup = false
    @State private var isPresentingPinVerification = false
    @State private var selectedTokenIndex: Int? = nil
    @State private var isLoadingTotalBalance = true
    @State private var showingSettings = false
    @State private var showingQRCodeScanner = false
    @State private var showingSendToAdress = false
    var accountStore: StoreOf<AccountFeature>
    var originalStore: StoreOf<AccountFeature>
    var paymentStore: StoreOf<ReceiverFeature>?
    init(accountStore: StoreOf<AccountFeature>){
        self.accountStore = accountStore
        self.viewModel = ContentViewViewModel(accountStore: accountStore)
        self.originalStore = accountStore
        self.paymentStore = Store(initialState: ReceiverFeature.State()) {
            ReceiverFeature()._printChanges()
        }
    }
    
    var body: some View {
        WithViewStore(accountStore, observe: { $0 }) { accountStore in
            NavigationStack{
                VStack {
                    Image(.frame9)
                        .resizable()
                        .frame(width: 40, height: 40)
                    if accountStore.isLoading {
                        Text("Loading...")
                            .redacted(reason: .placeholder)
                            .onAppear {
                                // Simulate a delay for loading the total balance
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    // Set isLoadingTotalBalance to false after the data is loaded
                                    isLoadingTotalBalance = false
                                }
                            }
                    } else {
                        Text(String(format: "%.2f USD", accountStore.totalPortfolioValue ?? 0.00))
                            .fontWeight(.bold)
                            .font(.system(size: 48))
                    }
                    Text("Address:")
                        .padding()
                    HStack {
                        Text(accountStore.address?.toHex() ?? "")
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = accountStore.address?.toHex()
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding()
                    .padding()
                    VStack {
                        Text("Token Balance").font(.headline).padding()
                        List {
                            if accountStore.isLoading {
                                // Simulate two placeholder rows
                                ForEach(0..<2, id: \.self) { _ in
                                    HStack {
                                        Text("Loading...")
                                            .redacted(reason: .placeholder)
                                        Spacer()
                                        Image(systemName: "photo")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .redacted(reason: .placeholder)
                                    }
                                    .padding()
                                }
                            } else {
                                // Actual data rows
                                ForEach(accountStore.tokens, id: \.address) { token in
                                    NavigationLink(value: token) {
                                        HStack {
                                            Text("\(token.balance, specifier: "%.6f") \(token.ticker)")
                                                .padding(.trailing, 8)
                                            Image(uiImage: UIImage(imageLiteralResourceName: token.image))
                                                .resizable()
                                                .frame(width: 20, height: 20)
                                        }
                                        .padding()
                                    }
                                }
                            }
                        }
                    }
                    //.redacted(reason: accountStore.isLoading ? .placeholder : [])
                    .navigationDestination(for: Token.self) { token in
                        
                        FundsManagerMenu(accountStore: self.accountStore, token: token)
                        
                    }
                    
                    if let errorMessage = viewModel?.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showingQRCodeScanner = true
                        }) {
                            Image(systemName: "qrcode.viewfinder")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingsView(acc_store: originalStore), isActive: $showingSettings) {
                            Button(action: {
                                showingSettings = true
                            }) {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingQRCodeScanner) {
                    CodeScannerView(codeTypes: [.qr], completion: handleScan)
                }
                .sheet(isPresented: $showingSendToAdress) {
                    SendFundsView(accountStore: self.accountStore, token: accountStore.tokens[0], receiverPayload: paymentStore)
                }
                .onAppear {
                    if KeychainHelper.standard.hasPin(service: "com.strapex.wallet", account: "user-pin") {
                        isPresentingPinVerification = true
                    }
                    #warning("potential risk")
                    viewModel?.retrieveWallet()
                }
                /*
                .sheet(isPresented: $isPresentingPinSetup) {
                    PinSetupView()
                }
                // Pin Verification
                .sheet(isPresented: $isPresentingPinVerification, onDismiss: {
                    // Set isAuthenticated to true when the PIN verification view is dismissed
                    accountStore.send(.isAuthenticated(true))
                    // Attempt to retrieve existing wallet
                    if accountStore.isCreatingWallet{
                        viewModel?.createWallet()
                    } else {
                        viewModel?.retrieveWallet()
                    }
                }) {
                    PinVerificationView(onPinVerified: {
                        isPresentingPinVerification = false
                        viewModel?.isAuthenticated = true
                        // Attempt to retrieve existing wallet
                        viewModel?.retrieveWallet()
                    }, onDismiss: {
                        isPresentingPinVerification = false
                    })
                }
                 */
            }
        }
        
    }
    
    func handleScan(result: Result<ScanResult, ScanError>) {
        showingQRCodeScanner = false

        switch result {
        case .success(let result):
            if let url = URL(string: result.string), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let queryItems = components.queryItems
                let address = queryItems?.first(where: { $0.name == "address" })?.value
                let uniqueID = queryItems?.first(where: { $0.name == "uniqueID" })?.value
                print("Address: \(address ?? "Not found"), UniqueID: \(uniqueID ?? "Not found")")
                guard let address = address, let uniqueID = uniqueID else {
                    print("Invalid QR code result.")
                    return
                }
                paymentStore?.send(.setReceiver(address, uniqueID))
                showingSendToAdress = true
            } else {
                print("Invalid QR code result.")
            }

        case .failure(let error):
            print("Scanning failed: \(error.localizedDescription)")
        }
    }
}

struct Home_Previews: PreviewProvider {
    
    static let accountStore = Store(initialState: AccountFeature.State()) {
        AccountFeature()._printChanges()
    }
    
    static var previews: some View {
        HomeView(accountStore: accountStore)
    }
}
