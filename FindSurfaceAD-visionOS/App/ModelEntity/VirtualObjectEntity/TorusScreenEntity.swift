//
//  TorusScreenEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 12/18/24.
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

final class TorusScreenEntity: VirtualObjectEntity, HasPlayableComponent, HasCustomHighlightComponent {

    struct Intrinsics: Equatable, Hashable {
        var meanRadius: Float
        var tubeRadius: Float
        var gestureAngle: Float
        var beginAngle: Float
        var deltaAngle: Float
        var rotation: TextureCoordinateRotation
        var resource: MaterialResource?
        init(meanRadius: Float = 1,
             tubeRadius: Float = 0.1,
             gestureAngle: Float = 0,
             beginAngle: Float = 0,
             deltaAngle: Float = .twoPi,
             rotation: TextureCoordinateRotation = .none,
             resource: MaterialResource? = nil) {
            self.meanRadius = meanRadius
            self.tubeRadius = tubeRadius
            self.gestureAngle = gestureAngle
            self.beginAngle = beginAngle
            self.deltaAngle = deltaAngle
            self.rotation = rotation
            self.resource = resource
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(meanRadius)
            hasher.combine(tubeRadius)
            hasher.combine(gestureAngle)
            hasher.combine(beginAngle)
            hasher.combine(deltaAngle)
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
        
    }
    
    @MainActor
    func update(block: (inout Intrinsics) -> Void) {
        
        var intrinsics = self.intrinsics
        block(&intrinsics)
        
        guard intrinsics != self.intrinsics else { return }
        defer { self.intrinsics = intrinsics }
        
        let meanRadius = intrinsics.meanRadius
        let _tubeRadius = intrinsics.tubeRadius
        let gestureAngle = intrinsics.gestureAngle
        let rotation = intrinsics.rotation
        let resource = intrinsics.resource
        
        let tubeRadius = _tubeRadius + outlineMargin + 0.001
        
        let _aspectRatio = Float(resource!.thumbnail.size.aspectRatio)
        let aspectRatio = rotation == .clockwise90 || rotation == .counterClockwise90 ? 1 / _aspectRatio : _aspectRatio
        
        let verticalAngle = Float.twoPi / 3
        let verticalLength = verticalAngle * tubeRadius
        let horizontalLength = verticalLength * aspectRatio
        let horizontalRadius = meanRadius + cos(abs(gestureAngle)) * tubeRadius
        let horizontalAngle = horizontalLength / horizontalRadius
        
        let panelMesh: MeshResource = {
            let submesh = Submesh.generateToricPatch(meanRadius: meanRadius,
                                                     tubeRadius: tubeRadius,
                                                     verticalCenterAngle: gestureAngle,
                                                     horizontalAngle: horizontalAngle,
                                                     verticalAngle: verticalAngle,
                                                     unitAngle: .pi / 36)
            return try! MeshResource.generate(from: submesh)
        }()
        panel.model?.mesh = panelMesh
        
        let panelOutlineMesh: MeshResource = {
            let submesh = Submesh.generateVolumetricToricPatch(meanRadius: meanRadius,
                                                               tubeRadius: tubeRadius - 0.001,
                                                               verticalCenterAngle: gestureAngle,
                                                               horizontalAngle: horizontalAngle,
                                                               verticalAngle: verticalAngle,
                                                               unitAngle: .pi / 36,
                                                               outlineMargin: outlineMargin).inverted
            return try! MeshResource.generate(from: submesh)
        }()
        panelOutline.model?.mesh = panelOutlineMesh
        
        let screenMesh: MeshResource = {
            let tubeRadius = tubeRadius + screenExtrusion
            let screenMarginVerticalAngle = screenMargin / tubeRadius
            let screenMarginHorizontalAngle = screenMargin / meanRadius
            let verticalAngle = verticalAngle - screenMarginVerticalAngle
            let horizontalAngle = horizontalAngle - screenMarginHorizontalAngle
            let submesh = Submesh.generateToricPatch(meanRadius: meanRadius,
                                                     tubeRadius: tubeRadius,
                                                     verticalCenterAngle: gestureAngle,
                                                     horizontalAngle: horizontalAngle,
                                                     verticalAngle: verticalAngle,
                                                     unitAngle: .pi / 36,
                                                     rotate: rotation)
            return try! MeshResource.generate(from: submesh)
        }()
        screen.model?.mesh = screenMesh
        
        let occlusionMesh: MeshResource = {
            let submesh = Submesh.generateToricPatch(meanRadius: meanRadius,
                                                     tubeRadius: _tubeRadius - screenExtrusion,
                                                     verticalCenterAngle: gestureAngle,
                                                     horizontalAngle: horizontalAngle,
                                                     verticalAngle: verticalAngle,
                                                     unitAngle: .pi / 36,
                                                     rotate: rotation).inverted
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
