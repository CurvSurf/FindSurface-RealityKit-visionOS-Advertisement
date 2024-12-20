//
//  SceneBoundaryEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 12/17/24.
//

import Foundation
import RealityKit

final class SceneBoundaryEntity: Entity {
    
    static let boundaryRadius: Float = 5.00
    static let boundaryHeight: Float = 5.00
    
    static let boundaryRadiusSquared = boundaryRadius * boundaryRadius
    static let boundaryShowingRadius = boundaryRadius - 1.0
    static let boundaryShowingRadiusSquared = boundaryShowingRadius * boundaryShowingRadius
    static let boundary = SceneBoundary.cylinder(.init(position: .zero, radius: boundaryRadius, height: boundaryHeight))
    
    private let cylinder: ModelEntity
    
    required init() {
        
        let mesh = MeshResource.generateCylindricalSurface(radius: Self.boundaryRadius,
                                                           length: 1.0,
                                                           subdivision: .radial(144),
                                                           insideOut: true)
        let materials = [UnlitMaterial(color: .orange)]
        let entity = ModelEntity(mesh: mesh, materials: materials)
        entity.position = .init(0, 0.50, 0)
        entity.isVisible = false
        entity.opacity = 0.3
        self.cylinder = entity
        super.init()
        
        addChild(entity)
    }
    
    func detectDeviceAnchor(_ devicePosition: simd_float3) {
        
        let displacement = simd_float3(devicePosition.x, 0, devicePosition.z)
        let distanceSquared = length_squared(displacement)
        
        guard distanceSquared > Self.boundaryShowingRadiusSquared else {
            cylinder.opacity = 0.0
            return
        }
        
        let factor = 1.0 - sqrt(max((Self.boundaryRadius - sqrt(distanceSquared) / (Self.boundaryRadius - Self.boundaryShowingRadius)), 0))
        cylinder.opacity = min(max(factor * 0.3, 0.0), 1.0)
    }
}
