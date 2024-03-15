import SwiftUI


struct PinSetupView: View {
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var isPinSet: Bool = false
    @State private var errorMessage: String?
    let keychain = KeychainHelper.standard
    var body: some View {
        VStack {
            if isPinSet {
                Text("PIN successfully set!")
                // Continue to wallet creation or show the main content view
            } else {
                SecureField("Enter a 4-digit PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .padding()
                SecureField("Confirm your 4-digit PIN", text: $confirmPin)
                    .keyboardType(.numberPad)
                    .padding()
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                Button("Set PIN") {
                    setPin()
                }
                .padding()
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }

    private func setPin() {
        guard pin.count == 4 else {
            errorMessage = "PIN must be 4 digits"
            return
        }
        guard pin == confirmPin else {
            errorMessage = "PINs do not match"
            return
        }
        do {
try keychain.save(pin.data(using: .utf8)!, service: "com.strapex.wallet", account: "user-pin")
            isPinSet = true
    // After setting the PIN, dismiss the view and proceed to create the wallet keys.
    // This can be done by using a completion handler or by updating a shared state.
        } catch {
            errorMessage = "Failed to set PIN"
        }
    }
}

struct PinSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PinSetupView()
    }
}
