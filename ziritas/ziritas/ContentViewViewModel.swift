import Foundation
import ComposableArchitecture
import Starknet
import SwiftUI
import BigInt
import LocalAuthentication

class ContentViewViewModel: ObservableObject {
    
    @Published var errorMessage: String?
    @Published var customMessage: String = ""
    @Published var signedMessage_r: Felt?
    @Published var signedMessage_s: Felt?
    @Published var isSignatureVerified: Bool?
    @Published var isAuthenticated: Bool = false
    @Published var isCreatingWallet: Bool = false
    @Published var isPresentingPinVerification: Bool = false
    
    @Published var isLoading = true
    
    let keychainAccountString = Bundle.main.object(forInfoDictionaryKey: "KeychainAccountString") as? String
    
    var account_contract_class_hash: Felt?
    
    let accountStore: StoreOf<AccountFeature>
    
    init(accountStore: StoreOf<AccountFeature>) {
        self.accountStore = accountStore
    }
    
    private func calculateTotalPortfolioValue(tokens: [Token]) -> Float {
        return tokens.compactMap { $0.totalPrice }.reduce(0, +)
    }
    
    let keychain = KeychainHelper.standard
    
    func createWallet() {
        guard accountStore.isAuthenticated else {
            isPresentingPinVerification = true
            return
        }
        
        let privKey = generateRandomFelt()
        guard let privKeyFelt: Felt = privKey else { return }
        print("priv key felt",privKeyFelt)
        do {
            let publicKey = try StarknetCurve.getPublicKey(privateKey: privKeyFelt)
            self.accountStore.send(.setPublicKey(publicKey, publicKey.toHex()))
            // Convert the private key to Data and store it securely in the Keychain
            let privateKeyData: Data = privKeyFelt.serialize()
            
            keychain.storePrivateKey(privateKeyData, service: "com.strapex.wallet", account: "wallet-private-key")
            
            // Introducing a wait before reading
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard let retrievedPrivateKeyData = self.keychain.retrievePrivateKey(service: "com.strapex.wallet", account: "wallet-private-key"),
                      privateKeyData == retrievedPrivateKeyData else {
                    self.errorMessage = "Failed to verify the private key storage"
                    return
                }
            }
            print("key correctly stored")
            let dataManager = DataManager.shared
            dataManager.getAccountContractHash() { hash, error in
                guard let hash = hash, let classHash = Felt.init(fromHex: hash) else {
                    self.errorMessage = "Error converting hash to Felt"
                    return
                }
                let callData: Array<Felt> = [publicKey]
                let address = StarknetContractAddressCalculator.calculateFrom(classHash: classHash, calldata: callData, salt: 0)
                Task{
                    self.accountStore.send(.setAddress(address))
                    self.accountStore.send(.setTokensAndBalance(await self.loadTokensFromJSON(for: address)))
                }
                
            }
        } catch {
            self.errorMessage = "Failed to create wallet"
        }
    }
    func retrieveWallet() {
        guard let privateKeyData = KeychainHelper.standard.retrievePrivateKey(service: "com.strapex.wallet", account: "wallet-private-key"),
              let private_key_felt = Felt(privateKeyData) else {
            // No wallet found, or there was an error retrieving the private key
            return
        }
        
        do {
            let publicKey = try StarknetCurve.getPublicKey(privateKey: private_key_felt)
            
            self.accountStore.send(.setPublicKey(publicKey, publicKey.toHex()))
            
            let dataManager = DataManager.shared
            dataManager.getAccountContractHash() { [self] hash, error in
                guard let hash = hash, let classHash = Felt.init(fromHex: hash) else {
                    self.errorMessage = "Error converting hash to Felt"
                    return
                }
                self.account_contract_class_hash = Felt(fromHex: hash)
                let callData: Array<Felt> = [publicKey]
                let address = StarknetContractAddressCalculator.calculateFrom(classHash: classHash, calldata: callData, salt: 0)
                
                //Retrieve the moa Account
                let moa_address: Felt? = loadMoaAccount()
                // Automatically set ETH balance after retrieving wallet
                Task{
                    accountStore.send(.setAddress(address))
                    accountStore.send(.setTokensAndBalance(await self.loadTokensFromJSON(for: address)))
                    if let moa_address {
                        accountStore.send(.setMoaAccount(moa_address))
                    }
                    print("moa_address",moa_address)
                }
                
            }
        } catch {
            self.errorMessage = "Failed to retrieve wallet"
        }
    }

    func saveMoaAccount(address: Felt) {
        
        let dataManager = DataManager.shared
        dataManager.getMoaImplementationHash {[weak self] hash, error in
            if let error = error {
                        print("Error retrieving hash: \(error)")
                    return
                    }
            guard let hash else { return  }
            do {
                let moa_save = MoaKeychain(implHash: hash, address: address)
                self?.keychain.storeMoaKeychain(moaKeychain: moa_save)
                
                let moa_retrieved = self?.keychain.retrieveMoaKeychain()
                print(moa_retrieved)
            } catch {
                //
            }
            
        }
    }

    func loadMoaAccount() -> Felt? {
        let moa_retrieved = keychain.retrieveMoaKeychain()
        guard let moa_retrieved = moa_retrieved else { return nil }
        return moa_retrieved.address
    }
    
    func importWallet(publicKey: String, privateKey: String) {
        guard accountStore.isAuthenticated else {
            isPresentingPinVerification = true
            return
        }
        
        // Convert the provided keys from String to Felt
        guard let publicKeyFelt = Felt(fromHex: publicKey), let privateKeyFelt = Felt(fromHex: privateKey) else {
            self.errorMessage = "Invalid key format"
            return
        }
        
        // Store the private key securely in the Keychain
        let privateKeyData: Data = privateKeyFelt.serialize()
        keychain.storePrivateKey(privateKeyData, service: "com.strapex.wallet", account: "wallet-private-key")
        
        // Verify the private key storage
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let retrievedPrivateKeyData = self.keychain.retrievePrivateKey(service: "com.strapex.wallet", account: "wallet-private-key"),
                  privateKeyData == retrievedPrivateKeyData else {
                self.errorMessage = "Failed to verify the private key storage"
                return
            }
        }
        
        // Set the public key in the accountStore
        self.accountStore.send(.setPublicKey(publicKeyFelt, publicKeyFelt.toHex()))
        
        // Calculate the address from the public key
        let dataManager = DataManager.shared
        dataManager.getAccountContractHash() { [self] hash, error in
            guard let hash = hash, let classHash = Felt.init(fromHex: hash) else {
                self.errorMessage = "Error converting hash to Felt"
                return
            }
            let callData: Array<Felt> = [publicKeyFelt]
            let address = StarknetContractAddressCalculator.calculateFrom(classHash: classHash, calldata: callData, salt: 0)
            
            // Set the address and load tokens and balance
            Task {
                self.accountStore.send(.setAddress(address))
                self.accountStore.send(.setTokensAndBalance(await self.loadTokensFromJSON(for: address)))
            }
        }
    }
    
    
    
    func signMessage() {
        // Require PIN verification before signing a message
        guard isAuthenticated else {
            isPresentingPinVerification = true
            return
        }
        
        // Retrieve the private key from the Keychain
        guard let privateKeyData = KeychainHelper.standard.retrievePrivateKey(service: "com.strapex.wallet", account: "wallet-private-key"),
              let private_key_felt = Felt(privateKeyData),
              let messageFelt = Felt.fromShortString(customMessage) else {
            self.errorMessage = "Invalid private key or message"
            return
        }
        
        do {
            let signature = try StarknetCurve.sign(privateKey: private_key_felt, hash: messageFelt)
            self.signedMessage_r = signature.r
            self.signedMessage_s = signature.s
            print(signature)
        } catch {
            self.errorMessage = "Failed to sign message"
        }
    }
    
    func verifySignature() {
        // Retrieve the private key from the Keychain
        guard
            let public_key = accountStore.public_key_felt,
            let messageFelt = Felt.fromShortString(customMessage),
            let signedMessage_s, let signedMessage_r else {
            self.errorMessage = "Invalid data for signature verification"
            return
        }
        
        
        do {
            let isVerified = try StarknetCurve.verify(publicKey: public_key, hash: messageFelt, r: signedMessage_r, s: signedMessage_s)
            self.isSignatureVerified = isVerified
        } catch {
            self.errorMessage = "Failed to verify signature"
        }
    }
    
    func getAccountBalance() async -> String? {
        
        guard let address = accountStore.address?.toHex() else { return nil }
        
        let contractAddress: Felt = "0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7"  //ETH address
        let address_felt: Felt = Felt.init(fromHex: address)!
        
        let entrypoint: Felt = starknetSelector(from: "balanceOf")
        let starknetCall = StarknetCall(contractAddress: contractAddress , entrypoint: entrypoint, calldata:[address_felt])
        
        do {
            let result = try await accountStore.provider?.callContract(starknetCall)
            let balance = result![0].value
            let divisor = BigUInt(10).power(18)
            if let balanceFloat = Float(String(balance)), let divisorFloat = Float(String(divisor)) {
                let ethBalance: Float = balanceFloat / divisorFloat
                print("The balance of the account \(address_felt) is: \(ethBalance)")
                return String(ethBalance)
            } else {
                print("Error converting BigUInt to Float")
                return nil
            }
        } catch {
            print("An error occurred: \(error)")
            return nil
        }
    }
    
    func loadTokensFromJSON(for address: Felt) async -> Result<([Token], Float?), Error> {
        guard let url = Bundle.main.url(forResource: "Tokens", withExtension: "json") else {
            print("Tokens JSON file not found")
            return .failure(NSError(domain: "LocalDataError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch local data"]))
            
        }
        
        let request = URLRequest(url: url)
        let session = URLSession.shared
        
        //Temp variable
        var totalPortfolioValue: Float = 0.00
        var tokens: [Token] = []
        
        do {
            let (data, _) = try await session.data(for: request)
            let decoder = JSONDecoder()
            var tokensFromJSON = try decoder.decode([Token].self, from: data)
            
            for (index, token) in tokensFromJSON.enumerated() {
                let balance = await getAccountBalance(of: token.address, selector: token.balanceSelector, for: address)
                tokensFromJSON[index].balance = balance ?? 0.0
            }
            tokens = tokensFromJSON
            
            // Set the balance of the tokens
            let usdcAddress = "0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8"
            
            for (index, token) in tokens.enumerated() {
                let sellTokenAddress = token.address
                let balanceBigInt = BigInt(String(format: "%.0f", token.balance * 1e18))
                guard let sellAmountInWei = balanceBigInt else {
                    print("Error converting balance to BigInt")
                    continue
                }
                let sellAmountInWeiHex = "0x" + String(sellAmountInWei, radix: 16)
                
                var urlComponents = URLComponents(string: "https://starknet.api.avnu.fi/swap/v1/quotes")
                let queryItems = [
                    URLQueryItem(name: "sellTokenAddress", value: sellTokenAddress),
                    URLQueryItem(name: "buyTokenAddress", value: usdcAddress),
                    URLQueryItem(name: "sellAmount", value: sellAmountInWeiHex)
                ]
                urlComponents?.queryItems = queryItems
                
                guard let quoteUrl = urlComponents?.url else {
                    print("Invalid URL")
                    continue
                }
                
                var quoteRequest = URLRequest(url: quoteUrl)
                quoteRequest.httpMethod = "GET"
                quoteRequest.addValue("application/json", forHTTPHeaderField: "accept")
                
                let (quoteData, quoteResponse) = try await session.data(for: quoteRequest)
                
                guard let httpResponse = quoteResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("Error with the response, unexpected status code: \(String(describing: (quoteResponse as? HTTPURLResponse)?.statusCode))")
                    continue
                }
                
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: quoteData, options: [])
                    print(jsonResponse)
                    if let array = jsonResponse as? [[String: Any]],
                       let buyAmountInUsd = array.first?["buyAmountInUsd"] as? Double {
                        // Assign the USD value to the token's totalPrice
                        print("assigned price")
                        tokens[index].totalPrice = Float(buyAmountInUsd)
                    } else {
                        // If the array is empty or the value is not found, assign 0 to totalPrice
                        tokens[index].totalPrice = 0
                    }
                } catch {
                    print("Error parsing JSON for token: \(token.ticker): \(error)")
                    tokens[index].totalPrice = 0
                }
            }
            
            totalPortfolioValue = self.calculateTotalPortfolioValue(tokens: tokens)
            print("All prices have been fetched and assigned.")
            isLoading = false
            
        } catch {
            isLoading = false
            print("Error decoding tokens from JSON or fetching data: \(error)")
            
        }
        return .success((tokens, totalPortfolioValue))
    }
    
    private func getAccountBalance(of token_address: String, selector: String, for user_address: Felt) async -> Float? {
        guard !token_address.isEmpty else { return nil }
        
        
        let contractAddress: Felt = Felt(fromHex: token_address) ?? Felt.zero
        let user_address_felt: Felt =  user_address
        
        let entrypoint: Felt = starknetSelector(from: selector)
        let starknetCall = StarknetCall(contractAddress: contractAddress, entrypoint: entrypoint, calldata: [user_address_felt])
        
        do {
            let result = try await accountStore.provider?.callContract(starknetCall)
            let balance = result![0].value
            let divisor = BigUInt(10).power(18)
            if let balanceFloat = Float(String(balance)), let divisorFloat = Float(String(divisor)) {
                return balanceFloat / divisorFloat
            } else {
                print("Error converting BigUInt to Float")
                return nil
            }
        } catch {
            print("An error occurred while fetching balance for \(accountStore.address?.toHex()): \(error)")
            return nil
        }
    }
    
    
    
    func signTransaction_execute(calls: [StarknetCall], params: StarknetInvokeParamsV3?) async throws -> StarknetInvokeTransactionResponse {
        
        guard let privateKeyData = KeychainHelper.standard.retrievePrivateKey(service: "com.strapex.wallet", account: "wallet-private-key"),
              let private_key_felt = Felt(privateKeyData) else {
            throw TransactionError.privateKeyNotFound
        }
        guard let address_felt = accountStore.address, let provider = accountStore.provider else {
            throw TransactionError.privateKeyNotFound
        }
        
        let signer = StarkCurveSigner(privateKey: private_key_felt)!
        let starknetacc = StarknetAccount(address: address_felt, signer: signer, provider: provider, cairoVersion: .one)
        
        //0x57cdad79f56a3f69846346561467ed713d2a70f214a0a22cf7e6561b7a132fb
        //let signer_test = StarkCurveSigner(privateKey: "0x0707d4b6b4b7c8b723a4346c83ee6766fab7eebe7f0767849b657a7a014b6daa")!
        //let testStarknetAccount = StarknetAccount(address: "0x00c9d553f988783d957fd976b8cee67146cc05722476ac9ec09dc673b39caa46", signer: signer_test, provider: provider, cairoVersion: .zero)
        
        
        ///Testing the braavos deployment
        ///
        ///
        //let temp_pubkey = Felt("589637958316579531865823167976138464469073589697755226043016610260171330897")
        //let temp_privkey = Felt (5314292297)
        //let temp_callData: Array<Felt> = [publi]
        //let temp_hash = Felt(fromHex: "0x04e422823bc75151205f576fc89ae5de3312ed6449d0a5d319db48db2a754a18")!
        
        
        
        
        
        //Getting the provider chainId
        let chainId = try await provider.getChainId()
        
        var nonce: Felt
        var resourceBounds: StarknetResourceBoundsMapping
        
        let version = try await provider.specVersion()
        var test_nonce: Felt
        var firstInvokeSoDeploy = false
        if let paramsNonce = params?.nonce {
            nonce = paramsNonce
            test_nonce = paramsNonce
        } else {
            do {
                test_nonce = try await getNonce(address: "0x069c236f88e3945385cfae15ba1b4e67207f5db8fbc65b20141da30402eed866", provider: accountStore.provider)
                nonce = try await getNonce(address: address_felt, provider: accountStore.provider)
            } catch StarknetProviderError.jsonRpcError(let code, let message, _) where message.contains("Contract not found") {
                // This error indicates the contract is not found, which likely means it's the first deployment
                firstInvokeSoDeploy = true
                // Initialize nonce for deployment, if necessary
                nonce = Felt.zero // Adjust according to your needs
                test_nonce = try await getNonce(address: "0x069c236f88e3945385cfae15ba1b4e67207f5db8fbc65b20141da30402eed866", provider: accountStore.provider)
                
                account_contract_class_hash = Felt(fromHex: "0x013bfe114fb1cf405bfc3a7f8dbe2d91db146c17521d40dcf57e16d6b59fa8e6")
                /// Lets proceed to deploy de account
                guard let account_contract_class_hash, let public_key_felt = accountStore.public_key_felt else {  throw  TransactionError.account_deploy_hash_error}
                
                
                /*
                 let temp_address = StarknetContractAddressCalculator.calculateFrom(classHash: temp_hash, calldata: temp_callData, salt: 0)
                 let signer = StarkCurveSigner(privateKey: temp_privkey)!
                 let temp_acc = StarknetAccount(address: temp_address, signer: signer, provider: provider, cairoVersion: .one)
                 let impl_hash = Felt(fromHex: "0x00816dd0297efc55dc1e7559020a3a825e81ef734b558f03c83325d4da7e6253")
                 //let feeEstimate = try await starknetacc.estimateDeployAccountFeeV3(classHash: account_contract_class_hash, calldata: [public_key_felt], salt: 0)
                 let feeEstimateV2 = try await temp_acc.estimateDeployAccountFeeV1(classHash: temp_hash, calldata: [temp_pubkey], salt: 0, impl_hash: impl_hash)
                 */
                
                let temp_address = StarknetContractAddressCalculator.calculateFrom(classHash: account_contract_class_hash, calldata: [accountStore.public_key_felt!], salt: 0)
                print(temp_address)
                let signer = StarkCurveSigner(privateKey: private_key_felt)!
                
                let temp_acc = StarknetAccount(address: temp_address, signer: signer, provider: provider, cairoVersion: .one)
                let impl_hash = Felt(fromHex: "0x00816dd0297efc55dc1e7559020a3a825e81ef734b558f03c83325d4da7e6253")
                //let feeEstimate = try await starknetacc.estimateDeployAccountFeeV3(classHash: account_contract_class_hash, calldata: [public_key_felt], salt: 0)
                //let feeEstimateV1 = try await temp_acc.estimateDeployAccountFeeV1(classHash: account_contract_class_hash, calldata: [accountStore.public_key_felt!], salt: 0, impl_hash: impl_hash, privateKey: private_key_felt)
                
                let feeEstimatev3 = try await temp_acc.estimateDeployAccountFeeV32(classHash: account_contract_class_hash, calldata: [public_key_felt] , salt: 0, privatekey: private_key_felt)
                //resourceBounds = feeEstimateV2.toResourceBounds()
                
                resourceBounds = feeEstimatev3.toResourceBounds()
                //let deployTransaction = StarknetDeployAccountTransactionV3(signature: [], l1ResourceBounds: resourceBounds.l1Gas, nonce: .zero, contractAddressSalt: 0, constructorCalldata: [public_key_felt], classHash: account_contract_class_hash)
                let deployTransactionv3 = StarknetDeployAccountTransactionV3(signature: [], l1ResourceBounds: feeEstimatev3.toResourceBounds().l1Gas, nonce: 0, contractAddressSalt: 0, constructorCalldata: [public_key_felt], classHash: account_contract_class_hash)
                
                
                
                let chaindId = try! await provider.getChainId()
                
                ///-------------------
                let hash = StarknetTransactionHashCalculator.computeHash(of: deployTransactionv3, chainId: chainId)
                
                
                let signatureOnHash = try StarknetCurve.sign(privateKey: private_key_felt, hash: hash)
                
                // Correctly construct auxiliary data based on the Python example
                let strong_signer_type: Felt = 0 // Adjust according to your needs
                let secp256r1_signer: [Felt] = [0, 0, 0, 0] // Adjust if you have a secp256r1 signer
                let multisig_threshold: Felt = 0 // Your multisig threshold
                let withdrawal_limit_low: Felt = 0 // Your withdrawal limit
                let eth_fee_rate: Felt = 0 // Your ETH fee rate
                let stark_fee_rate: Felt = 0 // Your Stark fee rate
                
                
                // Combine all auxiliary data into a single array
                let auxiliaryData = [impl_hash!] + [strong_signer_type] + secp256r1_signer + [multisig_threshold, withdrawal_limit_low, eth_fee_rate, stark_fee_rate, chainId]
                
                let auxDataHash = StarknetPoseidon.poseidonHash(auxiliaryData)
                
                // Sign the auxiliary data hash
                let signatureOnAuxData = try StarknetCurve.sign(privateKey: private_key_felt, hash: auxDataHash)
                
                // Construct the full signature array
                var fullSignature: [Felt] = signatureOnHash.toArray()
                
                fullSignature += auxiliaryData
                fullSignature += [signatureOnAuxData.r, signatureOnAuxData.s]
                
                // If you have an implementation hash, append it to the full signature
                
                let temp_pubkey = try! StarknetCurve.getPublicKey(privateKey: private_key_felt)
                // Verification step (ensure this is necessary for your use case)
                let result = try StarknetCurve.verify(publicKey: temp_pubkey, hash: auxDataHash, r: signatureOnAuxData.r, s: signatureOnAuxData.s)
                print("Verification result: \(result)")
                ///-------------------
                
                
                let correctResourceBounds = feeEstimatev3.toResourceBounds().l1Gas
                
                //let deployTransaction_signed = StarknetDeployAccountTransactionV3(signature: signature, l1ResourceBounds: resourceBounds.l1Gas, nonce: .zero, contractAddressSalt: 0, constructorCalldata: [public_key_felt], classHash: account_contract_class_hash)
                let deployTransaction_signed = StarknetDeployAccountTransactionV3(signature: fullSignature, l1ResourceBounds: correctResourceBounds, nonce: 0, contractAddressSalt: 0, constructorCalldata: [public_key_felt], classHash: account_contract_class_hash)
                let tx_response = try await provider.addDeployAccountTransaction(deployTransaction_signed)
                print(tx_response)
                ///Wait 5 seconds for the transaction to be mined, make a recursive call to the function to proceed with the funds transfer
                sleep(5)
                return try await signTransaction_execute(calls: calls, params: params)
                
            } catch {
                // Handle other potential errors
                print("Error: \(error)")
                throw error
            }
        }
        
    
        let maxFee: Felt?
        if let paramsResourceBounds = params?.resourceBounds {
            resourceBounds = paramsResourceBounds
            maxFee = Felt(0)
        } else {
            //let feeEstimate = try await testStarknetAccount.estimateFeeV3(calls: calls, nonce: test_nonce)
            let feeEstimate = try await starknetacc.estimateFeeV1(calls: calls, nonce: nonce)
            resourceBounds = feeEstimate.toResourceBounds()
            maxFee = feeEstimate.toMaxFee()
        }
        
        guard let maxFee else { throw TransactionError.account_deploy_hash_error}
        
        let params = StarknetInvokeParamsV1(nonce: nonce, maxFee: maxFee)
        
       
        
        let calldata = starknetCallsToExecuteCalldata(calls: calls, cairoVersion: .one)
        
        
        guard let public_key_felt = accountStore.public_key_felt else {  throw  TransactionError.account_deploy_hash_error}
        
        ///FOR WHEN INVOKE + DEPLOY let accountDeploymentData: [Felt] = [account_contract_class_hash, 0, public_key_felt]
        
        let transaction = StarknetInvokeTransactionV1(senderAddress: address_felt, calldata: calldata, signature: [], maxFee: maxFee, nonce: nonce, forFeeEstimation: false)
        
        let hash = StarknetTransactionHashCalculator.computeHash(of: transaction, chainId: chainId)
        
        let signature = try signer.sign(transactionHash: hash)
        
        let transaction_signed = StarknetInvokeTransactionV1(senderAddress: address_felt, calldata: calldata, signature: signature, maxFee: maxFee, nonce: nonce, forFeeEstimation: false)
        
        
        let tx_response = try await provider.addInvokeTransaction(transaction_signed)
        print(tx_response)
        return tx_response
    }
    
    func deployMoaAccount(participants: [Participant], threshold: Int) async throws -> (StarknetInvokeTransactionResponse, Felt) {
        guard let account_contract_class_hash = Felt(fromHex: "0x00ca6d503d0136b93b35870e6d0ad17d809402882b9cbca0b43a1f7c33f8c1bd") else {
            throw TransactionError.errorParsinFelt
        }
        
        guard let privateKeyData = KeychainHelper.standard.retrievePrivateKey(service: "com.strapex.wallet", account: "wallet-private-key"),
              let private_key_felt = Felt(privateKeyData) else {
            throw TransactionError.privateKeyNotFound
        }
        guard let address_felt = accountStore.address, let provider = accountStore.provider else {
            throw TransactionError.privateKeyNotFound
        }
        
        let signer = StarkCurveSigner(privateKey: private_key_felt)!
        let starknetacc = StarknetAccount(address: address_felt, signer: signer, provider: provider, cairoVersion: .one)
        let chainId = try await provider.getChainId()
        
        
        let participant0: Participant = participants[0]
        let participant1: Participant = participants[1]
        guard let participant0_address: Felt = Felt(fromHex: participant0.id) else { throw TransactionError.errorParsinFelt }
        guard let participant1_address: Felt = Felt(fromHex: participant1.id) else { throw TransactionError.errorParsinFelt }
        let numbahOfParticipants: Felt = Felt(clamping: 2)
        let argument1:Felt = participant0_address
        let argument2:Felt = participant0.publicKey
        let weight0: Felt = Felt(clamping: 2)
        let argument3:Felt = participant1_address
        let argument4:Felt = participant1.publicKey
        let weight1: Felt = Felt(clamping: 1)
        let argument5:Felt = Felt(clamping: 2)
        let contractAdress:Felt = Felt(fromHex: "0x041a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf")!
        let randomSalt = Int.random(in: 1...Int.max) // Generate a random salt
        
        let constructor_calldata = [
            numbahOfParticipants,
            argument1,
            argument2,
            weight0,
            argument3,
            argument4,
            weight1,
            argument5
        ]
        //This is the udc calldata which encapuslates some extra params + constructor calldata
        let calldata_temp = [
            account_contract_class_hash, // Account class hash
            Felt(clamping: randomSalt), // Salt
            Felt(clamping: 1), // Unique
            Felt(clamping: 8  ), // Data Legnth
            numbahOfParticipants,
            argument1,
            argument2,
            weight0,
            argument3,
            argument4,
            weight1,
            argument5
        ]
        let nonce = try await getNonce(address: address_felt, provider: provider)
        let call = StarknetCall(contractAddress: contractAdress,
                                entrypoint: starknetSelector(from: "deployContract"),
                                calldata: calldata_temp)
        
        let feeEstimate = try await starknetacc.estimateFeeV1(calls: [call], nonce: nonce)
        
        let maxFee = feeEstimate.toMaxFee()
        let calldata = starknetCallsToExecuteCalldata(calls: [call], cairoVersion: .one)
        
        let transaction = StarknetInvokeTransactionV1(senderAddress: address_felt, calldata: calldata, signature: [], maxFee: maxFee, nonce: nonce, forFeeEstimation: false)
        
        let hash = StarknetTransactionHashCalculator.computeHash(of: transaction, chainId: chainId)
        
        let signature = try signer.sign(transactionHash: hash)
        
        let transaction_signed = StarknetInvokeTransactionV1(senderAddress: address_felt, calldata: calldata, signature: signature, maxFee: maxFee, nonce: nonce, forFeeEstimation: false)
        
        let address = StarknetContractAddressCalculator.calculateFrom(classHash: account_contract_class_hash, calldata: constructor_calldata, salt: Felt(clamping: randomSalt), deployerAddress: contractAdress)
        let tx_response = try await provider.addInvokeTransaction(transaction_signed)
        //let tx_receipt = try await provider.getTransactionReceiptBy(hash: tx_response.transactionHash)
     
        
        let deployed_moa: Felt
        do {
            if let fetched_moa = try await fetchTransactionReceipt(provider: accountStore.provider!, transactionHash: tx_response.transactionHash) {
                deployed_moa = fetched_moa
            } else {
                // Handle the case where fetched_moa is nil, perhaps by setting a default value or throwing an error
                print("Transaction receipt not found.")
                deployed_moa = Felt(clamping: 0)
            }
            print(tx_response.transactionHash)
        } catch {
            // Handle any errors from fetching the transaction receipt
            print(error)
        }
        print(tx_response.transactionHash)
        
        return (tx_response, deployed_moa)
    }
    
    func deployMoaAccountWithCompletion(participants: [Participant], threshold: Int, completion: @escaping (Result<DeploymentResult, Error>) -> Void) {
        Task {
            do {
                let (response, deployed_contract) = try await deployMoaAccount(participants: participants, threshold: threshold)
                let deploymentResult = DeploymentResult(response: response, deployedContract: deployed_contract)
                completion(.success(deploymentResult))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    
    
    /*
     MOA accounts - in depth

     Constructor params: signers: Array<ContractAddress, felt252>>, threshold: usize
     To suggest a transaction the user should send a multicall with these calls: • Call the function assert_max_fee with parameter expected_max_fee: u128 • Put the custom transactions in the rest of the array
     To sign a transaction, the user should call sign_pending_multisig_transaction with the parameters pending_nonce and calls: Array<Call> • The call array contains all the original call set
     The signature structure is: • [ A_address, A_pub_key, A_r, A_s, A_sig_len, A_ext_sig, ...etc]
     */
    /*
     StarknetCall(
         contractAddress: token_address,
         entrypoint: starknetSelector(from: "transfer"),
         calldata: [destination_felt, low.toFelt()!, high.toFelt()!]
     )
     */
    /*
     fn assert_max_fee(
            self: @TState,
            expected_max_fee_in_eth: u128,
            expected_max_fee_in_stark: u128,
            signer_max_fee_in_eth: u128,
            signer_max_fee_in_stark: u128
        );
     */
    /*
     MAX_EXECUTE_FEE_ETH = 5 * 10**17
     MAX_SIGN_FEE_ETH = 3 * 10**16

     MAX_EXECUTE_FEE_STRK = 5 * 10**18
     MAX_SIGN_FEE_STRK = 3 * 10**17
     */
    
    
    func signTransactionMoaExecute(params: StarknetInvokeParamsV3?) async throws -> StarknetInvokeTransactionResponse {
        
        
        guard let privateKeyData = KeychainHelper.standard.retrievePrivateKey(service: "com.strapex.wallet", account: "wallet-private-key"),
              let private_key_felt = Felt(privateKeyData) else {
            throw TransactionError.privateKeyNotFound
        }
        guard let address_felt = accountStore.address, let provider = accountStore.provider,
            let public_key_felt = accountStore.public_key_felt else {
            throw TransactionError.privateKeyNotFound
        }
        
        let signer = StarkCurveSigner(privateKey: private_key_felt)!
        let starknetacc = StarknetAccount(address: address_felt, signer: signer, provider: provider, cairoVersion: .one)
    
        //Getting the provider chainId
        let chainId = try await provider.getChainId()

        //Moa account address
        guard let moaAccountAdress = accountStore.moaAccountAdress else {
            throw WalletError.moaNotFound
        }
        //Prepend the assert_max_fee call to the calls array
        let prependedCall = StarknetCall(contractAddress: moaAccountAdress,
        entrypoint: starknetSelector(from: "assert_max_fee"), 
        calldata: [
            Felt(clamping: 5 * BigUInt(10).power(17)), // MAX_EXECUTE_FEE_ETH
            Felt(clamping: 5 * BigUInt(10).power(18)), // MAX_EXECUTE_FEE_STRK
            Felt(clamping: 3 * BigUInt(10).power(16)), // MAX_SIGN_FEE_ETH
            Felt(clamping: 3 * BigUInt(10).power(17)) // MAX_SIGN_FEE_STRK
        ])
        
        let tranferAm = "0.0001"
        guard let amount = convertToWei(amount: tranferAm) else {
            throw TransactionError.converionError
        }
        
        let (high, low) = amount.quotientAndRemainder(dividingBy: BigUInt(2).power(128))
        let destination_felt = Felt(fromHex: "0x043263A3Bfb836ef2b8aBBb7818897F3993466811F537d637648bF4a2298Fa03")!
        //WARN: Delete for later
        let callToExecute = StarknetCall(
            contractAddress: Felt(fromHex: "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d")!,
            entrypoint: starknetSelector(from: "transfer"),
            calldata: [destination_felt, low.toFelt()!, high.toFelt()!]
        )
        
        let calls = [prependedCall,callToExecute]
        
        let calldata = starknetCallsToExecuteCalldata(calls: calls, cairoVersion: .one)
        var nonce: Felt
        var resourceBounds: StarknetResourceBoundsMapping
        
        let maxFee: Felt?
        
      
        nonce = try await getNonce(address: moaAccountAdress, provider: accountStore.provider)

        
        if let paramsResourceBounds = params?.resourceBounds {
            resourceBounds = paramsResourceBounds
            maxFee = Felt(0)
        } else {
            //let feeEstimate = try await testStarknetAccount.estimateFeeV3(calls: calls, nonce: test_nonce)
            //let feeEstimate = try await starknetacc.estimateFeeV1(calls: calls, nonce: nonce)
            
            //resourceBounds = feeEstimate.toResourceBounds()


            /*
            Temporally set maxFee to a contant (69809515226305)


            */
            //maxFee = feeEstimate.toMaxFee()
            maxFee = Felt(109809515226305)
        }
        
        //guard let maxFee else { throw TransactionError.account_deploy_hash_error}
        
        //let params = StarknetInvokeParamsV1(nonce: nonce, maxFee: .zero)
        
        /*
         /// Format of a signature: [ A_type, A_address, A_pub_key, A_r, A_s, A_sig_len, A_ext_sig, ...etc]

         */

        let transaction = StarknetInvokeTransactionV1(senderAddress: moaAccountAdress, calldata: calldata, signature: [], maxFee: maxFee!, nonce: nonce, forFeeEstimation: false)

        let hash = StarknetTransactionHashCalculator.computeHash(of: transaction, chainId: chainId)

  
        let hashSignature = try StarknetCurve.sign(privateKey: private_key_felt, hash: hash)
        
        let fullSignature: [Felt] = [
        0,
        address_felt,
        public_key_felt,
        hashSignature.r,
        hashSignature.s,
        1
        ]
    

        let transaction_signed = StarknetInvokeTransactionV1(senderAddress: moaAccountAdress, calldata: calldata, signature: fullSignature, maxFee: maxFee!, nonce: nonce, forFeeEstimation: false)

        let tx_response = try await provider.addInvokeTransaction(transaction_signed)
        print(tx_response)
        return tx_response   
    }
}

extension ContentViewViewModel {
    func fetchTransactionReceipt(provider: StarknetProvider, transactionHash: Felt) async -> Felt? {
        var receipt: (any StarknetTransactionReceipt)?
        var attempts = 0
        let maxAttempts = 30
        
        while receipt == nil && attempts < maxAttempts {
            do {
                receipt = try await provider.getTransactionReceiptBy(hash: transactionHash)
                break
            } catch {
                print("Receipt not available yet, retrying...")
                attempts += 1
                await Task.sleep(5_000_000_000) // Wait for 5 seconds before retrying
            }
        }
        
        if let receipt = receipt {
            print("Transaction receipt: \(receipt)")
            guard let deploymentEvent = receipt.events.first else { return nil }
            
            let deployedContractAddress = deploymentEvent.address
            print("Deployed contract address: \(deployedContractAddress)")
            return deployedContractAddress
        } else {
            print("Failed to fetch transaction receipt after \(maxAttempts) attempts.")
        }
        return nil
    }
    
    func convertToWei(amount: String) -> BigUInt? {
        // Assuming the amount is a string representing a decimal number
        guard let decimal = Decimal(string: amount) else { return nil }
        let weiMultiplier = Decimal(string: "1000000000000000000")! // 1e18
        let multiplied = (decimal * weiMultiplier)
        return BigUInt(multiplied.description)
    }
}

enum TransactionError: Error {
    case authenticationRequired
    case privateKeyNotFound
    case account_deploy_hash_error
    case errorParsinFelt
    case cannotGetDeployedAddress
    case converionError
    case feeProblem
}

enum ProviderError: Error {
    case providererror
}

enum KeychainServiceError: Error {
    case errorGettingHash
}

enum WalletError: Error {
    case moaNotFound
}

struct DeploymentResult {
    let response: StarknetInvokeTransactionResponse
    let deployedContract: Felt
}

