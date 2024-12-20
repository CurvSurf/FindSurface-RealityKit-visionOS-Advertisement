//
//  FindSurfaceAD_visionOSApp.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/22/24.
//

import SwiftUI

import FindSurface_visionOS

@Observable
final class ScenePhaseTracker: ScenePhaseTrackerProtocol {
    var activeScene: Set<SceneID> = []
}

@main
struct FindSurfaceAD_visionOSApp: App {

    @State private var appModel = AppModel()
    @State private var sessionManager = SessionManager()
    @State private var scenePhaseTracker = ScenePhaseTracker()
    
    @Environment(\.openWindow) private var openWindow
    
    init() {
        PlayableComponent.registerComponent()
        CustomTransformComponent.registerComponent()
        PersistentDataComponent.registerComponent()
        CustomHighlightComponent.registerComponent()
    }
    
    var body: some Scene {
        
        WindowGroup(sceneID: SceneID.startup, for: SceneID.self) { _ in
            StartupView()
                .modelContainer(PersistentDataModel.shared.container)
                .modelContext(PersistentDataModel.shared.context)
                .environment(sessionManager)
                .environment(appModel)
                .trackingScenePhase(by: scenePhaseTracker,
                                    sceneID: SceneID.startup)
                .glassBackgroundEffect()
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)

        ImmersiveSpace(sceneID: SceneID.immersiveSpace, for: SceneID.self) { _ in
            ImmersiveView()
                .environment(appModel)
                .environment(sessionManager)
                .environment(FindSurface.instance)
                .environment(scenePhaseTracker)
                .trackingScenePhase(by: scenePhaseTracker,
                                    sceneID: SceneID.immersiveSpace)
                .onAppear {
                    
                }
                .onDisappear {
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        WindowGroup(sceneID: SceneID.inspector, for: SceneID.self) { _ in
            ResourceImportView()
                .modelContainer(PersistentDataModel.shared.container)
                .environment(appModel)
                .trackingScenePhase(by: scenePhaseTracker,
                                    sceneID: SceneID.inspector)
                .glassBackgroundEffect()
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        
        
        WindowGroup(sceneID: SceneID.userGuide, for: SceneID.self) { _ in
            UserGuideView()
                .environment(scenePhaseTracker)
                .trackingScenePhase(by: scenePhaseTracker, sceneID: .userGuide)
                .glassBackgroundEffect()
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
     }
}

