//
//  PersistentObject.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 10/22/24.
//

import Foundation
import SwiftData
import simd

import FindSurface_visionOS

enum Geometry: Hashable, Codable {
    case plane(Plane)
    case sphere(Sphere)
    case cylinder(Cylinder)
    case cone(Cone)
    case torus(Torus, Float, Float)
    
    var extrinsics: simd_float4x4 {
        get {
            switch self {
            case let .plane(plane):         return plane.extrinsics
            case let .sphere(sphere):       return sphere.extrinsics
            case let .cylinder(cylinder):   return cylinder.extrinsics
            case let .cone(cone):           return cone.extrinsics
            case let .torus(torus, _, _):   return torus.extrinsics
            }
        }
        set {
            switch self {
            case var .plane(plane):
                plane.extrinsics = newValue
                self = .plane(plane)
                
            case var .sphere(sphere):
                sphere.extrinsics = newValue
                self = .sphere(sphere)
                
            case var .cylinder(cylinder):
                cylinder.extrinsics = newValue
                self = .cylinder(cylinder)
                
            case var .cone(cone):
                cone.extrinsics = newValue
                self = .cone(cone)
                
            case .torus(var torus, let beginAngle, let deltaAngle):
                torus.extrinsics = newValue
                self = .torus(torus, beginAngle, deltaAngle)
            }
        }
    }
}

struct PendingObject {
    let name: String
    let geometry: Geometry
    let inliers: [simd_float3]
    let rmsError: Float
    let materialData: MaterialData
    let gesturePosition: simd_float3
    let deviceTransform: simd_float4x4
}

struct ReferenceFrame: Hashable, Codable, Equatable {
    private var _vectors: [simd_float3]
    
    init(matrix: simd_float4x4) {
        self.init(xAxis: matrix.basisX,
                  yAxis: matrix.basisY,
                  zAxis: matrix.basisZ,
                  origin: matrix.position)
    }
    
    init(xAxis: simd_float3,
         yAxis: simd_float3,
         zAxis: simd_float3,
         origin: simd_float3) {
        self._vectors = [xAxis, yAxis, zAxis, origin]
    }
    
    var matrix: simd_float4x4 {
        get {
            simd_float4x4(.init(_vectors[0], 0),
                          .init(_vectors[1], 0),
                          .init(_vectors[2], 0),
                          .init(_vectors[3], 1))
        }
        set {
            _vectors = [simd_make_float3(newValue.columns.0),
                        simd_make_float3(newValue.columns.1),
                        simd_make_float3(newValue.columns.2),
                        simd_make_float3(newValue.columns.3)]
        }
    }
}

enum VirtualObjectType: Hashable, Codable, Equatable {
    case ceiling(ReferenceFrame)
    case floor(ReferenceFrame)
    case wall(ReferenceFrame)
    case sphere(ReferenceFrame, Float)
    case cylinder(ReferenceFrame, Float)
    case cone(ReferenceFrame, Float, Float, Float, TextureCoordinateRotation)
    case torus(ReferenceFrame, Float, Float, Float, Float, Float, TextureCoordinateRotation)
    
    var extrinsics: ReferenceFrame {
        switch self {
        case let .ceiling(frame): return frame
        case let .floor(frame): return frame
        case let .wall(frame): return frame
        case .sphere(let frame, _): return frame
        case .cylinder(let frame, _): return frame
        case .cone(let frame, _, _, _, _): return frame
        case .torus(let frame, _, _, _, _, _, _): return frame
        }
    }
}

@Model
final class ObjectData {
    
    @Attribute(.unique) private(set) var uuid: UUID
    private(set) var name: String
    var geometry: Geometry
    var inliers: [simd_float3]
    private(set) var rmsError: Float
    @Relationship var materialData: MaterialData
    var objectType: VirtualObjectType
    
    init(uuid: UUID,
         name: String,
         geometry: Geometry,
         inliers: [simd_float3],
         rmsError: Float,
         materialData: MaterialData,
         gesturePosition: simd_float3,
         deviceTransform: simd_float4x4) {
        self.uuid = uuid
        self.name = name
        self.geometry = geometry
        self.inliers = inliers
        self.rmsError = rmsError
        self.materialData = materialData
        let aspectRatio = Float(materialData.resource!.thumbnail.size.aspectRatio)
        self.objectType = makeVirtualObjectType(geometry, gesturePosition, deviceTransform, aspectRatio)
    }
    
    var extrinsics: simd_float4x4 {
        get { geometry.extrinsics }
        set { geometry.extrinsics = newValue }
    }
    
    convenience init(from object: PendingObject,
                     forID id: UUID) {
        self.init(uuid: id,
                  name: object.name,
                  geometry: object.geometry,
                  inliers: object.inliers,
                  rmsError: object.rmsError,
                  materialData: object.materialData,
                  gesturePosition: object.gesturePosition,
                  deviceTransform: object.deviceTransform)
    }
}

fileprivate func makeVirtualObjectType(ofPlane plane: Plane,
                                       _ gesturePosition: simd_float3,
                                       _ deviceTransform: simd_float4x4) -> VirtualObjectType {
    let normal = plane.normal
    let tenDegree = Float.pi / 18
    
    if acos(-normal.y) < tenDegree { // ceiling
        let devicePosition = deviceTransform.position
        let towardDevice = normalize(devicePosition - gesturePosition)
        let dotdn = dot(towardDevice, normal)
        let cos1Deg = cos(Float.pi / 180)
        let cos179Deg = -cos1Deg
        let isParallel = dotdn > cos1Deg || dotdn < cos179Deg
        
        let _zAxis = isParallel ? deviceTransform.basisY : normalize(towardDevice - dotdn * normal)
        let _yAxis = -normal
        let _xAxis = normalize(cross(_yAxis, _zAxis))
        let _position = gesturePosition
        let transform = plane.transform
        let xAxis = simd_make_float3(transform * simd_float4(_xAxis, 0))
        let yAxis = simd_make_float3(transform * simd_float4(_yAxis, 0))
        let zAxis = simd_make_float3(transform * simd_float4(_zAxis, 0))
        let position = simd_make_float3(transform * simd_float4(_position, 1))
        let extrinsics = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
        let frame = ReferenceFrame(matrix: extrinsics)
        return .ceiling(frame)
    } else if acos(normal.y) < tenDegree { // floor
        let devicePosition = deviceTransform.position
        let towardDevice = normalize(devicePosition - gesturePosition)
        let dotdn = dot(towardDevice, normal)
        let cos1Deg = cos(Float.pi / 180)
        let cos179Deg = -cos1Deg
        let isParallel = dotdn > cos1Deg || dotdn < cos179Deg
        
        let _zAxis = isParallel ? -deviceTransform.basisY : normalize(towardDevice - dotdn * normal)
        let _yAxis = normal
        let _xAxis = normalize(cross(_yAxis, _zAxis))
        let _position = gesturePosition
        let transform = plane.transform
        let xAxis = simd_make_float3(transform * simd_float4(_xAxis, 0))
        let yAxis = simd_make_float3(transform * simd_float4(_yAxis, 0))
        let zAxis = simd_make_float3(transform * simd_float4(_zAxis, 0))
        let position = simd_make_float3(transform * simd_float4(_position, 1))
        let extrinsics = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
        let frame = ReferenceFrame(matrix: extrinsics)
        return .floor(frame)
    } else { // wall
        let up = simd_float3(0, 1, 0)
        
        let _yAxis = normalize(up - dot(up, normal) * normal)
        let _xAxis = normalize(cross(_yAxis, normal))
        let _zAxis = normal
        let _position = gesturePosition
        let transform = plane.transform
        let xAxis = simd_make_float3(transform * simd_float4(_xAxis, 0))
        let yAxis = simd_make_float3(transform * simd_float4(_yAxis, 0))
        let zAxis = simd_make_float3(transform * simd_float4(_zAxis, 0))
        let position = simd_make_float3(transform * simd_float4(_position, 1))
        let extrinsics = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
        let frame = ReferenceFrame(matrix: extrinsics)
        return .wall(frame)
    }
}

fileprivate func makeVirtualObjectType(ofSphere sphere: Sphere,
                                       _ gesturePosition: simd_float3,
                                       _ deviceTransform: simd_float4x4) -> VirtualObjectType {
    let center = sphere.center
    
    let _xAxis = normalize(deviceTransform.position - center)
    let _yAxis = normalize(deviceTransform.basisY)
    let _zAxis = normalize(cross(_xAxis, _yAxis))
    let _position = center
    let transform = sphere.transform
    let xAxis = simd_make_float3(transform * simd_float4(_xAxis, 0))
    let yAxis = simd_make_float3(transform * simd_float4(_yAxis, 0))
    let zAxis = simd_make_float3(transform * simd_float4(_zAxis, 0))
    let position = simd_make_float3(transform * simd_float4(_position, 1))
    let extrinsics = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
    let frame = ReferenceFrame(matrix: extrinsics)
    return .sphere(frame, sphere.radius + 0.01)
}

fileprivate func makeVirtualObjectType(ofCylinder cylinder: Cylinder,
                                       _ gesturePosition: simd_float3,
                                       _ deviceTransform: simd_float4x4) -> VirtualObjectType {
    let center = cylinder.center
    let axis = cylinder.axis
    
    let axisAngleDegree = acos(axis.y) * 180 / .pi
    let isHorizontalCylinder = 60 < axisAngleDegree && axisAngleDegree < 120
    let deviceRight = deviceTransform.basisX
    let dotar = dot(axis, deviceRight)
    let axisRightAngle = acos(dotar)
    let axisLeftAngle = acos(-dotar)
    let newAxis = isHorizontalCylinder && axisRightAngle > axisLeftAngle ? -axis : axis
    let foot = center + dot(gesturePosition - center, newAxis) * newAxis
    
    let _xAxis = normalize(gesturePosition - foot)
    let _yAxis = newAxis
    let _zAxis = normalize(cross(_xAxis, _yAxis))
    let _position = foot
    let transform = cylinder.transform
    let xAxis = simd_make_float3(transform * simd_float4(_xAxis, 0))
    let yAxis = simd_make_float3(transform * simd_float4(_yAxis, 0))
    let zAxis = simd_make_float3(transform * simd_float4(_zAxis, 0))
    let position = simd_make_float3(transform * simd_float4(_position, 1))
    let extrinsics = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
    let frame = ReferenceFrame(matrix: extrinsics)
    return .cylinder(frame, cylinder.radius + 0.01)
}

fileprivate func makeVirtualObjectType(ofCone cone: Cone,
                                       _ gesturePosition: simd_float3,
                                       _ deviceTransform: simd_float4x4,
                                       _ screenAspectRatio: Float) -> VirtualObjectType {
    var gesturePosition = gesturePosition
    
    let center = cone.center
    let axis = cone.axis
    let top = cone.top
    let bottom = cone.bottom
    let topRadius = cone.topRadius
    let bottomRadius = cone.bottomRadius
    let topBottomDistance = distance(top, bottom)
    let vertex = cone.vertex
    
    let rotation: TextureCoordinateRotation = {
        let axisAngleDegree = acos(axis.y) * 180 / .pi
        let isHorizontal = 60 < axisAngleDegree && axisAngleDegree < 120
        let (angleBetweenAxisAndDeviceRight, angleBetweenAxisAndDeviceLeft) = {
            let deviceRight = deviceTransform.basisX
            let dotar = dot(axis, deviceRight)
            return (acos(dotar), acos(-dotar))
        }()
        let isUpsideDown = cone.axis.y < 0
        if isHorizontal {
            return angleBetweenAxisAndDeviceRight > angleBetweenAxisAndDeviceLeft ? .clockwise90 : .counterClockwise90
        } else {
            return isUpsideDown ? .upsideDown : .none
        }
    }()
    let screenAspectRatio = rotation == .clockwise90 || rotation == .counterClockwise90 ? (1 / screenAspectRatio) : screenAspectRatio
    
    
    var foot = center + dot(gesturePosition - center, axis) * axis
    let footRatio = max(distance(foot, top) / topBottomDistance, 0.2)
    let footRadius = mix(topRadius, bottomRadius, t: footRatio)
    
    if distance(foot, vertex) < 0.001 {
        foot = top - footRatio * topBottomDistance * axis
        var orthogonal = acos(dot(deviceTransform.basisZ, axis)) < .pi / 180 ? deviceTransform.basisY : deviceTransform.basisZ
        orthogonal = normalize(cross(axis, orthogonal))
        orthogonal = normalize(cross(orthogonal, axis))
        gesturePosition = foot + orthogonal * footRadius
    }
    let screenWidth = Float.pi * (2 / 3) * footRadius
    let screenHeight = screenWidth / screenAspectRatio
    let availableScreenHeight = distance(vertex, gesturePosition)
    let hasNotEnoughSpaceForScreen = screenHeight * 0.5 > availableScreenHeight
    
    let (position, verticalLength, screenTopRadius, screenBottomRadius) = {
        let horizontal = bottomRadius - topRadius
        let vertical = topBottomDistance
        let lateral = sqrt(horizontal * horizontal + vertical * vertical)
        let sinVertexHalfAngle = horizontal / lateral
        let cosVertexHalfAngle = vertical / lateral

        if hasNotEnoughSpaceForScreen {
            print("has not enough space for screen: true")
            let verticalLength = screenHeight * cosVertexHalfAngle
            let position = vertex - 0.5 * verticalLength * axis
            let screenTopRadius = Float.zero
            let screenBottomRadius = screenHeight * sinVertexHalfAngle
            return (position, verticalLength, screenTopRadius, screenBottomRadius)
        } else {
            print("has not enough space for screen: false")
            let position = foot
            let verticalLength = screenHeight * cosVertexHalfAngle
            let radiusOffset = screenHeight * 0.5 * sinVertexHalfAngle
            let screenTopRadius = footRadius - radiusOffset
            let screenBottomRadius = footRadius + radiusOffset
            return (position, verticalLength, screenTopRadius, screenBottomRadius)
        }
    }()
    
    let extrinsics: simd_float4x4 = {
        let _xAxis = normalize(gesturePosition - foot)
        let _yAxis = axis
        let _zAxis = normalize(cross(_xAxis, _yAxis))
        let _position = position
        let transform = cone.transform
        let xAxis = simd_make_float3(transform * simd_float4(_xAxis, 0))
        let yAxis = simd_make_float3(transform * simd_float4(_yAxis, 0))
        let zAxis = simd_make_float3(transform * simd_float4(_zAxis, 0))
        let position = simd_make_float3(transform * simd_float4(_position, 1))
        return .extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
    }()
    
    let frame = ReferenceFrame(matrix: extrinsics)
    return .cone(frame, screenTopRadius, screenBottomRadius, verticalLength, rotation)
}

fileprivate func makeVirtualObjectType(ofTorus torus: Torus,
                                       _ gesturePosition: simd_float3,
                                       _ deviceTransform: simd_float4x4,
                                       _ beginAngle: Float,
                                       _ deltaAngle: Float) -> VirtualObjectType {
    
    let center = torus.center
    let axis = torus.axis
    let meanRadius = torus.meanRadius
    let tubeRadius = torus.tubeRadius
    
    let axisAngleDegree = acos(axis.y) * 180 / .pi
    let isHorizontal = 60 < axisAngleDegree && axisAngleDegree < 120
    
    let p = normalize(gesturePosition - center)
    let l = normalize(cross(p, axis))
    let r = normalize(cross(axis, l))
    let foot = center + meanRadius * r
    
    let _up = cross(axis, .init(0, 1, 0))
    let _upLength = length(_up)
    let up = _upLength > 0 ? cross(normalize(_up), axis) : axis
    
    let gf = normalize(gesturePosition - foot)
    let gestureAngle = {
        let footTangent = cross(axis, r)
        let angle = acos(dot(r, gf))
        let xros = cross(r, gf)
        let isPositiveAngle = dot(xros, footTangent) > 0
        return isPositiveAngle ? angle : -angle
    }()
    enum GestureWorldDirection {
        case up
        case down
        case right
        case left
    }
    let gestureDirection: GestureWorldDirection = {
        let _angle = acos(dot(up, r))
        let xros = cross(up, r)
        let isPositiveAngle = _angle < .pi / 180 || dot(xros, axis) > 0
        let angle = isPositiveAngle ? _angle : -_angle
        let angleDegree = angle * 180 / .pi
        if -45 <= angleDegree && angleDegree < 45 {
            return .up
        } else if 45 <= angleDegree && angleDegree < 135 {
            return .right
        } else if -135 <= angleDegree && angleDegree < -45 {
            return .left
        } else {
            return .down
        }
    }()
    
    let rotation: TextureCoordinateRotation = {
        if isHorizontal {
            let isAxisPointingTowardDevice = dot(axis, normalize(deviceTransform.position - center)) > 0
            switch gestureDirection {
            case .up: return isAxisPointingTowardDevice ? .upsideDown : .none
            case .down: return isAxisPointingTowardDevice ? .none : .upsideDown
            case .right: return isAxisPointingTowardDevice ? .clockwise90 : .counterClockwise90
            case .left: return isAxisPointingTowardDevice ? .counterClockwise90 : .clockwise90
            }
        } else {
            let gestureAngleDegree = gestureAngle * 180 / .pi
            let isInnerSide = gestureAngleDegree > 90 || gestureAngleDegree < -90
            return isInnerSide ? .upsideDown : .none
        }
    }()
    
    let _xAxis = r
    let _yAxis = axis
    let _zAxis = normalize(cross(_xAxis, _yAxis))
    let _position = center
    let transform = torus.transform
    let xAxis = simd_make_float3(transform * simd_float4(_xAxis, 0))
    let yAxis = simd_make_float3(transform * simd_float4(_yAxis, 0))
    let zAxis = simd_make_float3(transform * simd_float4(_zAxis, 0))
    let position = simd_make_float3(transform * simd_float4(_position, 1))
    let extrinsics = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
    let frame = ReferenceFrame(matrix: extrinsics)
    return .torus(frame, meanRadius, tubeRadius, gestureAngle, beginAngle, deltaAngle, rotation)
}

fileprivate func makeVirtualObjectType(_ geometry: Geometry,
                                       _ gesturePosition: simd_float3,
                                       _ deviceTransform: simd_float4x4,
                                       _ aspectRatio: Float) -> VirtualObjectType {
    let result: VirtualObjectType = switch geometry {
        
    case let .plane(plane):         makeVirtualObjectType(ofPlane: plane, gesturePosition, deviceTransform)
    case let .sphere(sphere):       makeVirtualObjectType(ofSphere: sphere, gesturePosition, deviceTransform)
    case let .cylinder(cylinder):   makeVirtualObjectType(ofCylinder: cylinder, gesturePosition, deviceTransform)
    case let .cone(cone):           makeVirtualObjectType(ofCone: cone, gesturePosition, deviceTransform, aspectRatio)
    case let .torus(torus, beginAngle, deltaAngle):
        makeVirtualObjectType(ofTorus: torus, gesturePosition, deviceTransform, beginAngle, deltaAngle)
    }
    
    return result
}
