import SwiftUI
import ComposableArchitecture

struct FeedView: View {
    @State private var isLoading = true
    @State private var feedItems = ["Breaking News: Market Hits New High!", "Tech Update: New Wallet Features Released", "Security Alert: Tips to Keep Your Wallet Safe"]
    let accountStore: StoreOf<AccountFeature>
    var body: some View {
        VStack {
            if isLoading {
                ForEach(0..<3, id: \.self) { _ in
                    Text("Loading...")
                        .redacted(reason: .placeholder)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isLoading = false
                    }
                }
            } else {
                ForEach(feedItems, id: \.self) { item in
                    Text(item)
                }
            }
        }
    }
}

struct FeedView_Previews: PreviewProvider {
    
    static let accountStore = Store(initialState: AccountFeature.State()) {
        AccountFeature()._printChanges()
    }
    static var previews: some View {
        FeedView(accountStore: accountStore)
    }
}
