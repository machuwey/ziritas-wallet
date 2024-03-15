import SwiftUI

struct PinVerificationView: View {
    @State private var pin: String = ""
    @State private var errorMessage: String?
    var onPinVerified: (() -> Void)?
    var onDismiss: (() -> Void)?

    let keychain = KeychainHelper.standard
    var body: some View {
        VStack {
            SecureField("Enter your PIN", text: $pin)
                .keyboardType(.numberPad)
                .padding()
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            Button("Verify PIN") {
                verifyPin()
            }
            .padding()
            .background(.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }

    private func verifyPin() {
        do {
            let savedPinData = try keychain.read(service: "com.strapex.wallet", account: "user-pin")
            let savedPin = String(decoding: savedPinData, as: UTF8.self)
            if pin == savedPin {
                // PIN is correct, proceed to create wallet keys.
                // This can be done by using a completion handler or by updating a shared state.
                                onPinVerified?()
                onDismiss?()

            } else {
                errorMessage = "Incorrect PIN"
            }
        } catch {
            errorMessage = "Failed to verify PIN"
        }
    }
}

struct PinVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        PinVerificationView()
    }
}