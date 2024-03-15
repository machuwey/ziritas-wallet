import SwiftUI
import ComposableArchitecture

struct MyQRView: View {
    
    @Binding var isShowing: Bool
    @State private var qrImage: UIImage?
    @State private var curHeight: CGFloat = 400
    @State private var name = "Anonymous"
    @State private var emailAddress = "you@yoursite.com"
    @State private var qrCode = UIImage()
    @State private var showingCopyHint = false
    
    let minHeight: CGFloat = 400
    let maxHeight: CGFloat = 700
    
    let qrURLImage = URL(string: "https://www.avanderlee.com")?.qrImage(using: UIColor(red:0.93, green:0.31, blue:0.23, alpha:1.00))
    
    let context = CIContext()
    let filter = CIFilter(name: "CIQRCodeGenerator")
    
    let accountStore: StoreOf<AccountFeature>
                                

    
    var body: some View{
       
        VStack{
            HStack {
                //Text("\(String("\(accountStore.address?.toHex().prefix(4))"))...\(String("\(accountStore.address?.toHex().suffix(4))"))")
                Text((accountStore.address?.toHex())!)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = accountStore.address?.toHex()
                    // Show a hint that the address was copied
                    withAnimation {
                        showingCopyHint = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showingCopyHint = false
                        }
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .padding(.horizontal, 8)
                .overlay(
                    Text(showingCopyHint ? "Copied" : "")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .opacity(showingCopyHint ? 1 : 0)
                        .animation(.easeInOut, value: showingCopyHint)
                        .transition(.opacity)
                )
            }
            .padding()
            .padding()
            Image(uiImage: qrCode)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 200, height: 200)
            
        }
        .onAppear(perform: updateCode)
                .onChange(of: name) { _ in updateCode() }
                .onChange(of: emailAddress) { _ in updateCode() }
        
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
}

struct ModelView_Previews: PreviewProvider {
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

