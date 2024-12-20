//
//  FloorEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/28/24.
//

import RealityKit
import AVFoundation
import Combine
import UIKit

fileprivate let defaultMaterial = SimpleMaterial(color: .white, roughness: 1.0, isMetallic: false)
fileprivate let slateWidth: Float = 1.0
fileprivate let slateHeight: Float = slateWidth * 9.0 / 16.0
fileprivate let slateDepth: Float = 0.02
fileprivate let hingeAngle: Float = .pi / 2
fileprivate let hingeRadius: Float = slateDepth * 0.5 / cos(hingeAngle * 0.5)
fileprivate let objectOffset: Float = hingeRadius * sin(hingeAngle * 0.5)
fileprivate let screenMargin: Float = 0.02
fileprivate let screenWidth: Float = slateWidth - screenMargin * 2
fileprivate let screenHeight: Float = slateHeight - screenMargin * 2
fileprivate let outlineMargin: Float = 0.004

final class FloorScreenEntity: VirtualObjectEntity, HasPlayableComponent, HasCustomHighlightComponent {
    
    private let object: Entity
    private let hinge: ModelEntity
    private let hingeOutline: ModelEntity
    private let slate: ModelEntity
    private let slateOutline: ModelEntity
    private let screen: ModelEntity
    
    private var _dummy: Bool = true
    override var enableOcclusion: Bool {
        get { return _dummy }
        set { _dummy = newValue }
    }
    
    func updateHighlight() {
        let color: UIColor = switch highlightMode {
        case .none: .black
        case .hovered: .red
        case .selected: .green
        }
        hingeOutline.model?.materials = [UnlitMaterial(color: color)]
        slateOutline.model?.materials = [UnlitMaterial(color: color)]
    }
    
    required init() {
        
        let object = Entity()
        
        let hinge: ModelEntity = {
            let mesh = MeshResource.generateCylinder(height: slateWidth, radius: hingeRadius)
            let materials = [defaultMaterial]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        
        let hingeOutline: ModelEntity = {
            let submesh = Submesh.generateCylinder(radius: hingeRadius + outlineMargin, length: slateWidth + outlineMargin * 2).inverted
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [UnlitMaterial(color: .black)]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        
        let slate: ModelEntity = {
            let submesh = Submesh.generateCube(width: slateWidth, height: slateHeight, depth: slateDepth)
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [defaultMaterial]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        object.addChild(slate)
        
        let slateOutline: ModelEntity = {
            let submesh = Submesh.generateCube(width: slateWidth + outlineMargin * 2,
                                               height: slateHeight + outlineMargin * 2,
                                               depth: slateDepth + outlineMargin * 2).inverted
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [UnlitMaterial(color: .black)]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        slate.addChild(slateOutline)
        
        let screen: ModelEntity = {
            let mesh = MeshResource.generatePlane(width: screenWidth, height: screenHeight)
            let materials = [defaultMaterial]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        object.addChild(screen)
        
        self.object = object
        self.hinge = hinge
        self.hingeOutline = hingeOutline
        self.slate = slate
        self.slateOutline = slateOutline
        self.screen = screen
        super.init()
        
        addChild(object)
        addChild(hinge)
        addChild(hingeOutline)
        hinge.transform = Transform(rotation: .init(from: .init(0, 1, 0), to: .init(1, 0, 0)))
        hingeOutline.transform = hinge.transform
        slate.transform = Transform(translation: .init(0, slateHeight * 0.5 + objectOffset, 0))
        screen.transform = Transform(translation: .init(0, slateHeight * 0.5 + objectOffset, slateDepth * 0.5 + 0.002))
        screen.isVisible = false
        object.transform = Transform(rotation: .init(angle: 0, axis: .init(1, 0, 0)))
        
        components.set(InputTargetComponent())
        components.set(HoverEffectComponent())
        let shape = ShapeResource.generateBox(width: slateWidth, height: slateHeight, depth: slateDepth)
            .offsetBy(translation: slate.transform.translation)
        components.set(CollisionComponent(shapes: [shape], isStatic: true))
    }
    
    func setScreenMaterials(_ materials: [any Material]) {
        screen.model?.materials = materials
    }
    
    private var animationSubscription: AnyCancellable? = nil
    @MainActor
    override func playAppearingAnimation() {
        
        guard animationSubscription == nil else { return }
        
        let objectBegin = Transform(rotation: .init(from: .init(0, 1, 0), to: .init(0, 0, 1)))
        let objectEnd = object.transform
        let objectAnimation = FromToByAnimation<Transform>(name: "object",
                                                           from: objectBegin,
                                                           to: objectEnd,
                                                           duration: 1.0,
                                                           timing: .easeInOut,
                                                           bindTarget: .transform)
        let objectAnimationResource = try! AnimationResource.generate(with: objectAnimation)
        
        let objectAnimationHandle = object.playAnimation(objectAnimationResource)
        
        let objectAnimationPublisher = object.scene!.publisher(for: AnimationEvents.PlaybackCompleted.self)
            .filter { $0.playbackController == objectAnimationHandle }
        
        animationSubscription = objectAnimationPublisher
            .sink { [weak self] _ in
                self?.screen.isVisible = true
                self?.playContent()
            }
    }
}
