// AccountView.swift
import SwiftUI
import ComposableArchitecture

struct AccountView: View {
  
    
  let accountStore: StoreOf<AccountFeature>
  
        var body: some View {
            WithViewStore(accountStore, observe: { $0 }) { viewStore in
                Text(viewStore.address?.toHex() ?? "Loading Address")
        }
    }
}
