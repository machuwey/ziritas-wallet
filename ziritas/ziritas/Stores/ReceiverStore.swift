//
//  ReceiverStore.swift
//  ziritas
//
//  Created by Matvey Dergunov on 16/2/24.
//

import Foundation
import ComposableArchitecture

@Reducer
struct ReceiverFeature {
    @ObservableState
    struct State: Equatable {
        var address: String?
        var id: String?
    }
    
    enum Action {
        case setReceiver(String, String)
    }
 
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            case let .setReceiver(address, id):
                state.address = address
                state.id = id
                return .none
            }
        }
    }
}
