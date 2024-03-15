import Foundation
import Starknet
import Security

protocol KeychainOperations {
    func save(_ data: Data, service: String, account: String) throws
    func read(service: String, account: String) throws -> Data
    func delete(service: String, account: String) throws
    func hasPin(service: String, account: String) -> Bool
    func storePrivateKey(_ privateKey: Data, service: String, account: String)
    func deleteAllInstances(service: String, account: String)
    func retrievePrivateKey(service: String, account: String) -> Data?
}

class KeychainHelper: KeychainOperations {
    static let standard = KeychainHelper()
    private init() {}
    
    func save(_ data: Data, service: String, account: String) throws {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ] as [String: Any]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }
    
    func read(service: String, account: String) throws -> Data {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        guard let data = item as? Data else { throw KeychainError.noData }
        
        return data
    }
    
    func delete(service: String, account: String) throws {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as [String: Any]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandledError(status: status) }
    }
    
    func hasPin(service: String, account: String) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanFalse!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    enum KeychainError: Error {
        case noData
        case unhandledError(status: OSStatus)
    }
    func storePrivateKey(_ privateKey: Data, service: String, account: String) {
        do {
            // Attempt to delete any existing item with the same service and account
            try deleteAllInstances(service: service, account: account)
            // Proceed to save the new private key data
            try save(privateKey, service: service, account: account)
        } catch {
            print("Error storing private key: \(error)")
        }
    }

    func storeMoaKeychain(moaKeychain: MoaKeychain) {
        do {
            // First, delete any existing MoaKeychain to ensure we overwrite it
            try deleteAllInstances(service: "MoaKeychain", account: "MoaKeychain")
            // Encode the MoaKeychain object to data
            let data = try JSONEncoder().encode(moaKeychain)
            // Save the encoded MoaKeychain data
            try save(data, service: "MoaKeychain", account: "MoaKeychain")
        } catch {
            print("Error storing MoaKeychain: \(error)")
        }
    }

    func retrieveMoaKeychain() -> MoaKeychain? {
        do {
            let data = try read(service: "MoaKeychain", account: "MoaKeychain")
            return try JSONDecoder().decode(MoaKeychain.self, from: data)
        } catch {
            print("Error retrieving MoaKeychain: \(error)")
            return nil
        }
    }

    func deleteAllInstances(service: String, account: String) {
        var query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitAll
        ] as [String: Any]
        
        var item: CFTypeRef?
        while SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess {
            let deleteQuery = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ] as [String: Any]
            
            let status = SecItemDelete(deleteQuery as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound {
                print("Error deleting keychain item: \(status)")
                break
            }
        }
    }
    
    func retrievePrivateKey(service: String, account: String) -> Data? {
        do {
            return try read(service: service, account: account)
        } catch {
            print("Error retrieving private key: \(error)")
            return nil
        }
    }
}


struct MoaKeychain: Codable {
    var implHash: String
    var address: Felt
}
