//
//  CeilingEntity.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/25/24.
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
fileprivate let casingWidth: Float = sheetWidth + casingMargin * 2
fileprivate let casingHeight: Float = 0.02
fileprivate let casingDepth: Float = casingMargin * 2
fileprivate let outlineMargin: Float = 0.004

final class CeilingScreenEntity: VirtualObjectEntity, HasPlayableComponent, HasCustomHighlightComponent {
    
    private let sheet: ModelEntity
    private let sheetOutline: ModelEntity
    private let screen: ModelEntity
    private let casing: ModelEntity
    private let casingOutline: ModelEntity
    
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
        casingOutline.model?.materials = [UnlitMaterial(color: color)]
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
        
        let casing: ModelEntity = {
            let submesh = Submesh.generateCube(width: casingWidth, height: casingHeight, depth: casingDepth)
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [defaultMaterial]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        
        let casingOutline: ModelEntity = {
            let submesh = Submesh.generateCube(width: casingWidth + outlineMargin * 2,
                                               height: casingHeight + outlineMargin * 2,
                                               depth: casingDepth + outlineMargin * 2).inverted
            let mesh = try! MeshResource.generate(from: submesh)
            let materials = [UnlitMaterial(color: .black)]
            return ModelEntity(mesh: mesh, materials: materials)
        }()
        casing.addChild(casingOutline)
        
        self.sheet = sheet
        self.sheetOutline = sheetOutline
        self.screen = screen
        self.casing = casing
        self.casingOutline = casingOutline
        super.init()
        
        addChild(sheet)
        addChild(sheetOutline)
        addChild(screen)
        addChild(casing)
        
        casing.transform = Transform(translation: .init(0, -casingHeight * 0.5, 0))
        sheet.transform = Transform(scale: .one,
                                    translation: .init(0, -(casingHeight + sheetHeight * 0.5), 0))
        sheetOutline.transform = Transform(scale: .one,
                                           translation: .init(0, -(casingHeight + sheetHeight * 0.5), 0))
        screen.transform = Transform(translation: .init(0, -(sheetHeight * 0.5 + casingHeight), sheetDepth * 0.5 + 0.002))
        screen.isVisible = false
        
        components.set(InputTargetComponent())
        components.set(HoverEffectComponent())
        let shape = ShapeResource.generateBox(width: sheetWidth + outlineMargin * 2,
                                              height: sheetHeight + outlineMargin * 2,
                                              depth: sheetDepth + outlineMargin * 2)
            .offsetBy(translation: sheetOutline.transform.translation)
        components.set(CollisionComponent(shapes: [shape], isStatic: true))
    }
    
    func setScreenMaterials(_ materials: [any Material]) {
        screen.model?.materials = materials
    }
    
    private var animationSubscription: AnyCancellable? = nil
    @MainActor
    override func playAppearingAnimation() {
        
        guard animationSubscription == nil else { return }
        
        let sheetBegin = Transform(scale: .init(1, 0, 1),
                                   translation: .init(0, -casingHeight, 0))
        let sheetEnd = Transform(scale: sheet.scale, translation: sheet.position)
        let sheetAnimation = FromToByAnimation<Transform>(name: "sheet",
                                                          from: sheetBegin,
                                                          to: sheetEnd,
                                                          duration: 1.0,
                                                          timing: .easeInOut,
                                                          bindTarget: .transform)
        let sheetAnimationResource = try! AnimationResource.generate(with: sheetAnimation)
        
        let sheetOutlineBegin = Transform(scale: .init(1, outlineMargin * 2 / sheetHeight, 1),
                                          translation: .init(0, -casingHeight, 0))
        let sheetOutlineEnd = Transform(scale: sheetOutline.scale,
                                        translation: sheetOutline.position)
        let sheetOutlineAnimation = FromToByAnimation<Transform>(name: "sheet outline",
                                                                 from: sheetOutlineBegin,
                                                                 to: sheetOutlineEnd,
                                                                 duration: 1.0,
                                                                 timing: .easeInOut,
                                                                 bindTarget: .transform)
        let sheetOutlineAnimationResource = try! AnimationResource.generate(with: sheetOutlineAnimation)
        
        let sheetAnimationHandle = sheet.playAnimation(sheetAnimationResource)
        let sheetOutlineAnimationHandle = sheetOutline.playAnimation(sheetOutlineAnimationResource)
        
        let sheetAnimationPublisher = sheet.scene!.publisher(for: AnimationEvents.PlaybackCompleted.self)
            .filter { $0.playbackController == sheetAnimationHandle }
        let sheetOutlineAnimationPublisher = sheetOutline.scene!.publisher(for: AnimationEvents.PlaybackCompleted.self)
            .filter { $0.playbackController == sheetOutlineAnimationHandle }
        animationSubscription = Publishers.Merge(sheetAnimationPublisher, sheetOutlineAnimationPublisher)
            .sink { [weak self] _ in
                self?.screen.isVisible = true
                self?.playContent()
            }
    }
}

