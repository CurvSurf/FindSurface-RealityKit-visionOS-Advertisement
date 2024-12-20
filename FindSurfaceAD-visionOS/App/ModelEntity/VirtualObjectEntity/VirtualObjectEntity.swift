//
//  VirtualObjectEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 12/2/24.
//

import RealityKit
import AVKit

enum HighlightMode {
    case none
    case hovered
    case selected
}

@MainActor
class VirtualObjectEntity: Entity {
    
    open var enableOcclusion: Bool {
        get { fatalError("This property must be overriden.") }
        set { fatalError("This property must be overriden.")}
    }
    
    required init() {
        super.init()
    }
    
    open func playAppearingAnimation() {}
}

struct CustomHighlightComponent: Component {
    var highlightMode: HighlightMode = .none
}

protocol HasCustomHighlightComponent {
    func updateHighlight()
}
extension HasCustomHighlightComponent where Self: Entity {
    var highlightMode: HighlightMode {
        get { components[CustomHighlightComponent.self]?.highlightMode ?? .none }
        set {
            components.set(CustomHighlightComponent(highlightMode: newValue))
            updateHighlight()
        }
    }
}

struct CustomTransformComponent: Component {
    var transform: simd_float4x4?
}

protocol HasCustomTransformComponent {}
extension HasCustomTransformComponent where Self: Entity {
    var customTransform: simd_float4x4? {
        get { components[CustomTransformComponent.self]?.transform }
        set { components.set(CustomTransformComponent(transform: newValue)) }
    }
}

extension VirtualObjectEntity: HasCustomTransformComponent {}

struct PlayableComponent: Component {
    var audioController: AudioPlaybackController?
    var player: AVPlayer?
}

protocol HasPlayableComponent {
    var audioController: AudioPlaybackController? { get set }
    var player: AVPlayer? { get set }
    func setScreenMaterials(_ materials: [any Material])
}

extension HasPlayableComponent where Self: Entity {
    
    var isPlaying: Bool {
        guard let player else { return false }
        return player.timeControlStatus == .playing
    }
    
    func toggleContent() {
        if isPlaying {
            pauseContent()
        } else {
            playContent()
        }
    }
    
    func playContent() {
        if let player,
           let audioController {
            player.play()
            audioController.play()
        }
    }
    
    func pauseContent() {
        if let player,
           let audioController {
            player.pause()
            audioController.pause()
        }
    }
    
    func rewindContent() {
        if let player,
           let audioController {
            player.seek(to: .zero)
            audioController.seek(to: .zero)
        }
    }
    
    var audioController: AudioPlaybackController? {
        get { self.components[PlayableComponent.self]?.audioController }
        set {
            if var component = components[PlayableComponent.self] {
                component.audioController = newValue
                self.components.set(component)
            } else {
                self.components.set(PlayableComponent(audioController: newValue, player: nil))
            }
        }
    }
    var player: AVPlayer? {
        get { self.components[PlayableComponent.self]?.player }
        set {
            if var component = components[PlayableComponent.self] {
                component.player = newValue
                self.components.set(component)
            } else {
                self.components.set(PlayableComponent(audioController: nil, player: newValue))
            }
        }
    }
    
    func setScreenMaterial(_ material: any Material) {
        setScreenMaterials([material])
    }
    
    func setScreenContent(_ resource: MaterialResource) {
        if resource.material is VideoMaterial {
            let newPlayer = AVPlayer(url: resource.data.url)
            newPlayer.volume = 0
            newPlayer.actionAtItemEnd = .pause
            let newMaterial = VideoMaterial(avPlayer: newPlayer)
            setScreenMaterial(newMaterial)
            if let player {
                player.pause()
                self.stopAllAudio()
            }
            var audio = SpatialAudioComponent(gain: -30)
            audio.distanceAttenuation = .rolloff(factor: 2)
            audio.reverbLevel = 1.5
            self.spatialAudio = audio
            player = newPlayer
            if let audioResource = resource.audioResource {
                audioController = self.prepareAudio(audioResource)
            }
        } else {
            setScreenMaterial(resource.material)
        }
    }
}

extension VirtualObjectEntity {
    
    class func generate(from object: ObjectData, sessionTransform: simd_float4x4) -> VirtualObjectEntity {
        
        return switch object.objectType {
            
        case let .ceiling(extrinsics): {
            let entity = CeilingScreenEntity()
            let matrix0 = extrinsics.matrix
            let xAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisX, 0))
            let yAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisY, 0))
            let zAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisZ, 0))
            let position = simd_make_float3(sessionTransform * simd_float4(matrix0.position, 1))
            let matrix1 = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
            entity.transform = Transform(matrix: matrix1)
            entity.setScreenContent(object.materialData.resource!)
            return entity
        }()
            
        case let .floor(extrinsics): {
            let entity = FloorScreenEntity()
            let matrix0 = extrinsics.matrix
            let xAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisX, 0))
            let yAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisY, 0))
            let zAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisZ, 0))
            let position = simd_make_float3(sessionTransform * simd_float4(matrix0.position, 1))
            let matrix1 = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
            entity.transform = Transform(matrix: matrix1)
            entity.setScreenContent(object.materialData.resource!)
            return entity
        }()
            
        case let .wall(extrinsics): {
            let entity = WallScreenEntity()
            let matrix0 = extrinsics.matrix
            let xAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisX, 0))
            let yAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisY, 0))
            let zAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisZ, 0))
            let position = simd_make_float3(sessionTransform * simd_float4(matrix0.position, 1))
            let matrix1 = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
            entity.transform = Transform(matrix: matrix1)
            entity.setScreenContent(object.materialData.resource!)
            return entity
        }()
            
        case let .sphere(extrinsics, radius): {
            let entity = SphereScreenEntity()
            let matrix0 = extrinsics.matrix
            let xAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisX, 0))
            let yAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisY, 0))
            let zAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisZ, 0))
            let position = simd_make_float3(sessionTransform * simd_float4(matrix0.position, 1))
            let matrix1 = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
            entity.transform = Transform(matrix: matrix1)
            entity.update { intrinsics in
                intrinsics.radius = radius
                intrinsics.resource = object.materialData.resource
            }
            return entity
        }()
            
        case let .cylinder(extrinsics, radius): {
            let entity = CylinderScreenEntity()
            let matrix0 = extrinsics.matrix
            let xAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisX, 0))
            let yAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisY, 0))
            let zAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisZ, 0))
            let position = simd_make_float3(sessionTransform * simd_float4(matrix0.position, 1))
            let matrix1 = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
            entity.transform = Transform(matrix: matrix1)
            entity.update { intrinsics in
                intrinsics.radius = radius
                intrinsics.resource = object.materialData.resource
            }
            return entity
        }()
            
        case let .cone(extrinsics, topRadius, bottomRadius, length, rotation): {
            let entity = ConeScreenEntity()
            let matrix0 = extrinsics.matrix
            let xAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisX, 0))
            let yAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisY, 0))
            let zAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisZ, 0))
            let position = simd_make_float3(sessionTransform * simd_float4(matrix0.position, 1))
            let matrix1 = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
            entity.transform = Transform(matrix: matrix1)
            entity.update { intrinsics in
                intrinsics.topRadius = topRadius
                intrinsics.bottomRadius = bottomRadius
                intrinsics.length = length
                intrinsics.rotation = rotation
                intrinsics.resource = object.materialData.resource
            }
            return entity
        }()
            
        case let .torus(extrinsics, meanRadius, tubeRadius, gestureAngle, beginAngle, deltaAngle, rotation): {
            let entity = TorusScreenEntity()
            let matrix0 = extrinsics.matrix
            let xAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisX, 0))
            let yAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisY, 0))
            let zAxis = simd_make_float3(sessionTransform * simd_float4(matrix0.basisZ, 0))
            let position = simd_make_float3(sessionTransform * simd_float4(matrix0.position, 1))
            let matrix1 = simd_float4x4.extrinsics(xAxis: xAxis, yAxis: yAxis, zAxis: zAxis, position: position)
            entity.transform = Transform(matrix: matrix1)
            entity.update { intrinsics in
                intrinsics.meanRadius = meanRadius
                intrinsics.tubeRadius = tubeRadius
                intrinsics.gestureAngle = gestureAngle
                intrinsics.beginAngle = beginAngle
                intrinsics.deltaAngle = deltaAngle
                intrinsics.rotation = rotation
                intrinsics.resource = object.materialData.resource
            }
            return entity
        }()
            
        }
    }
}

