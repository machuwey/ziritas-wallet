import SwiftUI
import ComposableArchitecture
import Starknet
struct CreateMoaView: View {
    
    
    @State private var qrImage: UIImage?
    @State private var curHeight: CGFloat = 400
    @State private var name = "Anonymous"
    @State private var emailAddress = "you@yoursite.com"
    @State private var qrCode = UIImage()
    @State private var showingCopyHint = false
    @State private var showingMoaResultModal = false
    @State private var moaResult: MoaResult? = nil
    @State private var showDeploymentSuccess = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    let sessionIdJoin: String?
    
    var onDismiss: ((MoaResult) -> Void)?
    
    let minHeight: CGFloat = 400
    let maxHeight: CGFloat = 700
    
    let qrURLImage = URL(string: "https://www.avanderlee.com")?.qrImage(using: UIColor(red:0.93, green:0.31, blue:0.23, alpha:1.00))
    
    let context = CIContext()
    let filter = CIFilter(name: "CIQRCodeGenerator")
    @State private var participantWeights: [String: Int] = [:]
    
    
    let accountStore: StoreOf<AccountFeature>
    let moaSessionStore: StoreOf<MOASessionFeature>
    @ObservedObject var viewModel = MoaViewModel()
    let contentViewModel: ContentViewViewModel
    let colorHexCodeAssigned = String(format: "#%06X", Int.random(in: 0x000000...0xFFFFFF))
    
    @State private var dummyParticipant = Participant(
        id: "0x1234567890abcdef",
        publicKey: Felt(fromHex: "0x1234567890abcdef")!,
        username: "DummyUser",
        colorHexCode: "#FF0000"
    )
    
    @State var sigThreshold: Double = 0.0

    @State private var isEditing = false
    
    @State private var selectedMode: String = "Simple"
    let modes = ["Simple", "Weighted"]
    
    init(accountStore: StoreOf<AccountFeature>, sessionIdToJoin: String? = nil, onDismiss: ((MoaResult) -> Void)? = nil) {
        self.accountStore = accountStore
        self.sessionIdJoin = sessionIdToJoin
        self.onDismiss = onDismiss
        guard let address = accountStore.state.address?.toHex() else {
            fatalError("Localized error: Address not found.")
        }
        if (sessionIdToJoin == nil) {
            self.moaSessionStore = Store(initialState: MOASessionFeature.State(proposerAddress: address)){
                MOASessionFeature()._printChanges()
            }
        } else {
            self.moaSessionStore = Store(initialState: MOASessionFeature.State()){
                MOASessionFeature()._printChanges()
            }
        }
        self.contentViewModel = ContentViewViewModel(accountStore: accountStore)
    }
    @State var sessionId: String?
    
    var body: some View{
        if !showDeploymentSuccess {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Create Group Account")
                    .font(.title)
                    .fontWeight(.semibold)
                WithViewStore(moaSessionStore, observe: { $0 }) { moaSessionStore in
                    if moaSessionStore.proposerAddress == accountStore.address?.toHex() {
                        Picker("Mode", selection: $selectedMode) {
                            ForEach(modes, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    if moaSessionStore.wallet_participants.isEmpty || moaSessionStore.wallet_participants.count == 1 {
                        HStack(spacing: 30) {
                            // Your account button
                            Button(action: {
                                // Handle your account action
                            }) {
                                VStack {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color(hex: colorHexCodeAssigned))
                                        .clipShape(Circle())
                                    Text("Me")
                                }
                            }
                        }
                    } else {
                        ForEach(moaSessionStore.wallet_participants) { participant in
                            HStack {
                                Spacer()
                                VStack(alignment: .center) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color(hex: participant.colorHexCode))
                                        .clipShape(Circle())
                                        .overlay(
                                            selectedMode == "Weighted" ?
                                            Text("\(participantWeights[participant.id] ?? 1)")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(4)
                                                .background(Color.black.opacity(0.7))
                                                .clipShape(Circle())
                                                .offset(x: 20, y: -20)
                                            : nil
                                        )
                                    // Display "Me" for the current user, otherwise display the participant's username
                                    Text(participant.id == accountStore.address?.toHex() ? "Me" : participant.username)
                                    
                                    
                                }
                                if selectedMode == "Weighted" && moaSessionStore.proposerAddress == accountStore.address?.toHex() {
                                    Stepper(value: Binding(
                                        get: { participantWeights[participant.id] ?? 1 },
                                        set: { newValue in
                                            participantWeights[participant.id] = newValue
                                        }
                                    ), in: 1...10){
                                        //
                                    }
                                    .labelsHidden()
                                    .rotationEffect(.degrees(-90)) // Rotate the stepper 90 degrees counterclockwise
                                }
                                Spacer()
                            }
                        }
                    }
                    if let deeplink = moaSessionStore.sessionDeepLink {
                        ShareLink(item: deeplink)
                        {
                            VStack {
                                Image(systemName: "plus.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                    .padding()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                                            .foregroundColor(.gray)
                                    )
                                Text("Add")
                            }
                        }
                    } else {
                        EmptyView()
                    }
                    Spacer()
                    if moaSessionStore.proposerAddress == accountStore.address?.toHex() {
                        
                        
                        /*
                         Button(action: {
                         moaSessionStore.send(.addParticipant(dummyParticipant))
                         }) {
                         Text("Add Dummy Participant")
                         .padding()
                         .background(Color.gray)
                         .foregroundColor(.white)
                         .cornerRadius(10)
                         }
                         */
                       
                            let weights = moaSessionStore.wallet_participants.map { participantWeights[$0.id] ?? 1 }
                            let minWeight = weights.min() ?? 1
                            let maxWeight = max(weights.reduce(0, +), minWeight + 1)
                            
                            VStack {
                                Text("Threshold")
                                    .font(.headline)
                                
                                Slider(
                                    value: Binding(
                                        get: { Double(sigThreshold) },
                                        set: { newValue in
                                            sigThreshold = min(newValue, Double(maxWeight))
                                        }
                                    ),
                                    in: Double(minWeight)...Double(maxWeight),
                                    step: 1,
                                    onEditingChanged: { editing in
                                        isEditing = editing
                                    }
                                )
                                
                                Text("\(Int(sigThreshold))")
                                    .foregroundColor(isEditing ? .red : .blue)
                            }
                            .padding()
                        
                        
                        
                        Button(action: {
                            ///
                            Task {
                                deployMoaAccount()
                            }
                        }){
                            Text("Deploy moa account")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                        Spacer(minLength: 20) // Add a spacer or margin below the button
                    }
                }
                .onAppear {
                    guard let address = accountStore.address, let publicKey = accountStore.public_key_felt else {
                        // Handle error: address or public key not found
                        return
                    }
                    // Generate a random color hex code for the participant
                    let colorHexCode = colorHexCodeAssigned
                    let participant = Participant(id: address.toHex(), publicKey: publicKey, username: "TestUser", colorHexCode: colorHexCode)
                    
                    if let sessionIdJoin = sessionIdJoin {
                        joinSession(with: participant, sessionId: sessionIdJoin)
                    } else {
                        createSession(with: participant)
                    }
                }
                
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        // Perform any action you need when the user dismisses the alert
                        self.onDismiss?(.success)
                    }
                )
            }
            .onDisappear {
                self.onDismiss?(.ignore)
            }
        } else {
            VStack(){
                Spacer()
                Text("Deployment was succesfull!")
                Spacer()
            }
        }
    }
    @State private var prevDragTranslation = CGSize.zero
    var dragGesture: some Gesture{
        
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { val in
                let dragAmount = val.translation.height - prevDragTranslation.height
                if curHeight > maxHeight || curHeight < minHeight {
                    curHeight -= dragAmount / 6
                }else{
                    curHeight -= dragAmount
                }
                prevDragTranslation = val.translation
            }
            .onEnded { val in
                prevDragTranslation = .zero
            }
    }
    
    func updateCode() {
        guard let address_string = accountStore.address?.toHex() else { return }
        qrCode = generateQRCode(from: address_string )
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let data = string.data(using: String.Encoding.ascii)
        filter?.setValue(data, forKey: "inputMessage")
        
        if let outputImage = filter?.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
    
    func deployMoaAccount() {
        let weights = selectedMode == "Weighted" ? moaSessionStore.wallet_participants.map { participantWeights[$0.id] ?? 1 } : Array(repeating: 1, count: moaSessionStore.wallet_participants.count)
        
        contentViewModel.deployMoaAccountWithCompletion(participants: moaSessionStore.wallet_participants, weights: weights, threshold: Int(sigThreshold)) { result in
            switch result {
            case .success(let deploymentResult):
                print("Deployment successful: \(deploymentResult.response.transactionHash)")
                alertTitle = "Success"
                alertMessage = "The moa account has been created successfully."
                viewModel.updateDeploymentStatus(sessionID: moaSessionStore.sessionId!, status: "success", account_deployed: deploymentResult.deployedContract)
                contentViewModel.saveMoaAccount(address: deploymentResult.deployedContract)
                accountStore.send(.setMoaAccount(deploymentResult.deployedContract))
            case .failure(let error):
                print("Deployment failed: \(error.localizedDescription)")
                alertTitle = "Failure"
                alertMessage = "There was a problem creating the moa account."
                viewModel.updateDeploymentStatus(sessionID: moaSessionStore.sessionId!, status: "failure", account_deployed: Felt(clamping: 0))
            }
            showingAlert = true
        }
    }
    
    func joinSession(with participant: Participant, sessionId: String) {
        viewModel.joinMultiOwnerSession(participant: participant, sessionID: sessionId) {  session, error in
            guard let session = session else {
                return
            }
            self.updateSessionState(with: session, participant: participant, deepLink: nil)
        }
    }
    
    func createSession(with participant: Participant) {
        viewModel.generateMultiOwnerCreateSession(participant: participant) { sessionID, error in
            guard let sessionID = sessionID, let deepLink = self.viewModel.createDeepLink(sessionID: sessionID) else {
                // Handle error: session creation failed
                return
            }
            self.qrCode = self.generateQRCode(from: deepLink.absoluteString)
            self.sessionId = sessionID
            self.updateSessionState(with: sessionID, participant: participant, deepLink: deepLink)
        }
    }
    
    func updateSessionState(with sessionId: String, participant: Participant, deepLink: URL?) {
        listenForSessionUpdates(sessionID: sessionId)
        moaSessionStore.send(.setSessionId(sessionId))
        moaSessionStore.send(.addParticipant(participant))
        if let deepLink = deepLink {
            moaSessionStore.send(.setDeepLink(deepLink))
        }
    }
}

struct CreateMoaView_Previews: PreviewProvider {
    static let dummyToken = Token(
        image: "tokenImage", // The name of the image in your asset catalog
        ticker: "TOKEN_NOT_SELECTED",
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

extension CreateMoaView {
    func listenForSessionUpdates(sessionID: String) {
        let sessionRef = DataManager.shared.db.collection("moaSession").document(sessionID)
        sessionRef.addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot, error == nil else {
                print("Error fetching session updates: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            // Listen for changes in participants
            if let data = document.data(), let participantsData = data["participants"] as? [[String: Any]] {
                let participants = participantsData.compactMap { participantDict -> Participant? in
                    guard let id = participantDict["id"] as? String,
                          let publicKey = participantDict["publicKey"] as? String,
                          let username = participantDict["username"] as? String,
                          let colorHexCode = participantDict["colorHexCode"] as? String else {
                        return nil
                    }
                    return Participant(id: id, publicKey: Felt(fromHex: publicKey)!, username: username, colorHexCode: colorHexCode)
                }
                DispatchQueue.main.async {
                    self.moaSessionStore.send(.setWalletPartipants(participants))
                }
            }
            // Listen for changes in deployment status
            if let deploymentStatus = document.data()?["deploymentStatus"] as? String {
                DispatchQueue.main.async {
                    // Update the state variable based on the deployment status
                    self.showingAlert = (deploymentStatus == "success")
                    
                    if deploymentStatus == "success",
                       let accountDeployed = document.data()?["accountDeployed"] as? String,
                       let accountrDeployedFelt = Felt(fromHex: accountDeployed) {
                        self.accountStore.send(.setMoaAccount(accountrDeployedFelt))
                        contentViewModel.saveMoaAccount(address: accountrDeployedFelt)
                    }
                }
            }
        }
    }
}
