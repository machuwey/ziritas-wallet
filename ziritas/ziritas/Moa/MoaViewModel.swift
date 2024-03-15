import Foundation
import Starknet

class MoaViewModel: ObservableObject{
    
    @Published var walletAddresses: [String] = []

    /*
     Generates a session link and store it in firebase,
     the user can share the link to let other owners join
     the multi owner to finalize its creation
     */
    public func genereateMultiOwnerCreateSession() {
        
    }
    
    public func generateMultiOwnerCreateSession(participant: Participant, completion: @escaping (String?, Error?) -> Void) {
        let sessionID = UUID().uuidString // Generate a unique identifier
        DataManager.shared.createSession(sessionID, creator: participant) { error in
            if let error = error {
                completion(nil, error)
            } else {
                completion(sessionID, nil)
            }
        }
    }
    public func joinMultiOwnerSession(participant: Participant, sessionID: String, completion: @escaping (String?, Error?) -> Void) {
        DataManager.shared.joinSession(sessionID, newParticipant: participant) { error in
            if let error = error {
                completion(nil, error)
            } else {
                completion(sessionID, nil)
            }
        }
    }
    
    func createDeepLink(sessionID: String) -> URL? {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "deeplink.ziritas.com"
            components.path = "/joinSession"
            components.queryItems = [URLQueryItem(name: "sessionID", value: sessionID)]
            
            return components.url
        }

    func updateDeploymentStatus(sessionID: String, status: String, account_deployed: Felt) {
        
        DataManager.shared.updateDeploymentStatus(sessionID, status: status, account_deployed: account_deployed.toHex()) { error in
        if let error = error {
            print("Error updating deployment status: \(error.localizedDescription)")
        } else {
            print("Deployment status updated successfully.")
        }
    }
    }
}
