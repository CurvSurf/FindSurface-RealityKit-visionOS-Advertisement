//
//  SceneID.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/24/24.
//

enum SceneID: String, Codable, SceneIDProtocol {
    case startup = "StartupView"
    case immersiveSpace = "ImmersiveView"
    case inspector = "InspectorView"
    case userGuide = "UserGuideView"
}

