

import Foundation
import FirebaseFirestore


protocol ServiceProtocol {
    func getAccountContractHash(completion: @escaping (String?, Error?) -> Void)
}
    
class DataManager: ServiceProtocol {
    
    static let shared = DataManager()
    
    let db = Firestore.firestore()
    let contractsRef: CollectionReference
    
    private init() {
        contractsRef = db.collection("contracts")
    }
    
    func getAccountContractHash(completion: @escaping (String?, Error?) -> Void){
        let contractDocument = contractsRef.document("account_hash")
        
        contractDocument.getDocument { document, error in
            if let error = error {
                print("Error fetching user profile: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            if let document = document, document.exists, let data = document.data() {
                let hash = data["hash"] as? String ?? ""
                completion(hash, nil)
            } else {
                completion(nil, error)
            }
            
        }
    }

    func getMoaImplementationHash(completion: @escaping (String?, Error?) -> Void){
        let contractDocument = contractsRef.document("moa_implementation")
        
        contractDocument.getDocument { document, error in
            if let error = error {
                print("Error fetching user profile: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            if let document = document, document.exists, let data = document.data() {
                let hash = data["hash"] as? String ?? ""
                completion(hash, nil)
            } else {
                completion(nil, error)
            }
            
        }
    }
    
    func createSession(_ sessionID: String, creator: Participant, completion: @escaping (Error?) -> Void) {
        let sessionRef = db.collection("moaSession").document(sessionID)
        let participantData = [
            "id": creator.id,
            "publicKey": creator.publicKey.toHex(),
            "username": creator.username,
            "colorHexCode": creator.colorHexCode
        ] as [String : Any]
        sessionRef.setData([
            "participants": [participantData],
            "created_at": Timestamp(date: Date()),
            "proposer": creator.id
        ]) { error in
            completion(error)
        }
    }
    
    func joinSession(_ sessionID: String,
                     newParticipant: Participant,
                     completion: @escaping (Error?) -> Void) {
        let sessionRef = db.collection("moaSession").document(sessionID)
        let participantData = [
            "id": newParticipant.id,
            "publicKey": newParticipant.publicKey.toHex(),
            "username": newParticipant.username,
            "colorHexCode": newParticipant.colorHexCode
        ] as [String : Any]
        
        // Retrieve the current session document
        sessionRef.getDocument { (document, error) in
            if let error = error {
                completion(error)
                return
            }
            
            if let document = document, let data = document.data(), var participants = data["participants"] as? [[String: Any]] {
                // Check if the participant already exists
                if let index = participants.firstIndex(where: { $0["id"] as? String == newParticipant.id }) {
                    // Replace the existing participant data
                    participants[index] = participantData
                } else {
                    // Add the new participant
                    participants.append(participantData)
                }
                
                // Update the session document with the new participants array
                sessionRef.setData(["participants": participants], merge: true) { error in
                    completion(error)
                }
            } else {
                // If the document does not exist, create it with the new participant
                sessionRef.setData(["participants": [participantData]], merge: true) { error in
                    completion(error)
                }
            }
        }
    }

    func removeParticipant(_ sessionID: String, participantID: String, completion: @escaping (Error?) -> Void) {
        let sessionRef = db.collection("moaSession").document(sessionID)
        
        // First, get the current participants array
        sessionRef.getDocument { (document, error) in
            if let error = error {
                completion(error)
                return
            }
            
            if let document = document, let data = document.data(), var participants = data["participants"] as? [[String: Any]] {
                // Find the participant with the matching ID
                if let index = participants.firstIndex(where: { $0["id"] as? String == participantID }) {
                    let participantToRemove = participants[index]
                    // Remove the participant using the full participant object
                    sessionRef.updateData([
                        "participants": FieldValue.arrayRemove([participantToRemove])
                    ], completion: { error in
                        completion(error)
                    })
                } else {
                    // Participant with the given ID was not found
                    completion(nil)
                }
            } else {
                // Document or participants array does not exist
                completion(nil)
            }
        }
    }

    func updateDeploymentStatus(_ sessionID: String, status: String, account_deployed: String, completion: @escaping (Error?) -> Void) {
    let sessionRef = db.collection("moaSession").document(sessionID)
    sessionRef.updateData([
        "deploymentStatus": status,
        "accountDeployed": account_deployed
    ], completion: completion)
}
}

