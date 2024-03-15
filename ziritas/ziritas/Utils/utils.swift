
import Foundation
import Starknet
import BigInt

func generateRandomFelt() -> Felt? {
    let max = StarknetCurve.curveOrder
    var randomValue: BigUInt
    repeat {
        randomValue = BigUInt.randomInteger(withExactWidth: 250)
    } while randomValue >= max
    
    return Felt(clamping: randomValue)
}

func getNonce(address: Felt, provider: StarknetProvider?) async throws -> Felt {
    
    guard let provider = provider else { throw ProviderError.providererror }
    let result = try await provider.getNonce(of: address)
    
    return result
}
