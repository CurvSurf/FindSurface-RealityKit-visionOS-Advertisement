//
//  ConeScreenEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 12/12/24.
//

import RealityKit
import AVFoundation
import Combine
import UIKit

fileprivate let defaultMaterial = SimpleMaterial(color: .white, roughness: 1.0, isMetallic: false)
fileprivate let panelHorizontalAngle: Float = (2 / 3) * .pi
fileprivate let screenExtrusion: Float = 0.001
fileprivate let screenMargin: Float = 0.015
fileprivate let outlineMargin: Float = 0.004

final class ConeScreenEntity: VirtualObjectEntity, HasPlayableComponent, HasCustomHighlightComponent {
    
    struct Intrinsics: Equatable, Hashable {
        var topRadius: Float
        var bottomRadius: Float
        var length: Float
        var rotation: TextureCoordinateRotation
        var resource: MaterialResource?
        init(topRadius: Float = 1,
             bottomRadius: Float = 1,
             length: Float = 1,
             rotation: TextureCoordinateRotation = .none,
             resource: MaterialResource? = nil) {
            self.topRadius = topRadius
            self.bottomRadius = bottomRadius
            self.length = length
            self.rotation = rotation
            self.resource = resource
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(topRadius)
            hasher.combine(bottomRadius)
            hasher.combine(length)
            hasher.combine(rotation)
            hasher.combine(resource)
        }
    }
    private(set) var intrinsics: Intrinsics
    
    private let panel: ModelEntity
    private let panelOutline: ModelEntity
    private let screen: ModelEntity
    private let occlusion: ModelEntity
    
    override var enableOcclusion: Bool {
        get { return occlusion.isEnabled }
        set { occlusion.isEnabled = newValue }
    }
    
    func updateHighlight() {
        let color: UIColor = switch highlightMode {
        case .none: .black
        case .hovered: .red
        case .selected: .green
        }
        panelOutline.model?.materials = [UnlitMaterial(color: color)]
    }
    required init() {
        
        let dummy = MeshResource.generatePlane(width: 1, height: 1)
        
        let panel: ModelEntity = {
            let materials = [defaultMaterial]
            return ModelEntity(mesh: dummy, materials: materials)
        }()
        
        let panelOutline: ModelEntity = {
            let materials = [UnlitMaterial(color: .black)]
            return ModelEntity(mesh: dummy, materials: materials)
        }()
        
        let screen: ModelEntity = {
            let materials = [defaultMaterial]
            return ModelEntity(mesh: dummy, materials: materials)
        }()
        
        let occlusion: ModelEntity = {
            let materials = [OcclusionMaterial()]
            return ModelEntity(mesh: dummy, materials: materials)
        }()
        
        self.panel = panel
        self.panelOutline = panelOutline
        self.screen = screen
        self.occlusion = occlusion
        self.intrinsics = Intrinsics()
        super.init()
        
        addChild(panel)
        addChild(panelOutline)
        addChild(screen)
        addChild(occlusion)
        
        screen.isVisible = false
        
        components.set(InputTargetComponent())
        components.set(HoverEffectComponent())
    }
    
    func setScreenMaterials(_ materials: [any Material]) {
        screen.model?.materials = materials
    }
    
    private var startTime: Double? = nil
    func setAnimationTime(_ time: Double) {
        if startTime == nil {
            startTime = time
        }
        guard let startTime else { return }
        let dt = time - startTime
        let period = 10.0
        let rotationSpeed = 2.0 * Double.pi / period
        var angle = Float(dt * rotationSpeed).truncatingRemainder(dividingBy: 2.0 * .pi)
        let rotation = intrinsics.rotation
        if rotation == .clockwise90 || rotation == .upsideDown {
            angle = -angle
        }
        
        let rotationTransform = simd_quatf(angle: -angle, axis: .init(0, 1, 0))
        panel.transform.rotation = rotationTransform
        panelOutline.transform.rotation = rotationTransform
        screen.transform.rotation = rotationTransform
    }
    
    @MainActor
    func update(block: (inout Intrinsics) -> Void) {
        
        var intrinsics = self.intrinsics
        block(&intrinsics)
        
        guard intrinsics != self.intrinsics else { return }
        defer { self.intrinsics = intrinsics }
        
        let _topRadius = intrinsics.topRadius
        let _bottomRadius = intrinsics.bottomRadius
        let diffRadius = _bottomRadius - _topRadius
        let length = intrinsics.length
        let _topHeight = 0.5 * length
        let _bottomHeight = -0.5 * length
        
        let middleRadius = (_topRadius + _bottomRadius) * 0.5
        
        let lateralLength = sqrt(length * length + diffRadius * diffRadius)
        let sinVertexHalfAngle = diffRadius / lateralLength
        let cosVertexHalfAngle = length / lateralLength
        
        let radiusOffset = (outlineMargin + 0.001) * cosVertexHalfAngle
        let topRadius = _topRadius + radiusOffset
        let bottomRadius = _bottomRadius + radiusOffset
        
        let panelMesh: MeshResource = {
            let submesh = Submesh.generateConicalPatches(topRadius: topRadius,
                                                         bottomRadius: bottomRadius,
                                                         horizontalAngle: panelHorizontalAngle,
                                                         topHeight: _topHeight,
                                                         bottomHeight: _bottomHeight,
                                                         skipAngle: panelHorizontalAngle,
                                                         count: 3,
                                                         unitAngle: .pi / 36)
            return try! MeshResource.generate(from: submesh)
        }()
        panel.model?.mesh = panelMesh
        
        let panelOutlineMesh: MeshResource = {
            let submesh = Submesh.generateVolumetricConicalSurface(topRadius: topRadius,
                                                                   bottomRadius: bottomRadius,
                                                                   length: length,
                                                                   padding: outlineMargin,
                                                                   subdivision: .radial(72)).inverted
            return try! MeshResource.generate(from: submesh)
        }()
        panelOutline.model?.mesh = panelOutlineMesh
        
        let screenMesh: MeshResource = {
            let screenMarginAngle = screenMargin / middleRadius
            let horizontalAngle = panelHorizontalAngle - screenMarginAngle * 2
            
            let radiusOffset = screenMargin * sinVertexHalfAngle
            let screenTopRadius = topRadius + radiusOffset + screenExtrusion
            let screenBottomRadius = bottomRadius - radiusOffset + screenExtrusion
            
            let heightOffset = screenMargin * cosVertexHalfAngle
            let screenTopHeight = _topHeight - heightOffset
            let screenBottomHeight = _bottomHeight + heightOffset
            
            let submesh = Submesh.generateConicalPatches(topRadius: screenTopRadius,
                                                         bottomRadius: screenBottomRadius,
                                                         horizontalAngle: horizontalAngle,
                                                         topHeight: screenTopHeight,
                                                         bottomHeight: screenBottomHeight,
                                                         skipAngle: panelHorizontalAngle,
                                                         count: 3,
                                                         unitAngle: .pi / 36,
                                                         rotate: intrinsics.rotation)
            return try! MeshResource.generate(from: submesh)
        }()
        screen.model?.mesh = screenMesh
        
        let occlusionMesh: MeshResource = {
            let submesh = Submesh.generateCone(topRadius: _topRadius,
                                               bottomRadius: _bottomRadius,
                                               length: length,
                                               subdivision: .radial(72))
            return try! MeshResource.generate(from: submesh)
        }()
        occlusion.model?.mesh = occlusionMesh
        
        if let resource = intrinsics.resource,
           resource.material.name != self.intrinsics.resource?.material.name ||
            resource.thumbnail.size.aspectRatio != self.intrinsics.resource?.thumbnail.size.aspectRatio {
            setScreenContent(resource)
        }
        
        Task {
            let shape = try! await ShapeResource.generateStaticMesh(from: panelOutlineMesh)
            components.set(CollisionComponent(shapes: [shape], isStatic: true))
        }
    }
    
    private var animationSubscription: AnyCancellable? = nil
    @MainActor
    override func playAppearingAnimation() {
        
        guard animationSubscription == nil else { return }
        
        let panelBegin: Double = 0.0
        let panelEnd: Double = 1.0
        let panelAnimation = FromToByAnimation<Double>(name: "panel",
                                                       from: panelBegin,
                                                       to: panelEnd,
                                                       duration: 1.0,
                                                       timing: .easeInOut,
                                                       bindTarget: .opacity)
        let panelAnimationResource = try! AnimationResource.generate(with: panelAnimation)
        
        let panelAnimationHandle = panel.playAnimation(panelAnimationResource)
        
        let panelAnimationPublisher = panel.scene!.publisher(for: AnimationEvents.PlaybackCompleted.self)
            .filter { $0.playbackController == panelAnimationHandle }
        
        animationSubscription = panelAnimationPublisher.sink { [weak self] _ in
            self?.screen.isVisible = true
            self?.playContent()
        }
    }
}
