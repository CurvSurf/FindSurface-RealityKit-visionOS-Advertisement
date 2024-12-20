//
//  SceneBoundary.swift
//  FindSurfaceRR-visionOS
//
//  Created by CurvSurf-SGKim on 8/5/24.
//

import Foundation
import simd

protocol SceneBoundaryProtocol {
    func contains(_ point: simd_float3) -> Bool
}

extension SceneBoundaryProtocol {
    func containedIndices(_ points: [simd_float3]) -> [Int] {
        return points.enumerated().filter { (_, point) in contains(point) }.map { $0.offset }
    }
}

struct CylinderBoundary: SceneBoundaryProtocol {
    var position: simd_float3
    var radius: Float
    var height: Float {
        didSet {
            radiusSquared = radius * radius
        }
    }
    
    private var radiusSquared: Float
    init(position: simd_float3, radius: Float, height: Float) {
        self.position = position
        self.radius = radius
        self.height = height
        self.radiusSquared = radius * radius
    }
    
    func contains(_ point: simd_float3) -> Bool {
        return -0.1 <= point.y && point.y <= height && length_squared(.init(point.x, 0, point.z)) <= radiusSquared
    }
//    func containedIndices(_ points: [simd_float3]) -> [Int] {
//        let heightRange = (-0.1)...height
//        let radiusSquared = radius * radius
//        
//        return points.enumerated().filter { (_, point) in
//            return heightRange.contains(point.y) && length_squared(.init(point.x, 0, point.z)) <= radiusSquared
//        }.map { $0.offset }
//    }
}

struct BoxBoundary: SceneBoundaryProtocol {
    var minPoint: simd_float3
    var maxPoint: simd_float3
    
    func contains(_ point: simd_float3) -> Bool {
        return minPoint.x <= point.x && point.x <= maxPoint.x &&
               minPoint.y <= point.y && point.y <= maxPoint.y &&
               minPoint.z <= point.z && point.z <= maxPoint.z
    }
//    func containedIndices(_ points: [simd_float3]) -> [Int] {
//        let xRange = minPoint.x...maxPoint.x
//        let yRange = minPoint.y...maxPoint.y
//        let zRange = minPoint.z...maxPoint.z
//        return points.enumerated().filter { (_, point) in
//            return xRange.contains(point.x) && yRange.contains(point.y) && zRange.contains(point.z)
//        }.map { $0.offset }
//    }
}

//struct CuboidBoundary: SceneBoundaryProtocol {
//    var matrix: simd_float4x4
//    
//    func containedIndices(_ points: [simd_float3]) -> [Int] {
//        let xAxis = matrix.basisX
//        let yAxis = matrix.basisY
//        let zAxis = matrix.basisZ
//        let position = matrix.position
//        
//        let transform = simd_float4x4.transform(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, origin: position)
//        let range = Float(-1)...Float(1)
//        return points.enumerated().filter { (_, point) in
//            let p = simd_make_float3(transform * simd_float4(point, 1))
//            return range.contains(p.x) && range.contains(p.y) && range.contains(p.z)
//        }.map { $0.offset }
//    }
//}
//
//extension simd_float4 {
//    static func plane(normal: simd_float3, point: simd_float3) -> simd_float4 {
//        return .init(normal, -dot(normal, point))
//    }
//}
//
//struct PolygonBoundary: SceneBoundaryProtocol {
//    var planes: [simd_float4]
//    
//    func containedIndices(_ points: [simd_float3]) -> [Int] {
//        points.enumerated().filter { (_, point) in
//            let aug = simd_float4(point, 1)
//            return planes.allSatisfy { plane in
//                dot(plane, aug) <= 0
//            }
//        }.map { $0.offset }
//    }
//}

enum SceneBoundary: SceneBoundaryProtocol {
    case cylinder(CylinderBoundary)
    case box(BoxBoundary)
//    case cuboid(CuboidBoundary)
//    case polygon(PolygonBoundary)
    
    func containedIndices(_ points: [simd_float3]) -> [Int] {
        switch self {
        case let .cylinder(cylinder):   return cylinder.containedIndices(points)
        case let .box(box):             return box.containedIndices(points)
//        case let .cuboid(cuboid):       return cuboid.containedIndices(points)
//        case let .polygon(polygon):     return polygon.containedIndices(points)
        }
    }
    
    func contains(_ point: simd_float3) -> Bool {
        switch self {
        case let .cylinder(cylinder): return cylinder.contains(point)
        case let .box(box): return box.contains(point)
        }
    }
}
