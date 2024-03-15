
import Foundation

struct Token: Decodable, Hashable {
    var image: String
    var ticker: String
    var address: String
    var balanceSelector: String
    var balance: Float
    var totalPrice: Float?
}
