//
//  CylinderPatchEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 12/2/24.
//

import RealityKit
import AVFoundation
import Combine
import UIKit

fileprivate let defaultMaterial = SimpleMaterial(color: .white, roughness: 1.0, isMetallic: false)
fileprivate let panelHorizontalAngle: Float = (2 / 3) * .pi
fileprivate let screenExtrusion: Float = 0.001
fileprivate let screenMargin: Float = 0.02
fileprivate let outlineMargin: Float = 0.004

final class CylinderScreenEntity: VirtualObjectEntity, HasPlayableComponent, HasCustomHighlightComponent {

    struct Intrinsics: Equatable, Hashable {
        
        var radius: Float
        var resource: MaterialResource?
        init(radius: Float = 1,
             resource: MaterialResource? = nil) {
            self.radius = radius
            self.resource = resource
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(radius)
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
            let mesh = MeshResource.generateCylinder(height: 1, radius: 1)
            let materials = [OcclusionMaterial()]
            return ModelEntity(mesh: mesh, materials: materials)
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
        let angle = Float(dt * rotationSpeed).truncatingRemainder(dividingBy: 2.0 * .pi)
        
        let rotation = simd_quatf(angle: -angle, axis: .init(0, 1, 0))
        panel.transform.rotation = rotation
        panelOutline.transform.rotation = rotation
        screen.transform.rotation = rotation
    }
    
    @MainActor
    func update(block: (inout Intrinsics) -> Void) {
        
        var intrinsics = self.intrinsics
        block(&intrinsics)
        
        guard intrinsics != self.intrinsics else { return }
        defer { self.intrinsics = intrinsics }
         
        let angleRatio = acos(transform.matrix.basisY.y) / .pi
        let isHorizontalCylinder = 0.25 < angleRatio && angleRatio < 0.75
        
        let _radius = intrinsics.radius
        let radius = _radius + outlineMargin + 0.001
        let _aspectRatio = Float(intrinsics.resource?.thumbnail.size.aspectRatio ?? 1)
        let aspectRatio = isHorizontalCylinder ? (1 / _aspectRatio) : _aspectRatio
        
        let panelMesh: MeshResource = {
            let submesh = Submesh.generateCylindricalPatches(radius: radius,
                                                             horizontalAngle: panelHorizontalAngle,
                                                             aspectRatio: aspectRatio,
                                                             skipAngle: panelHorizontalAngle,
                                                             count: 3,
                                                             unitAngle: .pi / 36)
            return try! MeshResource.generate(from: submesh)
        }()
        panel.model?.mesh = panelMesh
        
        let panelOutlineMesh: MeshResource = {
            let submesh = Submesh.generateVolumetricCylindricalPatches(radius: radius,
                                                                       verticalLength: panelHorizontalAngle * radius / aspectRatio + outlineMargin * 2.0,
                                                                       count: 3,
                                                                       unitAngle: .pi / 36,
                                                                       outlineMargin: outlineMargin).inverted
            return try! MeshResource.generate(from: submesh)
        }()
        panelOutline.model?.mesh = panelOutlineMesh
        
        let screenMesh: MeshResource = {
            let horizontalLength = panelHorizontalAngle * (radius + 0.001) - screenMargin * 2
            let horizontalAngle = horizontalLength / (radius + 0.001)
            let verticalLength = panelHorizontalAngle * (radius + 0.001) / aspectRatio - screenMargin * 2
            let aspectRatio = horizontalLength / verticalLength
            let submesh = Submesh.generateCylindricalPatches(radius: radius + 0.001,
                                                             horizontalAngle: horizontalAngle,
                                                             aspectRatio: aspectRatio,
                                                             skipAngle: panelHorizontalAngle,
                                                             count: 3,
                                                             unitAngle: .pi / 36,
                                                             rotate: isHorizontalCylinder)
            return try! MeshResource.generate(from: submesh)
        }()
        screen.model?.mesh = screenMesh
        
        occlusion.scale = .init(_radius, panelHorizontalAngle * radius / aspectRatio, _radius)
        
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
