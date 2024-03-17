import SwiftUI
import ComposableArchitecture
import Starknet
import BigInt
struct SendFundsView: View {
    var viewModel: ContentViewViewModel
    let token: Token
    @State private var selectedPercentage: Float = 0
    @State private var destinationAddress: String
    @State private var transferAmount: String = ""
    let accountStore: StoreOf<AccountFeature>
    private let percentages: [Float] = [0.25, 0.50, 0.75, 1.00]
    var receiverStore :StoreOf<ReceiverFeature>?
    
    
    init(accountStore: StoreOf<AccountFeature>, token: Token?, receiverPayload: StoreOf<ReceiverFeature>?) {
        self.accountStore = accountStore
        
        viewModel = ContentViewViewModel(accountStore: accountStore)
        if let tokenFromParent = token {
            self.token = tokenFromParent
        } else {
            self.token = Token(
                image: "tokenImage",
                ticker: "DUMMY",
                address: "0x1234567890abcdef",
                balanceSelector: "balanceOf",
                balance: 100.0,
                totalPrice: 200.0
            )
        }
        
        self.receiverStore = receiverPayload
        if let receiver = receiverPayload {
            self.destinationAddress = receiver.address!
        } else {
            destinationAddress = ""
        }
    }
    
    var body: some View {
        VStack {
            Text("Send \(token.ticker)")
                .font(.title)
            
            Picker("Percentage", selection: $selectedPercentage) {
                ForEach(percentages, id: \.self) { percentage in
                    Text("\(Int(percentage * 100))%").tag(percentage)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            TextField("Destination Address", text: $destinationAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .disabled(receiverStore != nil)
            
            TextField("Amount", text:$transferAmount)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Sign & Send") {
                Task {
                    await signAndSendTransaction(tranferAm: transferAmount)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .onChange(of: selectedPercentage) { newValue in
            calculateAmount(for: newValue)
        }
    }
    private func calculateAmount(for percentage: Float) {
        let amount = Float(token.balance) * percentage
        transferAmount = String(format: "%g", amount)
    }
    private func signAndSendTransaction(tranferAm:String) async {
        // Validate the destination address and amount
        guard !destinationAddress.isEmpty else {
            viewModel.errorMessage = "Invalid address or amount"
            return
        }
        
        guard  let doubleValue = Float(tranferAm) else { return }
        
        guard let amount = convertToWei(amount: tranferAm) else {
            return
        }
        
        let (high, low) = amount.quotientAndRemainder(dividingBy: BigUInt(2).power(128))
        
        let destination_felt: Felt = Felt.init(fromHex: destinationAddress)!
        guard let user_address =  accountStore.address else { return }
        let token_address: Felt = Felt(fromHex: token.address)!
        // Sign the transaction
        let call = StarknetCall(
            contractAddress: token_address,
            entrypoint: starknetSelector(from: "transfer"),
            calldata: [destination_felt, low.toFelt()!, high.toFelt()!]
        )
        
        
        do {
            let transaction = try await viewModel.signTransaction_execute(calls: [call], params: nil)
        } catch {
            print(error)
        }
        
    }
    
    func convertToWei(amount: String) -> BigUInt? {
        // Assuming the amount is a string representing a decimal number
        guard let decimal = Decimal(string: amount) else { return nil }
        let weiMultiplier = Decimal(string: "1000000000000000000")! // 1e18
        let multiplied = (decimal * weiMultiplier)
        return BigUInt(multiplied.description)
    }
}

// Define the TransferTransaction struct
struct TransferTransaction {
    let from: String
    let to: String
    let amount: Float
    let token: Token
}
