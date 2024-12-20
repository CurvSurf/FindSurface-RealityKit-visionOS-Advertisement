//
//  MeshManager.swift
//  FindSurfaceRT-visionOS
//
//  Created by CurvSurf-SGKim on 10/8/24.
//

import ARKit
import RealityKit
import simd

@MainActor
fileprivate final class AxisIndicator: Entity {
    
    required init() {
        
        let (origin, xAxis, yAxis, zAxis) = {
            let origin = Submesh.generateSphere(radius: 0.005)
            let arrowbody = Submesh.generateCylinder(radius: 0.003, length: 0.041)
            let arrowhead = Submesh.generateCone(topRadius: 0, bottomRadius: 0.005, length: 0.025)
            
            let arrowheadY = arrowhead.translated(y: 0.0575)
            let arrowbodyY = arrowbody.translated(y: 0.0245)
            
            let yAxis = arrowheadY + arrowbodyY
            let xAxis = yAxis.rotated(angle: .pi * 0.5, axis: .init(0, 0, 1))
            let zAxis = yAxis.rotated(angle: .pi * 0.5, axis: .init(1, 0, 0))
            
            let originMesh = try! MeshResource.generate(name: "Origin", from: origin)
            let xAxisMesh = try! MeshResource.generate(name: "X-Axis", from: xAxis)
            let yAxisMesh = try! MeshResource.generate(name: "Y-Axis", from: yAxis)
            let zAxisMesh = try! MeshResource.generate(name: "Z-Axis", from: zAxis)
            
            let originMat = [SimpleMaterial(color: .white, roughness: 0.75, isMetallic: true)]
            let xAxisMat = [SimpleMaterial(color: .red, roughness: 0.75, isMetallic: true)]
            let yAxisMat = [SimpleMaterial(color: .green, roughness: 0.75, isMetallic: true)]
            let zAxisMat = [SimpleMaterial(color: .blue, roughness: 0.75, isMetallic: true)]
            
            let originModel = ModelEntity(mesh: originMesh, materials: originMat)
            let xAxisModel = ModelEntity(mesh: xAxisMesh, materials: xAxisMat)
            let yAxisModel = ModelEntity(mesh: yAxisMesh, materials: yAxisMat)
            let zAxisModel = ModelEntity(mesh: zAxisMesh, materials: zAxisMat)
            
            return (originModel, xAxisModel, yAxisModel, zAxisModel)
        }()
        
        super.init()
        addChild(origin)
        addChild(xAxis)
        addChild(yAxis)
        addChild(zAxis)
    }
}

@Observable
final class MeshVertexManager {
    
    let rootEntity = Entity()
    
    private var entityMap: [UUID: ModelEntity] = [:]
    
    private var vertexMap: [UUID: [simd_float3]] = [:]
    private var faceMap: [UUID: [(Int, Int, Int)]] = [:]
    private(set) var vertexCount: Int = 0
    
    init() {
        rootEntity.isVisible = true
    }
    
    var vertices: [simd_float3] {
        return vertexMap.values.flatMap { $0 }
    }
    
    var shouldShowMesh: Bool {
        get {
            access(keyPath: \.shouldShowMesh)
            return rootEntity.isVisible
        }
        set {
            withMutation(keyPath: \.shouldShowMesh) {
                rootEntity.isVisible = newValue
            }
        }
    }
    
    @MainActor
    func anchorAdded(_ anchor: MeshAnchor) async {
        
        var boundingBox = BoundingBox()
        let worldPositions = anchor.worldPositions
        for worldPosition in worldPositions {
            boundingBox.formUnion(worldPosition)
        }
        let m = boundingBox.min
        let M = boundingBox.max
        let corners = [
            m,
            simd_float3(m.x, m.y, M.z),
            simd_float3(m.x, M.y, m.z),
            simd_float3(m.x, M.y, M.z),
            simd_float3(M.x, m.y, m.z),
            simd_float3(M.x, m.y, M.z),
            simd_float3(M.x, M.y, m.z),
            M
        ]
        
        if corners.allSatisfy({ corner in
            SceneBoundaryEntity.boundary.contains(corner)
        }) {
            guard let entity = await ModelEntity.generateWireframe(from: anchor) else { return }
            rootEntity.addChild(entity)
            entityMap[anchor.id] = entity
            
            updateVerticesAndFaces(worldPositions, anchor.faces, forKey: anchor.id)
        } else {
            let (positions, normals, indices) = await generateMesh(from: anchor,
                                                                   sceneBoundary: SceneBoundaryEntity.boundary)
            var mesh: MeshResource
            var shape: ShapeResource
            do {
                (mesh, shape) = try await generateMeshAndShapeResources(anchor.id, positions, normals, indices)
            } catch {
                print("error: \(error)")
                return
            }
            let entity = ModelEntity.generateWireframe(from: anchor, mesh, and: shape)
            rootEntity.addChild(entity)
            entityMap[anchor.id] = entity
            
            let transform = anchor.originFromAnchorTransform
            await updateVerticesAndFaces(positions, indices, transform, forKey: anchor.id)
        }
    }
    
    @MainActor
    func anchorUpdated(_ anchor: MeshAnchor) async {
        
        var boundingBox = BoundingBox()
        let worldPositions = anchor.worldPositions
        for worldPosition in worldPositions {
            boundingBox.formUnion(worldPosition)
        }
        let m = boundingBox.min
        let M = boundingBox.max
        let corners = [
            m,
            simd_float3(m.x, m.y, M.z),
            simd_float3(m.x, M.y, m.z),
            simd_float3(m.x, M.y, M.z),
            simd_float3(M.x, m.y, m.z),
            simd_float3(M.x, m.y, M.z),
            simd_float3(M.x, M.y, m.z),
            M
        ]
        
        if corners.allSatisfy({ corner in
            SceneBoundaryEntity.boundary.contains(corner)
        }) {
            guard let entity = entityMap[anchor.id],
                  let materials = entity.model?.materials,
                  let (mesh, shape) = try? await generateMeshAndShapeResources(anchor.id, anchor.positions, anchor.normals, anchor.indices) else {
                return
            }
            entity.model = ModelComponent(mesh: mesh, materials: materials)
            let transform = anchor.originFromAnchorTransform
            entity.transform = Transform(matrix: transform)
            entity.collision?.shapes = [shape]
            
            updateVerticesAndFaces(worldPositions, anchor.faces, forKey: anchor.id)
            
        } else {
            let (positions, normals, indices) = await generateMesh(from: anchor,
                                                                   sceneBoundary: SceneBoundaryEntity.boundary)
            
            
            guard let entity = entityMap[anchor.id],
                  let materials = entity.model?.materials else {
                return
            }
            var mesh: MeshResource
            var shape: ShapeResource
            do {
                (mesh, shape) = try await generateMeshAndShapeResources(anchor.id, positions, normals, indices)
            } catch {
                print("error: \(error)")
                return
            }
            entity.model = ModelComponent(mesh: mesh, materials: materials)
            let transform = anchor.originFromAnchorTransform
            entity.transform = Transform(matrix: transform)
            entity.collision?.shapes = [shape]
            
            await updateVerticesAndFaces(positions, indices, transform, forKey: anchor.id)
        }
    }
    
    @MainActor
    func anchorRemoved(_ anchor: MeshAnchor) async {
        
        entityMap.removeValue(forKey: anchor.id)?.removeFromParent()
        updateVerticesAndFaces(nil, nil, forKey: anchor.id)
    }
    
    private func updateVerticesAndFaces(_ vertices: [simd_float3]?,
                                        _ indices: [UInt32]?,
                                        _ transform: simd_float4x4,
                                        forKey key: UUID) async {
        guard let vertices,
              let indices else {
            await updateVerticesAndFaces(nil, nil, forKey: key)
            return
        }
        
        let worldPositions = vertices.map { simd_make_float3(transform * simd_float4($0, 1)) }
        let faces = indices.chunks(ofCount: 3).map { (Int($0[$0.startIndex]), Int($0[$0.startIndex + 1]), Int($0[$0.startIndex + 2])) }
        
        return await updateVerticesAndFaces(worldPositions, faces, forKey: key)
    }
    
    @MainActor
    private func updateVerticesAndFaces(_ vertices: [simd_float3]?,
                                        _ faces: [(Int, Int, Int)]?,
                                        forKey key: UUID) {
        guard let vertices,
              let faces else {
            vertexCount -= vertexMap.removeValue(forKey: key)?.count ?? 0
            faceMap.removeValue(forKey: key)
            return
        }
        
        let removedVertexCount = vertexMap.updateValue(vertices, forKey: key)?.count ?? 0
        vertexCount += vertices.count - removedVertexCount
        faceMap.updateValue(faces, forKey: key)
    }
    
    
    func raycastAll(origin: simd_float3, direction: simd_float3) async -> [CollisionCastHit] {
        return await rootEntity.scene?.raycast(origin: origin, direction: direction, query: .all) ?? []
    }
    func raycast(origin: simd_float3, direction: simd_float3) async -> CollisionCastHit? {
        return await raycastAll(origin: origin, direction: direction).first
    }
    
    @MainActor
    func nearestTriangleVertices(_ hit: CollisionCastHit) async -> (simd_float3, simd_float3, simd_float3)? {
        guard let triangleHit = hit.triangleHit else {
            return nil
        }
        
        guard let id = UUID(uuidString: hit.entity.name),
              let vertices = vertexMap[id],
              let faces = faceMap[id] else { return nil }
        
        let face = faces[triangleHit.faceIndex]
        let triangleVertices = [vertices[face.0], vertices[face.1], vertices[face.2]]
        
        let location = hit.position
        
        let result = zip(triangleVertices, triangleVertices.map {
            distance_squared($0, location)
        }).sorted { lhs, rhs in
            lhs.1 < rhs.1
        }.map { $0.0 }
        
        return (result[0], result[1], result[2])
    }
}
