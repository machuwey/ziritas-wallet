
import SwiftUI
import FirebaseCore
import ComposableArchitecture

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

import SwiftUI

@main
struct ZiritasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var showingQRView = false
    @State private var showMoaConfirmation = false
    @State private var moaResult: MoaResult = .ignore
    @StateObject private var deepLinkManager = DeepLinkManager()
    
    // Assuming you have a way to initialize the AccountFeature.State
    static let accountStore = Store(initialState: AccountFeature.State()) {
        AccountFeature()._printChanges()
    }
    
    var body: some Scene {
        
        
        WindowGroup {
            WithViewStore(ZiritasApp.accountStore, observe: { $0 }) { accountStore in
                
                if ZiritasApp.accountStore.isAuthenticated{
                    
                    TabView {
                        HomeView(accountStore: ZiritasApp.accountStore)
                            .tabItem {
                                Image(systemName: "house.fill")
                                Text("Home")
                            }
                        SendFundsView(accountStore: ZiritasApp.accountStore, token: nil, receiverPayload: nil)
                            .tabItem {
                                Image(systemName: "arrow.up.arrow.down")
                                Text("Send")
                            }
                        FeedView(accountStore: ZiritasApp.accountStore)
                            .tabItem {
                                Image(systemName: "newspaper.fill")
                                Text("Pending Signatures")
                            }
                    }
                    .sheet(isPresented: $showingQRView) {
                        MyQRView(isShowing: $showingQRView, accountStore: ZiritasApp.accountStore)
                            .presentationDetents([.fraction(0.5), .medium, .large])
                        //.presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.2)))
                        
                    }
                    .sheet(isPresented: $deepLinkManager.isShowingMoaJoin) {
                        if let sessionIDToShow = deepLinkManager.sessionIDToShow {
                            CreateMoaView(accountStore: ZiritasApp.accountStore, sessionIdToJoin: sessionIDToShow.id, onDismiss: { reason in
                                // Logic to remove participant
                                guard let address = accountStore.address?.toHex() else { return }
                                DataManager.shared.removeParticipant(sessionIDToShow.id, participantID: address) { error in
                                    if let error = error {
                                        print("Failed to remove participant: \(error.localizedDescription)")
                                    } else {
                                        print("Participant removed successfully")
                                    }
                                }
                                // Dismiss the sheet programmatically
                                deepLinkManager.isShowingMoaJoin = false
                                
                                moaResult = reason
                                showMoaConfirmation = true
                            })
                            .presentationDetents([.fraction(0.7), .medium, .large])
                        } else {
                            CreateMoaView(accountStore: ZiritasApp.accountStore, onDismiss: { reason in
                                // Dismiss the sheet programmatically
                                deepLinkManager.isShowingMoaJoin = false
                            })
                            .presentationDetents([.fraction(0.7), .medium, .large])
                        }
                    }
                    .sheet(isPresented: $showMoaConfirmation){
                        MoaConfirm(moaResult: moaResult)
                    }
                    .onOpenURL(perform: deepLinkManager.handleDeepLink)
                    /*
                     else  if url.host() == "deeplink.ziritas.com",
                     let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                     let queryItems = components.queryItems,
                     let sessionID = queryItems.first(where: { $0.name == "sessionID" })?.value {
                     sessionIDToShow = SessionIDWrapper(id: sessionID)
                     isShowingMoaJoin = true
                     }
                     */
                    //})
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowQRView"))) { _ in
                        showingQRView = true
                    }
                    
                    
                    
                } else {
                    AuthenticationView(accountStore: ZiritasApp.accountStore)
                }
            }
            /*
             .sheet(item: $sessionIDToShow) { sessionIDWrapper in
             Text("Session ID: \(sessionIDWrapper.id)").padding()
             }
             */
            ///Example of url: https://deeplink.ziritas.com/joinSession?sessionID=50BF3CAD-E863-4B60-B049-53D83DE07ED6
            ///
            /*
             .onOpenURL(perform: { url in
             print("urlReceived\(url)")
             if url.host() == "deeplink.ziritas.com",
             let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
             let queryItems = components.queryItems,
             let sessionID = queryItems.first(where: { $0.name == "sessionID" })?.value {
             sessionIDToShow = SessionIDWrapper(id: sessionID)
             isShowingMoaJoin = true
             }
             
             })
             */
            
            
        }
    }
}

class DeepLinkManager: ObservableObject {
    @Published var sessionIDToShow: SessionIDWrapper?
    @Published var isShowingMoaJoin = false
    @Published var isDonatingScreen = false // New property to track donation screen visibility
    
    // Additional properties to hold donation information
    @Published var donationAddress: String?
    @Published var uniqueID: String?

    func handleDeepLink(_ url: URL) {
        print("urlReceived\(url)")
        if url.host() == "deeplink.ziritas.com",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            // Handling session join deep links
            if let sessionID = queryItems.first(where: { $0.name == "sessionID" })?.value {
                sessionIDToShow = SessionIDWrapper(id: sessionID)
                isShowingMoaJoin = true
            }
            // Handling donation deep links
            else if let address = queryItems.first(where: { $0.name == "address" })?.value,
                    let uniqueID = queryItems.first(where: { $0.name == "uniqueID" })?.value {
                donationAddress = address
                self.uniqueID = uniqueID
                isDonatingScreen = true
            }
        }
    }
}


struct SessionIDWrapper: Identifiable {
    let id: String
}
