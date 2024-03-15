import SwiftUI



enum MoaResult {
    case success
    case failure
    case ignore
}

struct MoaConfirm: View {
    
    let moaResult: MoaResult
    var onDismiss: (() -> Void)?
    
    init(moaResult: MoaResult, onDismiss: (() -> Void)? = nil){
        self.moaResult = moaResult
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if moaResult == .success {
                Text("All good!")
                Text("The moa account has been created")
            } else {
                Text("Oops!")
                Text("There was a problem creating the moa account")
            }
            Spacer()
        }
        .onDisappear {
            self.onDismiss?()
        }
    }
}

#Preview {
    MoaConfirm(moaResult: .success)
}
