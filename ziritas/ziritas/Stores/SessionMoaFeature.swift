//
//  SessionMoaFeature.swift
//  ziritas
//
//  Created by Matvey Dergunov on 14/2/24.
//

import Foundation
import Starknet
import ComposableArchitecture
struct Participant: Equatable, Identifiable {
    
    
    static func == (lhs: Participant, rhs: Participant) -> Bool {
        return lhs.id == rhs.id
    }
    let id: String // Also is the contract address
    let publicKey: Felt
    let username: String
    let colorHexCode: String
}

@Reducer
struct MOASessionFeature {
    @ObservableState
    struct State: Equatable {
        var wallet_participants: [Participant] = []
        var sessionId: String?
        var sessionDeepLink: URL? = nil
        var proposerAddress: String?
        var threshold: Int?
    }
    
    
    enum Action {
        case joinSession(String)
        //case sessionJoined(Result<MOASession, SessionMoaError>)
        case updateParticipants([Participant])
        case generateSession
        //case sessionGenerated(Result<MOASession, SessionMoaError>)
        case setSessionId(String)
        case addParticipant(Participant)
        case setWalletPartipants([Participant])
        case setDeepLink(URL)
    }
    struct Environment {
        var joinSession: (String) -> Effect<Action>
        var generateSession: () -> Effect<Action>
        //var test: () -> Effect
        // Add other dependencies here
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            
            case let .setSessionId(sessionId):
                state.sessionId = sessionId
                return .none
            case let .addParticipant(participant):
                state.wallet_participants.append(participant)
                //Here trigger a side effect
                return .none
            case .joinSession(_):
                return .none
            case .updateParticipants(_):
                return .none
            case .generateSession:
                return .none
            case let .setWalletPartipants(participants):
                state.wallet_participants = participants
                return .none
            case let .setDeepLink(url):
                state.sessionDeepLink = url
                return .none
                
            }
        }
    }
}
