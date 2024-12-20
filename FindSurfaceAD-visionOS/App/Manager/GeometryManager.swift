//
//  GeometryManager.swift
//  FindSurfaceRT-visionOS
//
//  Created by CurvSurf-SGKim on 10/8/24.
//

import ARKit
import RealityKit
import _RealityKit_SwiftUI

import FindSurface_visionOS


@Observable
final class GeometryManager {
    
    typealias VirtualObject = VirtualObjectEntity & HasPlayableComponent & HasCustomHighlightComponent
    
    let rootEntity: Entity
    
    private var pendingObjects: [UUID: PendingObject] = [:]
    private let geometryEntity: Entity
    private(set) var geometryEntityMap: [UUID: GeometryEntity] = [:]
    private let objectEntity: Entity
    private(set) var objectEntityMap: [UUID: VirtualObject] = [:]
    
    private(set) var undoStack: [UUID] = []
    
    let entityMenuWindow: EntityMenuWindow
    
    func locateEntityMenuWindow(_ devicePosition: simd_float3, entity: VirtualObject) {
        
        let bounds = entity.visualBounds(relativeTo: nil)
        let center = bounds.center
        let radius = bounds.boundingRadius
        let towardDevice = normalize(devicePosition - center)
        let windowPosition = center + towardDevice * radius
        
        entityMenuWindow.look(at: devicePosition, from: windowPosition, relativeTo: nil, forward: .positiveZ)
        currentEntity = entity
    }
    
    var currentEntity: (VirtualObject)? = nil {
        didSet {
            entityMenuWindow.isEnabled = currentEntity != nil
            currentEntity?.highlightMode = .selected
            oldValue?.highlightMode = .none
        }
    }
    var currentEntityID: UUID? {
        guard let currentEntity else { return nil }
        return objectEntityMap.first { $0.value == currentEntity }?.key
    }
    var isCurrentEntityPlaying: Bool {
        get {
            access(keyPath: \.isCurrentEntityPlaying)
            return currentEntity?.isPlaying ?? false
        }
        set {
            withMutation(keyPath: \.isCurrentEntityPlaying) {
                if newValue {
                    currentEntity?.pauseContent()
                } else {
                    currentEntity?.playContent()
                }
            }
        }
    }
    
    @MainActor
    func highlightObject(_ deviceTransform: simd_float4x4) async {
        for entity in objectEntityMap.values {
            if entity.highlightMode != .selected {
                entity.highlightMode = .none
            }
        }
        
        guard let hit = objectEntity.scene?.raycast(origin: deviceTransform.position,
                                                    direction: -deviceTransform.basisZ,
                                                    query: .nearest).first?.entity as? VirtualObject else {
            return
        }
        if hit.highlightMode != .selected {
            hit.highlightMode = .hovered
        }
    }
    
    var shouldShowGeometryEntities: Bool {
        get {
            access(keyPath: \.shouldShowGeometryEntities)
            return geometryEntity.isEnabled
        }
        set {
            withMutation(keyPath: \.shouldShowGeometryEntities) {
                geometryEntity.isEnabled = newValue
            }
        }
    }
    
    init() {
        
        let rootEntity = Entity()
        
        let geometryEntity = Entity()
        rootEntity.addChild(geometryEntity)

        let objectEntity = Entity()
        rootEntity.addChild(objectEntity)
        
        let entityMenuWindow = EntityMenuWindow()
        rootEntity.addChild(entityMenuWindow)
        
        self.rootEntity = rootEntity
        self.geometryEntity = geometryEntity
        self.objectEntity = objectEntity
        self.entityMenuWindow = entityMenuWindow
    }

    func addPendingObject(_ result: FindSurface.Result,
                          resource: MaterialResource,
                          gesturePosition: simd_float3,
                          deviceTransform: simd_float4x4) async -> WorldAnchor {
        
        let count = await pendingObjects.count + PersistentDataModel.shared.objectData.count
        let pendingObject: PendingObject = switch result {
        case let .foundPlane(plane, inliers, rmsError): {
            return .init(name: "Plane\(count)",
                         geometry: .plane(plane),
                         inliers: inliers,
                         rmsError: rmsError,
                         materialData: resource.data,
                         gesturePosition: gesturePosition,
                         deviceTransform: deviceTransform)
        }()
        case let .foundSphere(sphere, inliers, rmsError): {
            return .init(name: "Sphere\(count)",
                         geometry: .sphere(sphere),
                         inliers: inliers,
                         rmsError: rmsError,
                         materialData: resource.data,
                         gesturePosition: gesturePosition,
                         deviceTransform: deviceTransform)
        }()
        case let .foundCylinder(cylinder, inliers, rmsError): {
            return .init(name: "Cylinder\(count)",
                         geometry: .cylinder(cylinder),
                         inliers: inliers,
                         rmsError: rmsError,
                         materialData: resource.data,
                         gesturePosition: gesturePosition,
                         deviceTransform: deviceTransform)
        }()
        case let .foundCone(cone, inliers, rmsError): {
            return .init(name: "Cone\(count)",
                         geometry: .cone(cone),
                         inliers: inliers,
                         rmsError: rmsError,
                         materialData: resource.data,
                         gesturePosition: gesturePosition,
                         deviceTransform: deviceTransform)
        }()
        case let .foundTorus(torus, inliers, rmsError): {
            var (beginAngle, deltaAngle) = torus.calcAngleRange(from: inliers)
            if deltaAngle > 1.5 * .pi {
                beginAngle = .zero
                deltaAngle = .twoPi
            }
            return .init(name: "Torus\(count)",
                         geometry: .torus(torus, beginAngle, deltaAngle),
                         inliers: inliers,
                         rmsError: rmsError,
                         materialData: resource.data,
                         gesturePosition: gesturePosition,
                         deviceTransform: deviceTransform)
        }()
        default: fatalError("Should never reach here (\(result)).")
        }
        
        let anchor = WorldAnchor(originFromAnchorTransform: pendingObject.geometry.extrinsics)
        pendingObjects[anchor.id] = pendingObject
        return anchor
    }
    
    func removePendingObject(forKey key: UUID) {
        pendingObjects.removeValue(forKey: key)
    }
    
    @MainActor
    func anchorAdded(_ anchor: WorldAnchor) async -> Bool {
        
        var persistentObject: ObjectData? = nil
        if let pendingObject = pendingObjects.removeValue(forKey: anchor.id) {
            
            let object = ObjectData(from: pendingObject, forID: anchor.id)
            PersistentDataModel.shared.context.insert(object)
            persistentObject = object
            undoStack.append(anchor.id)
        } else {
            persistentObject = PersistentDataModel.shared.objectData.first { $0.uuid == anchor.id }
        }
        
        guard let persistentObject else {
            return false
        }
        
        let anchorMatrix = anchor.originFromAnchorTransform
        
        let geometry = await GeometryEntity.generate(from: persistentObject)
        geometry.transform = Transform(matrix: anchorMatrix)
        
        let virtualObject = VirtualObjectEntity.generate(from: persistentObject, sessionTransform: anchorMatrix)
        virtualObject.customTransform = persistentObject.objectType.extrinsics.matrix
        geometryEntity.addChild(geometry)
        geometryEntityMap[anchor.id] = geometry
        
        objectEntity.addChild(virtualObject)
        objectEntityMap[anchor.id] = (virtualObject as! VirtualObject)
        virtualObject.enableOcclusion = !shouldShowGeometryEntities
        virtualObject.playAppearingAnimation()
        
        return true
    }
    
    @MainActor
    func anchorUpdated(_ anchor: WorldAnchor) async {
        
        let anchorMatrix = anchor.originFromAnchorTransform
        
        if let geometry = geometryEntityMap[anchor.id],
           let object = objectEntityMap[anchor.id] {
            
            geometry.transform = Transform(matrix: anchorMatrix)
            geometry.data?.extrinsics = anchorMatrix
            
            let customTransform = object.customTransform!
            let xAxis = simd_make_float3(anchorMatrix * simd_float4(customTransform.basisX, 0))
            let yAxis = simd_make_float3(anchorMatrix * simd_float4(customTransform.basisY, 0))
            let zAxis = simd_make_float3(anchorMatrix * simd_float4(customTransform.basisZ, 0))
            let position = simd_make_float3(anchorMatrix * simd_float4(customTransform.position, 1))
            
            let objectMatrix = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
            object.transform = Transform(matrix: objectMatrix)
        }
    }
    
    @MainActor
    func anchorRemoved(_ anchor: WorldAnchor) async {
        await anchorRemoved(forID: anchor.id)
    }
    
    @MainActor
    func anchorRemoved(forID id: UUID) async {
        
        if let index = undoStack.firstIndex(of: id) {
            undoStack.remove(at: index)
        }
        if let entity = geometryEntityMap.removeValue(forKey: id),
           geometryEntity.children.contains(entity) {
            geometryEntity.removeChild(entity)
        }
        if let entity = objectEntityMap.removeValue(forKey: id),
           objectEntity.children.contains(entity) {
            objectEntity.removeChild(entity)
            if let currentEntity,
               currentEntity == entity {
                self.currentEntity = nil
            }
        }
        
        if let objectIndex = PersistentDataModel.shared.objectData.firstIndex(where: { $0.uuid == id }) {
            PersistentDataModel.shared.objectData.remove(at: objectIndex)
        }
    }
}

fileprivate func angle(_ a: simd_float3, _ b: simd_float3, _ c: simd_float3 = .init(0, -1, 0)) -> Float {
    let angle = acos(dot(a, b))
    if dot(c, cross(a, b)) < 0 {
        return -angle
    } else {
        return angle
    }
}

extension Torus {
    func calcAngleRange(from inliers: [simd_float3]) -> (begin: Float, delta: Float) {
        
        let projected = inliers.map { point in
            normalize(simd_float3(point.x, 0, point.z))
        }
        var projectedCenter = projected.reduce(.zero, +) / Float(projected.count)
        
        if length(projectedCenter) < 0.1 {
            return (begin: .zero, delta: .twoPi)
        }
        projectedCenter = normalize(projectedCenter)
        
        let baseAngle = angle(.init(1, 0, 0), projectedCenter)
        
        let angles = projected.map {
            return angle(projectedCenter, $0)
        }
        
        guard let (beginAngle, endAngle) = angles.minAndMax() else {
            return (begin: .zero, delta: .twoPi)
        }
        
        let begin = beginAngle + baseAngle
        let end = endAngle + baseAngle
        let delta = end - begin
        
        return (begin: begin, delta: delta)
    }
}
