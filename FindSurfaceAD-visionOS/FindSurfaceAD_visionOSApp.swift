//
//  FindSurfaceAD_visionOSApp.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/22/24.
//

import SwiftUI

@main
struct FindSurfaceAD_visionOSApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
     }
}
