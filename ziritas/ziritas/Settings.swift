import SwiftUI
import ComposableArchitecture
import SafariServices
struct SettingsView: View {
    @State private var showingImportAlert = false
    @State private var publicKey: String = ""
    @State private var privateKey: String = ""
    @State var selectedAccount: WalletAccount?
    @State var showMoaCreation: Bool = false
    @State private var isPresentWebView = false
    
    let accountStore: StoreOf<AccountFeature>
    let viewModel: ContentViewViewModel
    init(acc_store: StoreOf<AccountFeature>){
        self.accountStore = acc_store
        self.viewModel = ContentViewViewModel(accountStore: acc_store)
    }
    
    var body: some View {
        
        NavigationView {
            Form {
                Section(header: Text("Accounts")) {
                    //Picker("Select Account", selection: $accountStore.selectedWallet) {
                    // ForEach(accountStore.wallets, id: \.self) { account in
                    //    Text(account.name).tag(account)
                    //}
                    Button(action: {
                        viewModel.createWallet()
                    }){
                        Text("Create Wallet")
                    }
                    
                    Button(action: {
                        self.showingImportAlert = true
                    }){
                        Text("Import Wallet")
                    }
                    .sheet(isPresented: $showingImportAlert) {
                        ImportWalletView(publicKey: $publicKey, privateKey: $privateKey) {
                            // This closure is called when the import action is completed.
                            viewModel.importWallet(publicKey: publicKey, privateKey: privateKey)
                            showingImportAlert = false // Dismiss the sheet
                        }
                    }
                    
                    Button("Verify Uniqness with worldcoin") {
                        isPresentWebView = true
                    }
                    
                    
                    Button(action: {
                        // Handle add account action
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Account")
                        }
                    }
                }
                
                
                Section(header: Text("Multi Owner Accounts")) {
                    HStack {
                        Text(accountStore.moaAccountAdress?.toHex() ?? "No MOA account")
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = accountStore.moaAccountAdress?.toHex()
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding()
                    
                    Button(action: {
                        showMoaCreation = true
                    }){
                        Text("Create Moa Account")
                    }
                    
                }
                
      
                
                Section {
                    Button(action: {
                        Task {
                            try await viewModel.signTransactionMoaExecute(params: nil)
                        }
                    }){
                        Text("Test Moa Execution")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .fullScreenCover(isPresented: $isPresentWebView) {
            SafariView(url: URL(string: "https://verify.ziritas.com/account/\(accountStore.address)")!)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showMoaCreation) {
            CreateMoaView( accountStore: accountStore, sessionIdToJoin: nil, onDismiss: { reason in
                showMoaCreation = false //Dismiss the screen
            })
        }
    }
    
    
    
    func saveMoaAccount() {
        // Save the account to the database
        //viewModel.saveMoaAccount()
    }
}

struct ImportWalletView: View {
    @Binding var publicKey: String
    @Binding var privateKey: String
    var completion: () -> Void // Completion closure
    
    var body: some View {
        VStack {
            TextField("Public Key", text: $publicKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            TextField("Private Key", text: $privateKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Import") {
                completion() // Call the completion closure when the button is tapped
            }
        }
        .padding()
    }
}

struct SafariView: UIViewControllerRepresentable {
    
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        
    }
    
}
