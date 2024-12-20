//
//  EntityOpacity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/23/24.
//

import RealityKit

extension Entity {
    
    var opacity: Float {
        get { components[OpacityComponent.self]?.opacity ?? 0 }
        set { components.set(OpacityComponent(opacity: newValue)) }
    }
    
    var isVisible: Bool {
        get { opacity != 0 }
        set { opacity = newValue ? 1 : 0 }
    }
}
