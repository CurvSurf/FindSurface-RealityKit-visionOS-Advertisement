//
//  PlaneEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/23/24.
//

import RealityKit
import AVFoundation

fileprivate let planeThickness: Float = 0.0002
fileprivate let outlineWidth: Float = 0.005
fileprivate let occlusionThickness: Float = 0.00002

final class PlaneEntity: GeometryEntity {
    
    struct Intrinsics: Equatable {
        var width: Float
        var height: Float
        init(width: Float = 1, height: Float = 1) {
            self.width = width
            self.height = height
        }
    }
    
    private(set) var intrinsics: Intrinsics
    
    private let occlusion: ModelEntity
    private let surface: ModelEntity
    private let outline: ModelEntity
    
    var preview: Bool = false {
        didSet {
            surface.opacity = preview ? 0.2 : 0.5
        }
    }
    
    required init() {
        
        let volumeSubmesh = Submesh.generateCube(width: 1, height: 1, depth: 1)
        let volumeMesh = try! MeshResource.generate(from: volumeSubmesh)
        
        let occlusion = ModelEntity(mesh: volumeMesh,
                                    materials: [OcclusionMaterial()])
        occlusion.scale = .init(1, 1, planeThickness - occlusionThickness)
        
        let positions: [simd_float3] = [
            .init(-0.5, 0.5, 0), .init(0.5, 0.5, 0), .init(0.5, -0.5, 0), .init(-0.5, -0.5, 0)
        ]
        let normals: [simd_float3] = [
            .init(0, 0, 1), .init(0, 0, 1), .init(0, 0, 1), .init(0, 0, 1)
        ]
        let texcoords: [simd_float2] = [
            .init(0, 0), .init(1, 0), .init(1, 1), .init(0, 1)
        ]
        let triangleIndices: [UInt32] = [0, 3, 1, 1, 3, 2]
        let submesh = Submesh(positions: positions, normals: normals, texcoords: texcoords, triangleIndices: triangleIndices)
        let mesh = try! MeshResource.generate(from: submesh)
        let surface = ModelEntity(mesh: mesh,
                                  materials: [UnlitMaterial(color: .red)])
        surface.model?.mesh = volumeMesh
        surface.scale = .init(1, 1, planeThickness)
        surface.position.z = 0
        
        let outline = ModelEntity(mesh: try! .generate(from: volumeSubmesh.inverted),
                                  materials: [UnlitMaterial(color: .black)])
        outline.scale = surface.scale + .init(repeating: outlineWidth)
        
        self.intrinsics = Intrinsics(width: 1, height: 1)
        self.occlusion = occlusion
        self.surface = surface
        self.outline = outline
        super.init()
        
        addChild(occlusion)
        addChild(surface)
        addChild(outline)
    }
    
    convenience init(width: Float, height: Float) {
        self.init()
        update { intrinsics in
            intrinsics.width = width
            intrinsics.height = height
        }
    }
    
    func update(block: (inout Intrinsics) -> Void) {
        
        var intrinsics = self.intrinsics
        block(&intrinsics)
        
        guard intrinsics != self.intrinsics else { return }
        defer { self.intrinsics = intrinsics }
        
        let w = intrinsics.width
        let h = intrinsics.height
        
        occlusion.scale.x = w
        occlusion.scale.y = h
        surface.scale.x = w
        surface.scale.y = h
        outline.scale = surface.scale + .init(repeating: outlineWidth)
    }
}
