import SwiftUI

struct HalfSheetView: View {
    @Binding var showHalfSheet: Bool

    var body: some View {
        VStack {
            Spacer()

            VStack {
                Button("Dismiss") {
                    showHalfSheet = false
                }
                .padding()

                // Your half-sheet content here
                Text("This is a custom half-sheet.")
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
        .background(
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    showHalfSheet = false
                }
        )
    }
}
