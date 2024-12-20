//
//  ModelEntity.swift
//  FindSurfaceST-visionOS
//
//  Created by CurvSurf-SGKim on 6/17/24.
//

import Foundation
import RealityKit
import ARKit

extension MeshResource {
    
    class func generate(from anchor: MeshAnchor) throws -> MeshResource {
        
        let positions = anchor.positions
        let normals = anchor.normals
        let indices = anchor.indices
        
        var descriptor = MeshDescriptor(name: anchor.id.uuidString)
        descriptor.positions = .init(positions)
        descriptor.normals = .init(normals)
        descriptor.primitives = .triangles(indices)
        
        return try .generate(from: [descriptor])
    }
}

extension ModelEntity {
    
    class func generateWireframe(from meshAnchor: MeshAnchor) async -> ModelEntity? {
        guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor),
              let mesh = try? MeshResource.generate(from: meshAnchor) else { return nil }
        
        let entity = ModelEntity(mesh: mesh, materials: .mesh)
        entity.name = meshAnchor.id.uuidString
        entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
        entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
        entity.components.set(InputTargetComponent())
        entity.physicsBody = PhysicsBodyComponent(mode: .static)
        return entity
    }
    
    class func generateWireframe(from meshAnchor: MeshAnchor, boundary: SceneBoundary) async -> ModelEntity? {
        
        guard let (mesh, shape) = try? await generateMeshAndShapeResources(from: meshAnchor,
                                                                           sceneBoundary: boundary) else {
            return nil
        }
        
        let entity = ModelEntity(mesh: mesh, materials: .mesh)
        entity.name = meshAnchor.id.uuidString
        entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
        entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
        entity.components.set(InputTargetComponent())
        entity.physicsBody = PhysicsBodyComponent(mode: .static)
        return entity
    }
    
    class func generateWireframe(from anchor: MeshAnchor, _ mesh: MeshResource, and shape: ShapeResource) -> ModelEntity {
        
        let entity = ModelEntity(mesh: mesh, materials: .mesh)
        entity.name = anchor.id.uuidString
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
        entity.components.set(InputTargetComponent())
        entity.physicsBody = PhysicsBodyComponent(mode: .static)
        return entity
    }
}

func generateMesh(from anchor: MeshAnchor, sceneBoundary: SceneBoundary) async -> ([simd_float3], [simd_float3], [UInt32]) {
    
    let positionIndicesInBoundary = sceneBoundary.containedIndices(anchor.worldPositions)
    
    var indexMap = [Int: Int]()
//    let _positionsInBoundary = anchor.positions.enumerated().filter { positionIndicesInBoundary.contains($0.offset) }
    let positions = anchor.positions.enumerated().map { $0 }
    let _positionsInBoundary = positionIndicesInBoundary.map { index in
        positions[index]
    }
    indexMap.reserveCapacity(_positionsInBoundary.count)
    let positionsInBoundary = _positionsInBoundary.enumerated().map {
        let newIndex = $0.offset
        let oldIndex = $0.element.offset
        let position = $0.element.element
        indexMap[oldIndex] = newIndex
        return position
    }
//    let normalsInBoundary = anchor.normals.enumerated().filter { positionIndicesInBoundary.contains($0.offset) }.map { $0.element }
    let normals = anchor.normals
    let normalsInBoundary = positionIndicesInBoundary.map { index in
        normals[index]
    }
    let faceIndicesInBoundary: [UInt32] = anchor.indices.chunks(ofCount: 3).filter { face in
        positionIndicesInBoundary.contains(Int(face[face.startIndex])) &&
        positionIndicesInBoundary.contains(Int(face[face.startIndex + 1])) &&
        positionIndicesInBoundary.contains(Int(face[face.startIndex + 2]))
    }.map { face in
        face.map { UInt32(indexMap[Int($0)]!) }
    }.flatMap { $0 }
//    let faceIndicesInBoundary: [UInt32] = anchor.faces.filter { face in
//        positionIndicesInBoundary.contains(face.0) &&
//        positionIndicesInBoundary.contains(face.1) &&
//        positionIndicesInBoundary.contains(face.2)
//    }.map { (face: (Int, Int, Int)) -> [UInt32] in
//        [UInt32(indexMap[face.0]!), UInt32(indexMap[face.1]!), UInt32(indexMap[face.2]!)]
//    }.flatMap { $0 }
    
    return (positionsInBoundary, normalsInBoundary, faceIndicesInBoundary)
}

func generateMeshAndShapeResources(_ anchorID: UUID, _ positions: [simd_float3], _ normals: [simd_float3], _ indices: [UInt32]) async throws -> (MeshResource, ShapeResource) {
    
    var descriptor = MeshDescriptor(name: anchorID.uuidString)
    descriptor.positions = .init(positions)
    descriptor.normals = .init(normals)
    descriptor.primitives = .triangles(indices)
    
    let mesh = try await MeshResource.generate(from: [descriptor])
    let shape = try await ShapeResource.generateStaticMesh(positions: positions, faceIndices: indices.map { UInt16($0) })
    
    return (mesh, shape)
}

func generateMeshAndShapeResources(from anchor: MeshAnchor, sceneBoundary: SceneBoundary?) async throws -> (MeshResource, ShapeResource) {
    
    guard let sceneBoundary else {
        let mesh = try await MeshResource.generate(from: anchor)
        let shape = try await ShapeResource.generateStaticMesh(from: anchor)
        return (mesh, shape)
    }
    
    let positionIndicesInBoundary = sceneBoundary.containedIndices(anchor.worldPositions)
    
    var indexMap = [Int: Int]()
//    let _positionsInBoundary = anchor.positions.enumerated().filter { positionIndicesInBoundary.contains($0.offset) }
    let positions = anchor.positions.enumerated().map { $0 }
    let _positionsInBoundary = positionIndicesInBoundary.map { index in
        positions[index]
    }
    indexMap.reserveCapacity(_positionsInBoundary.count)
    let positionsInBoundary = _positionsInBoundary.enumerated().map {
        let newIndex = $0.offset
        let oldIndex = $0.element.offset
        let position = $0.element.element
        indexMap[oldIndex] = newIndex
        return position
    }
//    let normalsInBoundary = anchor.normals.enumerated().filter { positionIndicesInBoundary.contains($0.offset) }.map { $0.element }
    let normals = anchor.normals
    let normalsInBoundary = positionIndicesInBoundary.map { index in
        normals[index]
    }
//    let faceIndicesInBoundary: [UInt32] = anchor.faces.filter { face in
//        positionIndicesInBoundary.contains(face.0) &&
//        positionIndicesInBoundary.contains(face.1) &&
//        positionIndicesInBoundary.contains(face.2)
//    }.map { (face: (Int, Int, Int)) -> [UInt32] in
//        [UInt32(indexMap[face.0]!), UInt32(indexMap[face.1]!), UInt32(indexMap[face.2]!)]
//    }.flatMap { $0 }
    let faceIndicesInBoundary: [UInt32] = anchor.indices.chunks(ofCount: 3).filter { face in
        positionIndicesInBoundary.contains(Int(face[face.startIndex])) &&
        positionIndicesInBoundary.contains(Int(face[face.startIndex + 1])) &&
        positionIndicesInBoundary.contains(Int(face[face.startIndex + 2]))
    }.map { face in
        face.map { UInt32(indexMap[Int($0)]!) }
    }.flatMap { $0 }
    
    var descriptor = MeshDescriptor(name: anchor.id.uuidString)
    descriptor.positions = .init(positionsInBoundary)
    descriptor.normals = .init(normalsInBoundary)
    descriptor.primitives = .triangles(faceIndicesInBoundary)
    
    let mesh = try await MeshResource.generate(from: [descriptor])
    let shape = try await ShapeResource.generateStaticMesh(positions: positionsInBoundary, faceIndices: faceIndicesInBoundary.map { UInt16($0) })
    
    return (mesh, shape)
}
