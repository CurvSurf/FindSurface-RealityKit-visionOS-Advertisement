//
//  WallEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/28/24.
//

import RealityKit
import AVFoundation
import Combine
import UIKit

fileprivate let defaultMaterial = SimpleMaterial(color: .white, roughness: 1.0, isMetallic: false)
fileprivate let sheetWidth: Float = 1.0
fileprivate let sheetHeight: Float = sheetWidth * 9.0 / 16.0
fileprivate let sheetDepth: Float = 0.004
fileprivate let screenMargin: Float = 0.02
fileprivate let screenWidth: Float = sheetWidth - screenMargin * 2
fileprivate let screenHeight: Float = sheetHeight - screenMargin * 2
fileprivate let casingMargin: Float = 0.03
fileprivate let casingWidth: Float = screenWidth + casingMargin * 2
fileprivate let casingHeight: Float = 0.02
fileprivate let casingDepth: Float = casingMargin * 2
fileprivate let outlineMargin: Float = 0.004

final class WallScreenEntity: VirtualObjectEntity, HasPlayableComponent, HasCustomHighlightComponent {
    
    private let sheet: ModelEntity
    private let sheetOutline: ModelEntity
    private let screen: ModelEntity
    private let upperCasing: ModelEntity
    private let upperCasingOutline: ModelEntity
    private let lowerCasing: ModelEntity
    private let lowerCasingOutline: ModelEntity
    
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
        sheetOutline.model?.materials = [UnlitMaterial(color: color)]
        upperCasingOutline.model?.materials = [UnlitMaterial(color: color)]
        lowerCasingOutline.model?.materials = [UnlitMaterial(color: color)]
    }
    
    required init() {
        
        let sheet: ModelEntity = {
            let submesh = Submesh.generateCube(width: sheetWidth, height: sheetHeight, depth: sheetDepth)
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [defaultMaterial]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        
        let sheetOutline: ModelEntity = {
            let submesh = Submesh.generateCube(width: sheetWidth + outlineMargin * 2,
                                               height: sheetHeight + outlineMargin * 2,
                                               depth: sheetDepth + outlineMargin * 2).inverted
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [UnlitMaterial(color: .black)]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        
        let screen: ModelEntity = {
            let mesh = MeshResource.generatePlane(width: screenWidth, height: screenHeight)
            let materials = [defaultMaterial]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        
        let (upperCasing, lowerCasing): (ModelEntity, ModelEntity) = {
            let submesh = Submesh.generateCube(width: casingWidth, height: casingHeight, depth: casingDepth)
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [defaultMaterial]
            let upperCasing = ModelEntity(mesh: mesh, materials: materials)
            let lowerCasing = ModelEntity(mesh: mesh, materials: materials)
            return (upperCasing, lowerCasing)
        }()
        
        let (upperCasingOutline, lowerCasingOutline): (ModelEntity, ModelEntity) = {
            let submesh = Submesh.generateCube(width: casingWidth + outlineMargin * 2,
                                               height: casingHeight + outlineMargin * 2,
                                               depth: casingDepth + outlineMargin * 2).inverted
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [UnlitMaterial(color: .black)]
            let upperCasingOutline = ModelEntity(mesh: mesh, materials: materials)
            let lowerCasingOutline = ModelEntity(mesh: mesh, materials: materials)
            return (upperCasingOutline, lowerCasingOutline)
        }()
        upperCasing.addChild(upperCasingOutline)
        lowerCasing.addChild(lowerCasingOutline)
        
        self.sheet = sheet
        self.sheetOutline = sheetOutline
        self.screen = screen
        self.upperCasing = upperCasing
        self.upperCasingOutline = upperCasingOutline
        self.lowerCasing = lowerCasing
        self.lowerCasingOutline = lowerCasingOutline
        super.init()
        
        addChild(sheet)
        addChild(sheetOutline)
        addChild(screen)
        addChild(upperCasing)
        addChild(lowerCasing)
        
        upperCasing.transform = Transform(translation: .init(0, sheetHeight * 0.5 + casingHeight, 0))
        lowerCasing.transform = Transform(translation: .init(0, -(sheetHeight * 0.5 + casingHeight), 0))
        screen.transform = Transform(translation: .init(0, 0, sheetDepth * 0.5 + 0.002))
        screen.isVisible = false
        
        components.set(InputTargetComponent())
        components.set(HoverEffectComponent())
        let shape = ShapeResource.generateBox(width: sheetWidth + outlineMargin * 2,
                                              height: sheetHeight + outlineMargin * 2,
                                              depth: sheetDepth + outlineMargin * 2)
        components.set(CollisionComponent(shapes: [shape], isStatic: true))
    }
    
    func setScreenMaterials(_ materials: [any Material]) {
        screen.model?.materials = materials
    }
    
    private var animationSubscription: AnyCancellable? = nil
    @MainActor
    override func playAppearingAnimation() {
        
        guard animationSubscription == nil else { return }
        
        let sheetBegin = Transform(scale: .init(1, 0, 1))
        let sheetEnd = sheet.transform
        let sheetAnimation = FromToByAnimation<Transform>(name: "sheet",
                                                          from: sheetBegin,
                                                          to: sheetEnd,
                                                          duration: 1.0,
                                                          timing: .easeInOut,
                                                          bindTarget: .transform)
        let sheetAnimationResource = try! AnimationResource.generate(with: sheetAnimation)
        
        let sheetOutlineBegin = Transform(scale: .init(1, outlineMargin * 2 / sheetHeight, 1))
        let sheetOutlineEnd = sheetOutline.transform
        let sheetOutlineAnimation = FromToByAnimation<Transform>(name: "sheet outline",
                                                                 from: sheetOutlineBegin,
                                                                 to: sheetOutlineEnd,
                                                                 duration: 1.0,
                                                                 timing: .easeInOut,
                                                                 bindTarget: .transform)
        let sheetOutlineAnimationResource = try! AnimationResource.generate(with: sheetOutlineAnimation)
        
        let upperCasingBegin = Transform(translation: .init(0, casingHeight * 0.5, 0))
        let upperCasingEnd = upperCasing.transform
        let upperCasingAnimation = FromToByAnimation<Transform>(name: "upper casing",
                                                                from: upperCasingBegin,
                                                                to: upperCasingEnd,
                                                                duration: 1.0,
                                                                timing: .easeInOut,
                                                                bindTarget: .transform)
        let upperCasingAnimationResource = try! AnimationResource.generate(with: upperCasingAnimation)
        
        let lowerCasingBegin = Transform(translation: .init(0, -casingHeight * 0.5, 0))
        let lowerCasingEnd = lowerCasing.transform
        let lowerCasingAnimation = FromToByAnimation<Transform>(name: "lower casing",
                                                                from: lowerCasingBegin,
                                                                to: lowerCasingEnd,
                                                                duration: 1.0,
                                                                timing: .easeInOut,
                                                                bindTarget: .transform)
        let lowerCasingAnimationResource = try! AnimationResource.generate(with: lowerCasingAnimation)
        
        let sheetAnimationHandle = sheet.playAnimation(sheetAnimationResource)
        let sheetOutlineAnimationHandle = sheetOutline.playAnimation(sheetOutlineAnimationResource)
        let upperCasingAnimationHandle = upperCasing.playAnimation(upperCasingAnimationResource)
        let lowerCasingAnimationHandle = lowerCasing.playAnimation(lowerCasingAnimationResource)
        
        let sheetAnimationPublisher = sheet.scene!.publisher(for: AnimationEvents.PlaybackCompleted.self)
            .filter { $0.playbackController == sheetAnimationHandle }
        let sheetOutlineAnimationPublisher = sheetOutline.scene!.publisher(for: AnimationEvents.PlaybackCompleted.self)
            .filter { $0.playbackController == sheetOutlineAnimationHandle }
        let upperCasingAnimationPublisher = upperCasing.scene!.publisher(for: AnimationEvents.PlaybackCompleted.self)
            .filter { $0.playbackController == upperCasingAnimationHandle }
        let lowerCasingAnimationPublisher = lowerCasing.scene!.publisher(for: AnimationEvents.PlaybackCompleted.self)
            .filter { $0.playbackController == lowerCasingAnimationHandle }
        
        animationSubscription = Publishers.Merge4(sheetAnimationPublisher,
                                                  sheetOutlineAnimationPublisher,
                                                  upperCasingAnimationPublisher,
                                                  lowerCasingAnimationPublisher)
        .sink { [weak self] _ in
            self?.screen.isVisible = true
            self?.playContent()
        }
    }
}
