//
//  GeometryEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/22/24.
//

import RealityKit

@MainActor
class GeometryEntity: Entity {
    
    required init() {
        super.init()
    }
}

struct PersistentDataComponent: Component {
    var data: ObjectData
}

protocol HasPersistentDataComponent {
    
    var data: ObjectData? { get set }
}

extension HasPersistentDataComponent where Self: Entity {
    var data: ObjectData? {
        get { self.components[PersistentDataComponent.self]?.data }
        set {
            if let newValue {
                self.components.set(PersistentDataComponent(data: newValue))
            }
        }
    }
}

extension GeometryEntity: HasPersistentDataComponent {
    
    class func generate(from object: ObjectData) async -> GeometryEntity {
        
        let entity: GeometryEntity = switch object.geometry {
        case let .plane(plane): {
            let entity = PlaneEntity(width: plane.width, height: plane.height)
            return entity as GeometryEntity
        }()
        case let .sphere(sphere): {
            let entity = SphereEntity(radius: sphere.radius)
            return entity as GeometryEntity
        }()
        case let .cylinder(cylinder): {
            let entity = CylinderEntity(radius: cylinder.radius,
                                        length: cylinder.height,
                                        shape: .surface)
            return entity as GeometryEntity
        }()
        case let .cone(cone): {
            let entity = ConeEntity(topRadius: cone.topRadius,
                                    bottomRadius: cone.bottomRadius,
                                    length: cone.height,
                                    shape: .surface)
            return entity as GeometryEntity
        }()
        case let .torus(torus, beginAngle, deltaAngle): {
            let entity = TorusEntity(meanRadius: torus.meanRadius,
                                     tubeRadius: torus.tubeRadius,
                                     tubeBegin: deltaAngle > 1.5 * .pi ? .zero : beginAngle,
                                     tubeAngle: deltaAngle > 1.5 * .pi ? .twoPi : deltaAngle)
            return entity as GeometryEntity
        }()
        }
        
        entity.name = object.name
        entity.transform = Transform(matrix: object.extrinsics)
        entity.data = object
        return entity
    }
}

extension Array where Element == (any Material) {
    
    static var mesh: [any Material] {
        return [UnlitMaterial(color: .blue).wireframe]
    }
    
    static var plane: [any Material] {
        return [UnlitMaterial(color: .red)]
    }
    
    static var sphere: [any Material] {
        return [UnlitMaterial(color: .green)]
    }
    
    static var cylinder: [any Material] {
        return [UnlitMaterial(color: .purple)]
    }
    
    static var cone: [any Material] {
        return [UnlitMaterial(color: .cyan)]
    }
    
    static var torus: [any Material] {
        return [UnlitMaterial(color: .yellow)]
    }
}
