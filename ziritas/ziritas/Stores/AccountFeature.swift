// AccountFeature.swift
import ComposableArchitecture
import Starknet


struct WalletAccount: Equatable {
    var address: Felt
    var tokens: [Token] = []
    var totalPortfolioValue: Float?
    var public_key_felt: Felt
    var public_key: String
    
    // Initialize with default or provided values
    init( address: Felt, tokens: [Token] = [], totalPortfolioValue: Float? = nil, public_key_felt: Felt, public_key: String) {

        self.address = address
        self.tokens = tokens
        self.totalPortfolioValue = totalPortfolioValue
        self.public_key_felt = public_key_felt
        self.public_key = public_key
    }
}

@Reducer
struct AccountFeature {
    @ObservableState
    struct State: Equatable {
        
        var wallets: [WalletAccount]?
        var selectedWallet: WalletAccount?
        var address: Felt?
        var tokens: [Token] = []
        var totalPortfolioValue: Float?
        var isLoading: Bool = true
        var public_key_felt: Felt?
        var public_key: String?
        ///Temp
        var isAuthenticated: Bool = false
        var isCreatingWallet: Bool = false
        ///Moa related stuff
        var moaAccountAdress: Felt?
        ///Starknet related stuf
        let provider = StarknetProvider(url: "https://starknet-sepolia.blastapi.io/fec79bb2-ce39-4a58-8668-a96ce919142e/rpc/v0_7")

    }
    
    enum Action {
        case loadAccountData
        case setAddress(Felt)
        case setTokensAndBalance(Result<([Token], Float?), Error>)
        case setLoading(Bool)
        case isAuthenticated(Bool)
        case setPublicKey(Felt, String)
        case setMoaAccount(Felt)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadAccountData:
                state.isLoading = true
                // Simulate loading account data
                return .none
         
            case let .setTokensAndBalance(result):
                state.isLoading = false
                switch result {
                case let .success((tokens, totalPortfolioValue)):
                    state.tokens = tokens
                    state.totalPortfolioValue = totalPortfolioValue
                    state.isLoading = false
                case .failure:
                    // Handle error
                    return .none
                }
                return .none
                
            case let .setLoading(isLoading):
                state.isLoading = isLoading
                return .none
            case let .isAuthenticated(isAuthen):
                state.isAuthenticated = isAuthen
                return .none
            case let .setPublicKey(key_felt, key_string):
                state.public_key_felt = key_felt
                state.public_key = key_string
                return .none
            
            case let .setAddress(account_add):
                state.address = account_add
                return .none
            case let .setMoaAccount(moaAddress):
                state.moaAccountAdress = moaAddress
                return .none
            }
        }
    }
}

extension StarknetProvider: Equatable {

    public static func == (lhs: StarknetProvider, rhs: StarknetProvider) -> Bool {
        return  lhs.getUrl() == rhs.getUrl()
    }
}


