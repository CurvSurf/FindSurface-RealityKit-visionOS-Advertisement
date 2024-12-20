//
//  SessionManager.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/22/24.
//

import ARKit

@MainActor
@Observable
final class SessionManager {
    
    private let session = ARKitSession()
    
    var allRequiredProvidersAreSupported: Bool {
        WorldTrackingProvider.isSupported &&
        SceneReconstructionProvider.isSupported &&
        HandTrackingProvider.isSupported
    }
    
    private var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    private var handTrackingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    
    var handTrackingAllowed: Bool { handTrackingAuthorizationStatus == .allowed }
    var worldSensingAllowed: Bool { worldSensingAuthorizationStatus == .allowed }
    
    private var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed &&
        handTrackingAuthorizationStatus == .allowed
    }
    
    var canEnterImmersiveSpace: Bool {
        allRequiredProvidersAreSupported &&
        allRequiredAuthorizationsAreGranted
    }
    
    func requestRequiredAuthorizations() async {
        let result = await session.requestAuthorization(for: [.worldSensing, .handTracking])
        worldSensingAuthorizationStatus = result[.worldSensing]!
        handTrackingAuthorizationStatus = result[.handTracking]!
    }
    
    func queryRequiredAuthorizations() async {
        let result = await session.queryAuthorization(for: [.worldSensing, .handTracking])
        worldSensingAuthorizationStatus = result[.worldSensing]!
        handTrackingAuthorizationStatus = result[.handTracking]!
    }
    
    func run(with providers: [any DataProvider]) async {
        do {
            try await session.run(providers)
        } catch {
            return
        }
    }
    
    @MainActor
    func monitorSessionEvents(onError errorHandler: (ARKitSession.Error) -> Void) async {
        for await event in session.events {
            switch event {
                
            case let .authorizationChanged(type: type, status: status):
                switch type {
                case .worldSensing: worldSensingAuthorizationStatus = status
                case .handTracking: handTrackingAuthorizationStatus = status
                case .cameraAccess: fallthrough
                @unknown default: break
                }
                
            case let .dataProviderStateChanged(dataProviders: _, newState: state, error: error):
                if case .stopped = state,
                   let error {
                    errorHandler(error)
                }
                
            @unknown default:
                fatalError("An unknown error occurred: \(event).")
            }
        }
    }
    
}
