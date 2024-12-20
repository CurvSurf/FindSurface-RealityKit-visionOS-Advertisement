//
//  EntityMenuWindow.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 12/13/24.
//

import ARKit
import RealityKit

import _RealityKit_SwiftUI

final class EntityMenuWindow: Entity {
    
    var menuView: ViewAttachmentEntity? = nil {
        didSet {
            if let oldValue {
                oldValue.removeFromParent()
            }
            if let menuView {
                addChild(menuView)
            }
        }
    }
    
    required init() {
        super.init()
        self.isEnabled = false
    }
}
